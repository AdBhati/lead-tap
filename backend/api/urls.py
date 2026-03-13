from django.urls import path
from api import views

urlpatterns = [
    # Auth
    path('auth/google/', views.google_auth, name='auth-google'),
    path('auth/whatsapp/', views.save_whatsapp_number, name='auth-whatsapp'),
    path('me/', views.me, name='me'),

    # Events
    path('events/', views.event_list, name='event-list'),
    path('events/<uuid:pk>/', views.event_detail, name='event-detail'),

    # Leads
    path('events/<uuid:pk>/leads/', views.lead_list, name='lead-list'),
]
