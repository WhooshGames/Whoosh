"""
URL configuration for whoosh_api project.
"""
from django.contrib import admin
from django.urls import path, include
from apps.auth import views as auth_views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('apps.auth.urls')),
    path('api/users/', include('apps.users.urls')),
    path('api/match/', include('apps.matchmaking.urls')),
    path('api/game/', include('apps.game.urls')),
    path('api/health/', auth_views.health_check, name='health'),  # Health check endpoint
]

