# Whoosh Development Guide

## Local Development Setup

### Prerequisites

- Docker and Docker Compose
- Python 3.11+ (for local Django development)
- Go 1.22+ (for local Go development)
- PostgreSQL client (optional, for direct DB access)
- Redis client (optional, for direct cache access)

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/WhooshGames/Whoosh.git
   cd Whoosh
   ```

2. **Start all services:**
   ```bash
   make up
   ```

   This will start:
   - PostgreSQL database
   - Redis cache
   - Django API (port 8000)
   - Go Game Edge (port 8080)

3. **Run migrations:**
   ```bash
   make migrate
   ```

4. **Create a superuser (optional):**
   ```bash
   make django-createsuperuser
   ```

5. **Access services:**
   - Django API: http://localhost:8000
   - Go Game Edge: ws://localhost:8080/ws
   - Django Admin: http://localhost:8000/admin

### Development Workflow

#### Django API Development

1. **Activate virtual environment (if using local Python):**
   ```bash
   cd services/django-api
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Run Django development server:**
   ```bash
   python manage.py runserver
   ```

3. **Run tests:**
   ```bash
   python manage.py test
   ```

4. **Access Django shell:**
   ```bash
   make django-shell
   # or
   python manage.py shell
   ```

#### Go Game Edge Development

1. **Install dependencies:**
   ```bash
   cd services/go-game-edge
   go mod download
   ```

2. **Run locally:**
   ```bash
   make go-run
   # or
   go run ./cmd/server
   ```

3. **Build binary:**
   ```bash
   make go-build
   ```

4. **Run tests:**
   ```bash
   go test ./...
   ```

### Environment Variables

Create `.env` files for local development:

**services/django-api/.env:**
```env
DEBUG=True
SECRET_KEY=dev-secret-key
DB_HOST=localhost
DB_NAME=whoosh
DB_USER=postgres
DB_PASSWORD=postgres
DB_PORT=5432
REDIS_HOST=localhost
REDIS_PORT=6379
AWS_REGION=us-east-1
```

**services/go-game-edge/.env:**
```env
REDIS_ADDR=localhost:6379
JWT_PUBLIC_KEY=<your-public-key>
```

### Database Management

**Run migrations:**
```bash
make migrate
```

**Create migrations:**
```bash
docker-compose exec django-api python manage.py makemigrations
```

**Reset database:**
```bash
docker-compose down -v
docker-compose up -d postgres
make migrate
```

### Testing

#### Django Tests

```bash
# Run all tests
make test

# Run specific app tests
docker-compose exec django-api python manage.py test apps.auth

# Run with coverage
docker-compose exec django-api coverage run --source='.' manage.py test
docker-compose exec django-api coverage report
```

#### Go Tests

```bash
cd services/go-game-edge
go test ./...
go test -v ./...
go test -cover ./...
```

### API Testing

#### Using curl

```bash
# Register user
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"testpass123"}'

# Login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass123"}'

# Get user profile (replace TOKEN with actual token)
curl -X GET http://localhost:8000/api/users/me \
  -H "Authorization: Bearer TOKEN"
```

#### Using WebSocket

```bash
# Install wscat
npm install -g wscat

# Connect to WebSocket
wscat -c "ws://localhost:8080/ws?token=YOUR_JWT_TOKEN"

# Send message
{"type":"SUSPECT","payload":{"target":"user_123"}}
```

### Code Quality

#### Python

```bash
# Format code
black services/django-api/

# Lint code
flake8 services/django-api/

# Type checking
mypy services/django-api/
```

#### Go

```bash
# Format code
go fmt ./services/go-game-edge/...

# Lint code
golangci-lint run ./services/go-game-edge/...

# Vet code
go vet ./services/go-game-edge/...
```

### Debugging

#### Django Debugging

1. **Use Django Debug Toolbar** (add to INSTALLED_APPS in development)
2. **Use print statements or logging:**
   ```python
   import logging
   logger = logging.getLogger(__name__)
   logger.debug("Debug message")
   ```

3. **Use Django shell:**
   ```bash
   make django-shell
   ```

#### Go Debugging

1. **Use Delve debugger:**
   ```bash
   dlv debug ./cmd/server
   ```

2. **Add logging:**
   ```go
   import "log"
   log.Printf("Debug: %v", value)
   ```

### Common Issues

#### Port Already in Use

```bash
# Find process using port
lsof -i :8000
lsof -i :8080

# Kill process
kill -9 <PID>
```

#### Database Connection Errors

Ensure PostgreSQL is running:
```bash
docker-compose ps postgres
```

#### Redis Connection Errors

Ensure Redis is running:
```bash
docker-compose ps redis
```

### Project Structure

```
Whoosh/
├── services/
│   ├── django-api/          # Django REST API
│   │   ├── apps/            # Django apps
│   │   ├── whoosh_api/      # Django project
│   │   └── manage.py
│   └── go-game-edge/        # Go WebSocket service
│       ├── cmd/             # Application entry points
│       └── internal/        # Internal packages
├── infrastructure/
│   ├── terraform/           # Infrastructure as Code
│   ├── k8s/                 # Kubernetes manifests
│   └── cicd/                # CI/CD configuration
├── docs/                     # Documentation
├── docker-compose.yml        # Local development setup
└── Makefile                  # Common commands
```

### Contributing

1. Create a feature branch
2. Make your changes
3. Write/update tests
4. Ensure all tests pass
5. Submit a pull request

### Useful Commands

```bash
# View logs
make logs

# Stop services
make down

# Clean everything
make clean

# Rebuild images
make build

# Django shell
make django-shell

# Go build
make go-build
```

