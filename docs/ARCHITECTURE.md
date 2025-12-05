# Whoosh Architecture

## Overview

Whoosh is a party game platform designed to scale to 1 million+ concurrent users. It uses a hybrid microservices architecture deployed on Amazon EKS (Elastic Kubernetes Service) with AWS Global Accelerator for low-latency global distribution.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Global Accelerator                    │
│              (Static Anycast IP Addresses)                    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)                  │
│  Path Routing: /api/* → Django | /ws/* → Go                  │
└───────────────┬───────────────────────────┬─────────────────┘
                │                           │
                ▼                           ▼
    ┌───────────────────┐       ┌───────────────────┐
    │   Django API      │       │  Go Game Edge     │
    │  (Service A)      │       │  (Service B)      │
    │                   │       │                   │
    │  - Auth           │       │  - WebSocket      │
    │  - Matchmaking    │       │  - Game Loop      │
    │  - User Profiles  │       │  - Real-time      │
    │  - Economy        │       │  - State Mgmt     │
    └─────────┬─────────┘       └─────────┬─────────┘
              │                           │
              │                           │
    ┌─────────┴─────────┐       ┌─────────┴─────────┐
    │                   │       │                   │
    ▼                   ▼       ▼                   ▼
┌──────────┐      ┌──────────┐ ┌──────────┐  ┌──────────┐
│  Aurora  │      │  Redis   │ │  Redis   │  │  Redis   │
│PostgreSQL│      │  Cache   │ │  Cache   │  │  Cache   │
│Serverless│      │          │ │          │  │          │
└──────────┘      └──────────┘ └──────────┘  └──────────┘
```

## Components

### Service A: Django API (The "Brain")

**Purpose:** Stateless REST API for authentication, matchmaking, user profiles, and economy.

**Technology Stack:**
- Python 3.11
- Django 5.0
- Django REST Framework
- Gunicorn (gthread worker class)
- JWT authentication with RSA keys

**Key Features:**
- User registration and authentication
- JWT token management (RSA keys from AWS Secrets Manager)
- Matchmaking queue (Redis-based)
- User profile management (ELO, XP tracking)
- Game result persistence
- Celery workers for async tasks

**Scaling:**
- Horizontal Pod Autoscaling (HPA) based on CPU and request count
- Deployed on ARM64 (Graviton) nodes for cost efficiency

### Service B: Go Game Edge (The "Nervous System")

**Purpose:** Stateful WebSocket server for real-time game loops.

**Technology Stack:**
- Go 1.22+
- Gorilla WebSocket
- Redis for game state cache
- gRPC client for Django API communication

**Key Features:**
- WebSocket connection management
- Game lobby management with mutex-protected state
- 1Hz tick loop for game updates
- Confidence meter updates (in-memory, async Redis writes)
- Breaking news event system (time-based triggers)
- Graceful shutdown (60s timeout)

**Scaling:**
- HPA based on active WebSocket connections
- Deployed on compute-optimized ARM64 nodes (c7g.xlarge)
- Session stickiness enabled (15 minutes)

## Infrastructure

### Networking

**AWS Global Accelerator:**
- Two static Anycast IP addresses
- Routes traffic to nearest AWS edge location
- Traffic rides AWS fiber network to reduce latency

**Application Load Balancer:**
- Path-based routing:
  - `/api/*` → Django Service
  - `/ws/*` → Go Service
- WebSocket support with stickiness
- Idle timeout: 300 seconds

### Compute (Amazon EKS)

**Node Group A: Django Nodes**
- Instance Type: `t4g.medium` (ARM64/Graviton)
- Min: 2, Max: 10 nodes
- Labels: `workload=django-api`

**Node Group B: Go Nodes**
- Instance Type: `c7g.xlarge` (Compute Optimized ARM64)
- Min: 2, Max: 20 nodes
- Labels: `workload=game-engine`
- Taints: `workload=game-engine:NoSchedule`

### Data Layer

**Aurora PostgreSQL Serverless v2:**
- Engine: PostgreSQL 16.1
- Min Capacity: 0.5 ACU
- Max Capacity: 128 ACU
- Auto-scales based on load
- Perfect for viral spikes

**ElastiCache Redis:**
- Mode: Cluster Mode Enabled
- Node Type: `cache.r7g.large`
- Nodes: 3 (configurable)
- Eviction Policy: `volatile-ttl`
- Encryption: At-rest and in-transit
- Multi-AZ enabled

## Data Flows

### Flow 1: Confidence Meter Update (High Frequency)

1. Mobile client sends `{"t": "SUSPECT", "target": "user_123"}` via WebSocket
2. Global Accelerator routes to EKS Ingress
3. ALB routes to Go Pod hosting the game lobby
4. Go service:
   - Locks mutex
   - Updates `GameLobby.ConfMeter["sender_id"] = "user_123"`
   - Unlocks mutex
   - NO DB WRITE (pure memory operation)
5. On tick: Writes aggregated score snapshot to Redis (async)

### Flow 2: Game Over (Persistence)

1. Go service timer hits 0
2. Calculates final result
3. Sends gRPC message to Django service (internal ClusterIP)
4. Django service:
   - Receives game result
   - Writes to Aurora PostgreSQL (`INSERT INTO match_history...`)
   - Updates user ELO/XP
5. Go service closes WebSockets and cleans up memory

## Security

- JWT authentication with RSA keys stored in AWS Secrets Manager
- VPC isolation with private subnets for databases
- Security groups restrict access to necessary ports only
- Encryption at rest and in transit for databases
- IAM roles with least privilege principle

## Monitoring & Observability

- CloudWatch Logs for application logs
- CloudWatch Metrics for infrastructure metrics
- Kubernetes metrics for pod-level monitoring
- Health checks for both services

## Deployment

- CI/CD via AWS CodePipeline
- Docker images stored in Amazon ECR
- Kubernetes manifests for declarative deployments
- Terraform for Infrastructure as Code

## Cost Optimization

- ARM64/Graviton instances (20% better price/performance)
- Aurora Serverless v2 (pay only for what you use)
- EKS node groups sized appropriately
- Auto-scaling to handle traffic spikes efficiently

