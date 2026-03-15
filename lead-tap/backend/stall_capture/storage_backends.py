"""
Cloudflare R2 Storage Backends for Django.
Uses boto3 to connect to Cloudflare R2 (S3-compatible API).
"""

from django.conf import settings
from storages.backends.s3boto3 import S3Boto3Storage


class R2StaticStorage(S3Boto3Storage):
    """Storage backend for static files on Cloudflare R2."""
    location = 'static'
    default_acl = 'public-read'
    file_overwrite = True


class R2MediaStorage(S3Boto3Storage):
    """Storage backend for media files on Cloudflare R2."""
    location = 'media'
    default_acl = 'public-read'
    file_overwrite = False
