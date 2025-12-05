"""
URL configuration for matchmaking app.
"""
from django.urls import path
from . import views

urlpatterns = [
    path('join/', views.join_queue, name='join-queue'),
]

