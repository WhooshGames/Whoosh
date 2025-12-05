# Whoosh API Documentation

## Base URL

Production: `https://api.whoosh.example.com/api`
Local Development: `http://localhost:8000/api`

## Authentication

All endpoints (except auth endpoints) require JWT authentication. Include the token in the Authorization header:

```
Authorization: Bearer <access_token>
```

## Endpoints

### Authentication

#### Register User

```http
POST /api/auth/register
```

**Request Body:**
```json
{
  "username": "player1",
  "email": "player1@example.com",
  "password": "securepassword123"
}
```

**Response:**
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": 1,
    "username": "player1",
    "email": "player1@example.com"
  }
}
```

#### Login

```http
POST /api/auth/login
```

**Request Body:**
```json
{
  "username": "player1",
  "password": "securepassword123"
}
```

**Response:**
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": 1,
    "username": "player1",
    "email": "player1@example.com"
  }
}
```

### Users

#### Get Current User Profile

```http
GET /api/users/me
```

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "id": 1,
  "username": "player1",
  "email": "player1@example.com",
  "elo": 1000,
  "xp": 0,
  "total_games": 0,
  "wins": 0,
  "created_at": "2024-01-01T00:00:00Z"
}
```

#### Update User Profile

```http
PATCH /api/users/me
```

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "username": "newusername"
}
```

**Response:**
```json
{
  "id": 1,
  "username": "newusername",
  "email": "player1@example.com",
  "elo": 1000,
  "xp": 0,
  "total_games": 0,
  "wins": 0,
  "created_at": "2024-01-01T00:00:00Z"
}
```

### Matchmaking

#### Join Matchmaking Queue

```http
POST /api/match/join
```

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "queue": "standard"
}
```

**Response:**
```json
{
  "message": "Added to matchmaking queue",
  "queue": "standard",
  "user_id": "1"
}
```

### Game

#### Get Match History

```http
GET /api/game/history
```

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:**
```json
[
  {
    "match_id": "550e8400-e29b-41d4-a716-446655440000",
    "started_at": "2024-01-01T00:00:00Z",
    "ended_at": "2024-01-01T00:05:00Z",
    "elo_before": 1000,
    "elo_after": 1050,
    "xp_gained": 100,
    "is_winner": true
  }
]
```

#### Submit Game Result (Internal - Go Service)

```http
POST /api/game/result
```

**Note:** This endpoint is called internally by the Go service via gRPC/HTTP.

**Request Body:**
```json
{
  "game_id": "550e8400-e29b-41d4-a716-446655440000",
  "winner_id": "user_123",
  "participants": [
    {
      "user_id": "user_123",
      "elo_before": 1000,
      "elo_after": 1050,
      "xp_gained": 100,
      "is_winner": true
    }
  ]
}
```

**Response:**
```json
{
  "status": "success",
  "match_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

## WebSocket API

### Connection

Connect to WebSocket endpoint:

```
wss://ws.whoosh.example.com/ws?token=<jwt_token>
```

### Message Types

#### Client → Server

**Suspect Update:**
```json
{
  "type": "SUSPECT",
  "payload": {
    "target": "user_123"
  }
}
```

#### Server → Client

**Tick Update:**
```json
{
  "type": "TICK",
  "payload": {
    "phase": "INTERROGATION",
    "elapsed": 120.5,
    "remaining": 180.5,
    "confmeter": {
      "user_1": "user_123",
      "user_2": "user_456"
    }
  }
}
```

**Breaking News Event:**
```json
{
  "type": "EVENT_NEWS",
  "payload": {
    "message": "Breaking news event!",
    "phase": "VOTING"
  }
}
```

**Game Over:**
```json
{
  "type": "GAME_OVER",
  "payload": {
    "winner_id": "user_123",
    "confmeter": {
      "user_1": "user_123",
      "user_2": "user_456"
    }
  }
}
```

## Error Responses

All errors follow this format:

```json
{
  "error": "Error message here"
}
```

**HTTP Status Codes:**
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `500` - Internal Server Error

