"""
URL configuration for auth app.
"""
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path('register/', views.register, name='register'),
    path('login/', views.login, name='login'),
    path('guest/', views.create_guest, name='create-guest'),
    path('convert-guest/', views.convert_guest, name='convert-guest'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]

