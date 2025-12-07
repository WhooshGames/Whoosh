"""
Serializers for user app.
"""
from rest_framework import serializers
from .models import User


class UserSerializer(serializers.ModelSerializer):
    """Serializer for User model."""
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'elo', 'xp', 'total_games', 'wins', 'created_at', 'is_guest', 'display_name']
        read_only_fields = ['id', 'created_at', 'is_guest']

