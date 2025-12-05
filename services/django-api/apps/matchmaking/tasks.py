"""
Celery tasks for matchmaking.
"""
import redis
import uuid
from celery import shared_task
from django.conf import settings


@shared_task
def process_matchmaking_queue(queue_name='standard'):
    """Process matchmaking queue and create games when 8 players are ready."""
    r = redis.Redis(
        host=settings.REDIS_HOST,
        port=settings.REDIS_PORT,
        db=settings.REDIS_DB,
        decode_responses=True
    )
    
    queue_key = f'matchmaking:queue:{queue_name}'
    players_per_game = 8
    
    while True:
        # Check if we have enough players
        queue_length = r.llen(queue_key)
        if queue_length < players_per_game:
            break
        
        # Pop 8 players
        players = []
        for _ in range(players_per_game):
            player_id = r.rpop(queue_key)
            if player_id:
                players.append(player_id)
        
        if len(players) == players_per_game:
            # Create game
            game_id = str(uuid.uuid4())
            game_key = f'game:{game_id}'
            
            # Store game info in Redis
            r.hset(game_key, mapping={
                'id': game_id,
                'status': 'waiting',
                'players': ','.join(players),
            })
            
            # Set expiration (e.g., 10 minutes)
            r.expire(game_key, 600)
            
            # Notify players (this would typically be done via WebSocket)
            # For now, we'll just log it
            print(f"Created game {game_id} with players: {players}")
    
    return {'processed': True}

