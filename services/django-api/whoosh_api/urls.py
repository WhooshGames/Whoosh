"""
URL configuration for whoosh_api project.
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from apps.auth import views as auth_views
from . import views

urlpatterns = [
    path('', views.index, name='index'),  # Frontend app at root
    path('test/', views.test_page, name='test_page'),  # Test page
    path('admin/', admin.site.urls),
    path('api/auth/', include('apps.auth.urls')),
    path('api/users/', include('apps.users.urls')),
    path('api/match/', include('apps.matchmaking.urls')),
    path('api/game/', include('apps.game.urls')),
    path('api/health/', auth_views.health_check, name='health'),  # Health check endpoint
]

# WhiteNoise handles static files in production, so we don't need this
# But keep it for development if needed
if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

