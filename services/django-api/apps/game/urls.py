"""
URL configuration for game app.
"""
from django.urls import path
from . import views

urlpatterns = [
    path('history/', views.match_history, name='match-history'),
    path('result/', views.game_result, name='game-result'),
]

