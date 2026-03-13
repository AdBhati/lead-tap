"""
API Views for Stall Capture.

All list endpoints use select_related / prefetch_related to eliminate N+1 queries.
All endpoints filter strictly by request.user.

Endpoints:
    POST  /api/auth/google/         — Google OAuth login
    POST  /api/auth/whatsapp/       — Save WhatsApp number
    GET   /api/me/                  — Current user info

    GET   /api/events/              — List user events
    POST  /api/events/              — Create event
    GET   /api/events/<id>/         — Event detail
    PUT   /api/events/<id>/         — Update event
    DELETE /api/events/<id>/        — Delete event

    GET   /api/events/<id>/leads/   — List leads for event
    POST  /api/events/<id>/leads/   — Create lead → save DB + GSheet
"""

import logging
import threading
from django.conf import settings
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests
from google.oauth2.credentials import Credentials
import gspread

from api.models import User, Event, Lead
from api.serializers import (
    UserSerializer,
    EventSerializer,
    LeadSerializer,
    WhatsAppNumberSerializer,
    GoogleAuthSerializer,
)
from services.google_sheets import provision_sheet, append_lead_row

logger = logging.getLogger(__name__)


# ─── Helpers ─────────────────────────────────────────────────────────────────

class LeadPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = 'page_size'
    max_page_size = 200


class EventPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = 'page_size'
    max_page_size = 200


def _get_tokens_for_user(user):
    """Return JWT access + refresh tokens dict for a user."""
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }


def _provision_sheet_async(user):
    """Kick off sheet provisioning in a background thread so the auth response is fast."""
    t = threading.Thread(target=provision_sheet, args=(user,), daemon=True)
    t.start()


# ─── Auth ─────────────────────────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
def google_auth(request):
    """
    POST /api/auth/google/

    Accepts the Google ID token (and optionally server_auth_code / access_token /
    refresh_token) from the Flutter app's google_sign_in plugin.

    Flow:
    1. Verify the ID token with Google.
    2. Create or retrieve the User.
    3. Store access/refresh tokens if provided.
    4. Provision a Google Sheet if not already done (async).
    5. Return JWT tokens + user info.
    """
    serializer = GoogleAuthSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    id_token_str = serializer.validated_data.get('id_token', '')
    access_token_str = serializer.validated_data.get('access_token', '')
    refresh_token_str = serializer.validated_data.get('refresh_token', '')

    email = ''
    name = ''

    if id_token_str:
        # Verify Google ID token
        try:
            idinfo = google_id_token.verify_oauth2_token(
                id_token_str,
                google_requests.Request(),
                settings.GOOGLE_CLIENT_ID if settings.GOOGLE_CLIENT_ID else None,
            )
            email = idinfo.get('email', '')
            name = idinfo.get('name', '')
        except ValueError as exc:
            logger.warning('Invalid Google ID token: %s', exc)
            return Response(
                {'detail': 'Invalid Google ID token.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
    elif access_token_str:
        # On web, google_sign_in doesn't return id_token reliably, we use access_token
        import requests
        try:
            resp = requests.get(
                'https://www.googleapis.com/oauth2/v3/userinfo',
                headers={'Authorization': f'Bearer {access_token_str}'}
            )
            resp.raise_for_status()
            userinfo = resp.json()
            email = userinfo.get('email', '')
            name = userinfo.get('name', '')
        except Exception as exc:
            logger.warning('Failed to fetch user info with access token: %s', exc)
            return Response(
                {'detail': 'Invalid or expired Google Access Token.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
    else:
        return Response(
            {'detail': 'Must provide either id_token or access_token.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not email:
        return Response(
            {'detail': 'Email not returned by Google.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Get or create user
    user, created = User.objects.get_or_create(
        email=email,
        defaults={
            'username': email,
            'name': name,
        },
    )

    if name and not user.name:
        user.name = name

    # Store tokens
    if access_token_str:
        user.google_access_token = access_token_str
    if refresh_token_str:
        user.google_refresh_token = refresh_token_str

    user.save(update_fields=['name', 'google_access_token', 'google_refresh_token'])

    # Provision sheet asynchronously (non-blocking)
    if access_token_str or user.google_access_token:
        _provision_sheet_async(user)

    tokens = _get_tokens_for_user(user)
    return Response(
        {
            **tokens,
            'user': UserSerializer(user).data,
            'is_new_user': created,
        },
        status=status.HTTP_200_OK,
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def save_whatsapp_number(request):
    """
    POST /api/auth/whatsapp/
    Save or update the authenticated user's WhatsApp number.
    """
    serializer = WhatsAppNumberSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    request.user.whatsapp_number = serializer.validated_data['whatsapp_number']
    request.user.save(update_fields=['whatsapp_number'])

    return Response(UserSerializer(request.user).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def me(request):
    """GET /api/me/ — Return current user profile."""
    return Response(UserSerializer(request.user).data)


# ─── Events ───────────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def event_list(request):
    """
    GET  /api/events/ — Paginated list of user's events.
    POST /api/events/ — Create a new event for the current user.
    """
    if request.method == 'GET':
        # select_related('user') + prefetch leads for lead_count — zero N+1
        events = (
            Event.objects.filter(user=request.user)
            .select_related('user')
            .prefetch_related('leads')
            .only('id', 'name', 'whatsapp_message', 'media_url', 'created_at', 'user_id')
            .order_by('-created_at')
        )
        paginator = EventPagination()
        page = paginator.paginate_queryset(events, request)
        serializer = EventSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)

    # POST — create event
    serializer = EventSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    event = serializer.save(user=request.user)
    return Response(EventSerializer(event).data, status=status.HTTP_201_CREATED)


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsAuthenticated])
def event_detail(request, pk):
    """
    GET    /api/events/<id>/ — Single event detail.
    PUT    /api/events/<id>/ — Update event.
    DELETE /api/events/<id>/ — Delete event.
    """
    event = get_object_or_404(
        Event.objects.select_related('user').prefetch_related('leads'),
        pk=pk,
        user=request.user,
    )

    if request.method == 'GET':
        return Response(EventSerializer(event).data)

    if request.method == 'PUT':
        serializer = EventSerializer(event, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(serializer.data)

    # DELETE
    event.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


# ─── Leads ────────────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def lead_list(request, pk):
    """
    GET  /api/events/<id>/leads/ — Paginated leads for an event.
    POST /api/events/<id>/leads/ — Create lead, save DB, append GSheet row.
    """
    # Verify the event belongs to the authenticated user
    event = get_object_or_404(
        Event.objects.select_related('user'),
        pk=pk,
        user=request.user,
    )

    if request.method == 'GET':
        # select_related event+user for potential nested access — zero N+1
        leads = (
            Lead.objects.filter(event=event)
            .select_related('event__user')
            .only(
                'id', 'name', 'mobile_number', 'email', 'comment', 'created_at', 'event_id'
            )
            .order_by('-created_at')
        )
        paginator = LeadPagination()
        page = paginator.paginate_queryset(leads, request)
        serializer = LeadSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)

    # POST — create lead
    serializer = LeadSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    lead = serializer.save(event=event)

    # Append to GSheet in background (non-blocking — DB save already succeeded)
    def _append():
        append_lead_row(request.user, event.name, lead)

    threading.Thread(target=_append, daemon=True).start()

    return Response(LeadSerializer(lead).data, status=status.HTTP_201_CREATED)
