"""
Database models for the Stall Capture application.

Models:
    User  - Extends AbstractUser with WhatsApp, Google tokens, and GSheet fields
    Event - An exhibitor's event with WhatsApp message template
    Lead  - A captured lead tied to an event
"""

import uuid
from django.contrib.auth.models import AbstractUser
from django.db import models
from encrypted_model_fields.fields import EncryptedTextField


class User(AbstractUser):
    """
    Custom user model extending AbstractUser.

    Extra fields:
        - whatsapp_number: Exhibitor's WhatsApp number (optional initially)
        - google_access_token: OAuth2 access token (encrypted at rest)
        - google_refresh_token: OAuth2 refresh token (encrypted at rest)
        - gsheet_id: ID of the user's dedicated Google Sheet
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=255, blank=True)
    whatsapp_number = models.CharField(max_length=20, blank=True, default='')
    google_access_token = EncryptedTextField(blank=True, default='')
    google_refresh_token = EncryptedTextField(blank=True, default='')
    gsheet_id = models.CharField(max_length=255, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    class Meta:
        indexes = [
            models.Index(fields=['email']),
        ]
        verbose_name = 'User'
        verbose_name_plural = 'Users'

    def __str__(self):
        return self.email


class Event(models.Model):
    """
    An event created by an exhibitor.

    Each event has a WhatsApp message template and an optional media URL
    (e.g. a Google Drive brochure link) that is automatically included
    when WhatsApp is opened for a new lead.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='events',
        db_index=True,
    )
    name = models.CharField(max_length=255)
    whatsapp_message = models.TextField()
    media_url = models.CharField(max_length=1024, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['user', 'created_at']),
        ]
        ordering = ['-created_at']
        verbose_name = 'Event'
        verbose_name_plural = 'Events'

    def __str__(self):
        return f'{self.name} ({self.user.email})'

    @property
    def lead_count(self):
        return self.leads.count()


class Lead(models.Model):
    """
    A captured lead for an event.

    Stored in SQLite and simultaneously appended to the user's Google Sheet
    when created via the API.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    event = models.ForeignKey(
        Event,
        on_delete=models.CASCADE,
        related_name='leads',
        db_index=True,
    )
    name = models.CharField(max_length=255)
    mobile_number = models.CharField(max_length=20)
    email = models.EmailField(blank=True, default='')
    comment = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['event', 'created_at']),
            models.Index(fields=['created_at']),
        ]
        ordering = ['-created_at']
        verbose_name = 'Lead'
        verbose_name_plural = 'Leads'

    def __str__(self):
        return f'{self.name} — {self.mobile_number}'
