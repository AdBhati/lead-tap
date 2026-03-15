"""
Serializers for the Stall Capture API.
"""

from rest_framework import serializers
from api.models import User, Event, Lead


class UserSerializer(serializers.ModelSerializer):
    """Serializer for the current user's profile."""

    class Meta:
        model = User
        fields = ['id', 'email', 'name', 'whatsapp_number', 'gsheet_id', 'created_at']
        read_only_fields = ['id', 'email', 'gsheet_id', 'created_at']


class EventSerializer(serializers.ModelSerializer):
    """Serializer for Event CRUD — includes lead_count as computed field."""

    lead_count = serializers.SerializerMethodField()

    class Meta:
        model = Event
        fields = [
            'id', 'name', 'whatsapp_message', 'media_url', 'lead_count', 'created_at'
        ]
        read_only_fields = ['id', 'created_at', 'lead_count']

    def get_lead_count(self, obj) -> int:
        # Uses prefetched `leads` queryset from the view — no extra query
        if hasattr(obj, '_prefetched_objects_cache') and 'leads' in obj._prefetched_objects_cache:
            return len(obj._prefetched_objects_cache['leads'])
        return obj.leads.count()


class EventDetailSerializer(EventSerializer):
    """Extended serializer for single-event detail view."""

    class Meta(EventSerializer.Meta):
        fields = EventSerializer.Meta.fields


class LeadSerializer(serializers.ModelSerializer):
    """Serializer for leads — write and read."""

    class Meta:
        model = Lead
        fields = ['id', 'name', 'mobile_number', 'email', 'comment', 'created_at']
        read_only_fields = ['id', 'created_at']


class WhatsAppNumberSerializer(serializers.Serializer):
    """For the /api/auth/whatsapp/ endpoint."""

    whatsapp_number = serializers.CharField(max_length=20)


class GoogleAuthSerializer(serializers.Serializer):
    """Payload from Flutter's google_sign_in — ID token + auth code for server-side flow."""

    id_token = serializers.CharField(required=False, allow_blank=True, default='')
    server_auth_code = serializers.CharField(required=False, allow_blank=True, default='')
    access_token = serializers.CharField()
    refresh_token = serializers.CharField(required=False, allow_blank=True, default='')
