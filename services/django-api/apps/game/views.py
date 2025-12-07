"""
Game views for match history and results.
"""
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Match, MatchParticipant
from apps.users.models import User


@api_view(['GET'])
def match_history(request):
    """Get match history for current user."""
    user = request.user
    matches = Match.objects.filter(participants__user=user).distinct()[:20]
    
    history = []
    for match in matches:
        participant = match.participants.get(user=user)
        history.append({
            'match_id': str(match.id),
            'started_at': match.started_at.isoformat(),
            'ended_at': match.ended_at.isoformat() if match.ended_at else None,
            'elo_before': participant.elo_before,
            'elo_after': participant.elo_after,
            'xp_gained': participant.xp_gained,
            'is_winner': participant.is_winner,
        })
    
    return Response(history)


@csrf_exempt
@require_http_methods(["POST"])
def game_result(request):
    """
    gRPC endpoint (simulated via HTTP) for Go service to submit game results.
    This would typically be a gRPC endpoint, but for now we'll use HTTP.
    Guest matches are not persisted - only matches with authenticated users are saved.
    """
    try:
        data = json.loads(request.body)
        game_id = data.get('game_id')
        winner_id = data.get('winner_id')
        participants = data.get('participants', [])
        
        # Check if all participants are guests - if so, don't persist the match
        all_guests = True
        authenticated_users = []
        
        for participant_data in participants:
            user_id = participant_data.get('user_id')
            try:
                user = User.objects.get(id=user_id)
                if not user.is_guest:
                    all_guests = False
                    authenticated_users.append((user, participant_data))
            except User.DoesNotExist:
                continue
        
        # If all participants are guests, don't save the match
        if all_guests:
            return JsonResponse({
                'status': 'success',
                'message': 'Guest match - not persisted',
                'match_id': str(game_id)
            })
        
        # Create match record only if there are authenticated users
        match = Match.objects.create(
            id=game_id,
            status='completed',
            winner_id=winner_id
        )
        
        # Create participant records and update user stats (only for authenticated users)
        for user, participant_data in authenticated_users:
            elo_before = participant_data.get('elo_before', 1000)
            elo_after = participant_data.get('elo_after', 1000)
            xp_gained = participant_data.get('xp_gained', 0)
            is_winner = participant_data.get('is_winner', False)
            
            MatchParticipant.objects.create(
                match=match,
                user=user,
                elo_before=elo_before,
                elo_after=elo_after,
                xp_gained=xp_gained,
                is_winner=is_winner
            )
            
            # Update user stats (skip for guests)
            if not user.is_guest:
                user.elo = elo_after
                user.xp += xp_gained
                user.total_games += 1
                if is_winner:
                    user.wins += 1
                user.save()
        
        return JsonResponse({'status': 'success', 'match_id': str(game_id)})
    
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

