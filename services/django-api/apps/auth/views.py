"""
Authentication views for JWT-based auth.
"""
import boto3
import json
import uuid
from datetime import timedelta, datetime
from botocore.exceptions import ClientError
from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

User = get_user_model()


def get_jwt_keys_from_secrets_manager():
    """Retrieve JWT RSA keys from AWS Secrets Manager."""
    try:
        client = boto3.client('secretsmanager', region_name=settings.AWS_REGION)
        response = client.get_secret_value(SecretId=settings.AWS_SECRETS_MANAGER_SECRET_NAME)
        secret = json.loads(response['SecretString'])
        return secret.get('private_key'), secret.get('public_key')
    except ClientError:
        # Fallback for local development - generate keys on the fly
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        private_pem = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        public_pem = private_key.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )
        return private_pem.decode(), public_pem.decode()


def configure_jwt_keys():
    """Configure JWT keys in settings."""
    private_key, public_key = get_jwt_keys_from_secrets_manager()
    settings.SIMPLE_JWT['SIGNING_KEY'] = private_key
    settings.SIMPLE_JWT['VERIFYING_KEY'] = public_key


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Custom token serializer that includes user info."""
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['user_id'] = str(user.id)
        token['username'] = user.username
        token['is_guest'] = user.is_guest
        if user.display_name:
            token['display_name'] = user.display_name
        
        # Set shorter expiration for guest tokens (24 hours instead of default)
        if user.is_guest:
            from rest_framework_simplejwt.utils import aware_utcnow
            token.set_exp(from_time=aware_utcnow(), lifetime=timedelta(hours=24))
        
        return token


@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    """Register a new user."""
    username = request.data.get('username')
    email = request.data.get('email')
    password = request.data.get('password')

    if not username or not email or not password:
        return Response(
            {'error': 'Username, email, and password are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    if User.objects.filter(username=username).exists():
        return Response(
            {'error': 'Username already exists'},
            status=status.HTTP_400_BAD_REQUEST
        )

    if User.objects.filter(email=email).exists():
        return Response(
            {'error': 'Email already exists'},
            status=status.HTTP_400_BAD_REQUEST
        )

    user = User.objects.create_user(
        username=username,
        email=email,
        password=password
    )

    refresh_token = RefreshToken.for_user(user)
    access_token = refresh_token.access_token
    
    # Add custom claims
    refresh_token['user_id'] = str(user.id)
    refresh_token['username'] = user.username
    refresh_token['is_guest'] = user.is_guest
    access_token['user_id'] = str(user.id)
    access_token['username'] = user.username
    access_token['is_guest'] = user.is_guest
    
    return Response({
        'refresh': str(refresh_token),
        'access': str(access_token),
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'display_name': user.display_name,
            'is_guest': user.is_guest,
        }
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    """Login and get JWT tokens."""
    configure_jwt_keys()  # Ensure keys are loaded
    
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response(
            {'error': 'Username and password are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        user = User.objects.get(username=username)
        if not user.check_password(password):
            return Response(
                {'error': 'Invalid credentials'},
                status=status.HTTP_401_UNAUTHORIZED
            )
    except User.DoesNotExist:
        return Response(
            {'error': 'Invalid credentials'},
            status=status.HTTP_401_UNAUTHORIZED
        )

    # Generate tokens with custom claims
    refresh_token = RefreshToken.for_user(user)
    access_token = refresh_token.access_token
    
    refresh_token['user_id'] = str(user.id)
    refresh_token['username'] = user.username
    refresh_token['is_guest'] = user.is_guest
    access_token['user_id'] = str(user.id)
    access_token['username'] = user.username
    access_token['is_guest'] = user.is_guest
    
    if user.display_name:
        refresh_token['display_name'] = user.display_name
        access_token['display_name'] = user.display_name
    
    return Response({
        'refresh': str(refresh_token),
        'access': str(access_token),
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'display_name': user.display_name,
            'is_guest': user.is_guest,
        }
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([AllowAny])
def create_guest(request):
    """Create a temporary guest account."""
    configure_jwt_keys()  # Ensure keys are loaded
    
    display_name = request.data.get('display_name', '').strip()
    
    # Generate unique guest username
    guest_id = uuid.uuid4().hex[:8]
    username = f"Guest_{guest_id}"
    
    # Ensure username is unique (very unlikely but handle it)
    while User.objects.filter(username=username).exists():
        guest_id = uuid.uuid4().hex[:8]
        username = f"Guest_{guest_id}"
    
    # Create guest user
    user = User.objects.create_user(
        username=username,
        email=None,  # Guests don't need email
        password=None,  # Guests don't have passwords
        is_guest=True,
        display_name=display_name if display_name else None,
        session_expires_at=timezone.now() + timedelta(hours=24)
    )
    
    # Generate JWT tokens with shorter expiration for guests
    # For guests, we need custom token expiration (24 hours)
    from rest_framework_simplejwt.utils import aware_utcnow
    
    refresh_token = RefreshToken.for_user(user)
    access_token = refresh_token.access_token
    
    # Add custom claims
    refresh_token['user_id'] = str(user.id)
    refresh_token['username'] = user.username
    refresh_token['is_guest'] = user.is_guest
    access_token['user_id'] = str(user.id)
    access_token['username'] = user.username
    access_token['is_guest'] = user.is_guest
    
    if user.display_name:
        refresh_token['display_name'] = user.display_name
        access_token['display_name'] = user.display_name
    
    # Set 24-hour expiration for guest tokens
    if user.is_guest:
        refresh_token.set_exp(from_time=aware_utcnow(), lifetime=timedelta(hours=24))
        access_token.set_exp(from_time=aware_utcnow(), lifetime=timedelta(hours=24))
    
    return Response({
        'refresh': str(refresh_token),
        'access': str(access_token),
        'user': {
            'id': user.id,
            'username': user.username,
            'display_name': user.display_name,
            'is_guest': user.is_guest,
        }
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def convert_guest(request):
    """Convert a guest account to a full account."""
    configure_jwt_keys()  # Ensure keys are loaded
    
    # User must be authenticated (permission_classes default requires authentication)
    if not request.user.is_authenticated:
        return Response(
            {'error': 'Authentication required'},
            status=status.HTTP_401_UNAUTHORIZED
        )
    
    user = request.user
    
    # Check if user is actually a guest
    if not user.is_guest:
        return Response(
            {'error': 'User is not a guest account'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Get registration info
    username = request.data.get('username')
    email = request.data.get('email')
    password = request.data.get('password')
    
    if not username or not email or not password:
        return Response(
            {'error': 'Username, email, and password are required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Check if username already exists
    if User.objects.filter(username=username).exclude(id=user.id).exists():
        return Response(
            {'error': 'Username already exists'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Check if email already exists
    if User.objects.filter(email=email).exclude(id=user.id).exists():
        return Response(
            {'error': 'Email already exists'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Convert guest to full account
    user.username = username
    user.email = email
    user.set_password(password)
    user.is_guest = False
    user.session_expires_at = None
    # Keep display_name if it was set
    user.save()
    
    # Generate new tokens with full expiration (default settings)
    refresh_token = RefreshToken.for_user(user)
    access_token = refresh_token.access_token
    
    # Add custom claims
    refresh_token['user_id'] = str(user.id)
    refresh_token['username'] = user.username
    refresh_token['is_guest'] = user.is_guest
    access_token['user_id'] = str(user.id)
    access_token['username'] = user.username
    access_token['is_guest'] = user.is_guest
    
    if user.display_name:
        refresh_token['display_name'] = user.display_name
        access_token['display_name'] = user.display_name
    
    return Response({
        'refresh': str(refresh_token),
        'access': str(access_token),
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'display_name': user.display_name,
            'is_guest': user.is_guest,
        }
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    """Health check endpoint."""
    return Response({'status': 'ok'}, status=status.HTTP_200_OK)
