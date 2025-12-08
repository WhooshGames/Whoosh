"""
Main views for whoosh_api project.
"""
from django.shortcuts import render
from django.utils import timezone


def index(request):
    """Main frontend application."""
    return render(request, 'index.html')


def test_page(request):
    """Simple test page to verify deployment."""
    context = {
        'server_time': timezone.now().strftime('%Y-%m-%d %H:%M:%S UTC')
    }
    return render(request, 'test.html', context)

