"""
Game models for match history and results.
"""
from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()


class Match(models.Model):
    """Match history model."""
    id = models.UUIDField(primary_key=True)
    started_at = models.DateTimeField(auto_now_add=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, default='completed')
    winner_id = models.UUIDField(null=True, blank=True)
    
    class Meta:
        db_table = 'matches'
        ordering = ['-started_at']


class MatchParticipant(models.Model):
    """Participants in a match."""
    match = models.ForeignKey(Match, on_delete=models.CASCADE, related_name='participants')
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    elo_before = models.IntegerField()
    elo_after = models.IntegerField()
    xp_gained = models.IntegerField(default=0)
    is_winner = models.BooleanField(default=False)
    
    class Meta:
        db_table = 'match_participants'
        unique_together = ['match', 'user']

