# Whoosh

A scalable party game platform designed to support 1 million+ concurrent users, built with Django REST API and Go WebSocket services on AWS EKS.

## Architecture

Whoosh uses a hybrid microservices architecture:

- **Service A (Django API)**: Stateless REST API for authentication, matchmaking, user profiles, and economy
- **Service B (Go Game Edge)**: Stateful WebSocket server for real-time game loops

Both services are deployed on Amazon EKS with AWS Global Accelerator for low-latency global distribution.

## Features

- JWT-based authentication with RSA keys
- Real-time WebSocket game loops (1Hz tick rate)
- Matchmaking queue system
- User profiles with ELO/XP tracking
- Auto-scaling infrastructure
- Multi-AZ deployment for high availability

## Quick Start

### Local Development

1. **Start all services:**
   ```bash
   make up
   ```

2. **Run migrations:**
   ```bash
   make migrate
   ```

3. **Access services:**
   - Django API: http://localhost:8000
   - Go Game Edge: ws://localhost:8080/ws

See [Development Guide](docs/DEVELOPMENT.md) for more details.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - System architecture and design decisions
- [API Documentation](docs/API.md) - REST API and WebSocket API reference
- [Deployment Guide](docs/DEPLOYMENT.md) - Production deployment instructions
- [Development Guide](docs/DEVELOPMENT.md) - Local development setup and workflow

## Project Structure

```
Whoosh/
├── services/
│   ├── django-api/          # Django REST API
│   └── go-game-edge/        # Go WebSocket service
├── infrastructure/
│   ├── terraform/           # Infrastructure as Code
│   ├── k8s/                 # Kubernetes manifests
│   └── cicd/                # CI/CD configuration
├── docs/                     # Documentation
├── docker-compose.yml        # Local development
└── Makefile                  # Common commands
```

## Technology Stack

### Backend
- **Django 5.0** - REST API framework
- **Go 1.22+** - WebSocket game server
- **PostgreSQL 16.1** - Primary database (Aurora Serverless v2)
- **Redis 7.1** - Game state cache (ElastiCache)

### Infrastructure
- **Amazon EKS** - Kubernetes cluster
- **AWS Global Accelerator** - Low-latency routing
- **Application Load Balancer** - Traffic routing
- **Terraform** - Infrastructure as Code
- **AWS CodePipeline** - CI/CD

## Requirements

- Docker and Docker Compose (for local development)
- Terraform >= 1.5.0 (for infrastructure)
- kubectl >= 1.29 (for Kubernetes)
- AWS CLI (for deployment)

## Contributing

1. Create a feature branch
2. Make your changes
3. Write/update tests
4. Ensure all tests pass
5. Submit a pull request

## License

[Add your license here]

## Support

[Add support information here]
