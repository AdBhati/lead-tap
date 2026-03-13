"""
Google Sheets service layer.

Handles creation of a new Sheet on user signup and appending lead rows.
Uses the gspread library with OAuth2 credentials obtained from the user's
stored (and refreshed) Google tokens.
"""

import logging
from typing import Optional

import gspread
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from django.conf import settings

logger = logging.getLogger(__name__)

SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
]

SHEET_HEADERS = ['Name', 'Mobile', 'Email', 'Comment', 'Timestamp']


def _build_credentials(user) -> Optional[Credentials]:
    """
    Build a refreshed Google OAuth2 Credentials object from the user's
    stored tokens.  Returns None if no tokens are available.
    """
    if not user.google_access_token:
        logger.warning('User %s has no Google access token.', user.email)
        return None

    creds = Credentials(
        token=user.google_access_token,
        refresh_token=user.google_refresh_token,
        token_uri='https://oauth2.googleapis.com/token',
        client_id=settings.GOOGLE_CLIENT_ID,
        client_secret=settings.GOOGLE_CLIENT_SECRET,
        scopes=SCOPES,
    )

    # Refresh if expired
    if creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
            # Persist refreshed token
            user.google_access_token = creds.token
            user.save(update_fields=['google_access_token'])
        except Exception as exc:  # noqa: BLE001
            logger.error('Failed to refresh Google token for %s: %s', user.email, exc)
            return None

    return creds


def _get_client(user) -> Optional[gspread.Client]:
    """Return an authenticated gspread client for the given user."""
    creds = _build_credentials(user)
    if creds is None:
        return None
    return gspread.authorize(creds)


def provision_sheet(user) -> Optional[str]:
    """
    Create a Google Sheet for the user (one-time on signup).

    The sheet is named "Stall Capture — <email>".
    Returns the spreadsheet ID, or None on failure.
    """
    if user.gsheet_id:
        # Already provisioned — return existing ID
        return user.gsheet_id

    gc = _get_client(user)
    if gc is None:
        logger.error('Cannot provision sheet — no valid credentials for %s', user.email)
        return None

    try:
        sh = gc.create(f'Stall Capture — {user.email}')
        # Remove the default empty sheet and add a placeholder
        default_ws = sh.sheet1
        default_ws.update_title('Overview')
        default_ws.update([['This sheet is managed by Stall Capture.']], 'A1')

        sheet_id = sh.id
        user.gsheet_id = sheet_id
        user.save(update_fields=['gsheet_id'])
        logger.info('Provisioned Google Sheet %s for %s', sheet_id, user.email)
        return sheet_id
    except Exception as exc:  # noqa: BLE001
        logger.error('Failed to create Google Sheet for %s: %s', user.email, exc)
        return None


def ensure_event_tab(user, event_name: str) -> Optional[gspread.Worksheet]:
    """
    Ensure a worksheet tab exists for the given event inside the user's sheet.
    Creates it with header row if it doesn't exist.
    Returns the Worksheet, or None on failure.
    """
    if not user.gsheet_id:
        logger.warning('User %s has no gsheet_id — cannot ensure event tab.', user.email)
        return None

    gc = _get_client(user)
    if gc is None:
        return None

    try:
        sh = gc.open_by_key(user.gsheet_id)
        # Try to get existing tab
        try:
            ws = sh.worksheet(event_name)
        except gspread.WorksheetNotFound:
            ws = sh.add_worksheet(title=event_name, rows=1000, cols=len(SHEET_HEADERS))
            ws.append_row(SHEET_HEADERS, value_input_option='USER_ENTERED')
        return ws
    except Exception as exc:  # noqa: BLE001
        logger.error(
            'Failed to ensure event tab "%s" for %s: %s', event_name, user.email, exc
        )
        return None


def append_lead_row(user, event_name: str, lead) -> bool:
    """
    Append a single lead row to the correct event tab.

    Args:
        user:       The owner User instance.
        event_name: The event's name (tab name).
        lead:       The Lead model instance.

    Returns:
        True if the row was appended successfully, False otherwise.
    """
    ws = ensure_event_tab(user, event_name)
    if ws is None:
        return False

    row = [
        lead.name,
        lead.mobile_number,
        lead.email,
        lead.comment,
        lead.created_at.strftime('%Y-%m-%d %H:%M:%S UTC'),
    ]

    try:
        ws.append_row(row, value_input_option='USER_ENTERED')
        logger.info(
            'Appended lead %s to sheet %s tab "%s"', lead.id, user.gsheet_id, event_name
        )
        return True
    except Exception as exc:  # noqa: BLE001
        logger.error(
            'Failed to append lead %s to GSheet: %s', lead.id, exc
        )
        return False
