"""
Matchmaking views.
"""
import redis
from django.conf import settings
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .tasks import process_matchmaking_queue


@api_view(['POST'])
def join_queue(request):
    """Add user to matchmaking queue."""
    user_id = str(request.user.id)
    queue_name = request.data.get('queue', 'standard')
    
    try:
        r = redis.Redis(
            host=settings.REDIS_HOST,
            port=settings.REDIS_PORT,
            db=settings.REDIS_DB,
            decode_responses=True
        )
        
        # Add user to queue
        r.lpush(f'matchmaking:queue:{queue_name}', user_id)
        
        # Trigger matchmaking worker
        process_matchmaking_queue.delay(queue_name)
        
        return Response({
            'message': 'Added to matchmaking queue',
            'queue': queue_name,
            'user_id': user_id
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

