"""
User models for Whoosh.
"""
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Custom user model with ELO and XP tracking."""
    elo = models.IntegerField(default=1000)
    xp = models.IntegerField(default=0)
    total_games = models.IntegerField(default=0)
    wins = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Guest account fields
    is_guest = models.BooleanField(default=False)
    display_name = models.CharField(max_length=50, null=True, blank=True)
    session_expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'users'
        indexes = [
            models.Index(fields=['is_guest', 'session_expires_at']),
        ]

