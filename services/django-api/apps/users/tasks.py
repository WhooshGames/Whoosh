"""
Celery tasks for user management.
"""
from celery import shared_task
from django.utils import timezone
from .models import User


@shared_task
def cleanup_expired_guests():
    """Delete expired guest accounts and their associated data."""
    now = timezone.now()
    
    # Find all expired guest accounts
    expired_guests = User.objects.filter(
        is_guest=True,
        session_expires_at__lt=now
    )
    
    count = expired_guests.count()
    
    # Delete expired guests (this will cascade delete any related data)
    expired_guests.delete()
    
    return {
        'deleted_count': count,
        'timestamp': now.isoformat()
    }

