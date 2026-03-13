from django.contrib import admin
from api.models import User, Event, Lead


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ['email', 'name', 'whatsapp_number', 'created_at']
    search_fields = ['email', 'name']
    readonly_fields = ['id', 'created_at']
    list_select_related = True


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ['name', 'user', 'created_at']
    search_fields = ['name', 'user__email']
    list_filter = ['created_at']
    readonly_fields = ['id', 'created_at']
    list_select_related = ['user']


@admin.register(Lead)
class LeadAdmin(admin.ModelAdmin):
    list_display = ['name', 'mobile_number', 'email', 'event', 'created_at']
    search_fields = ['name', 'mobile_number', 'email', 'event__name']
    list_filter = ['created_at']
    readonly_fields = ['id', 'created_at']
    list_select_related = ['event', 'event__user']
