# Multi-stage build for Go WebSocket service
# Supports ARM64 (primary) and AMD64 (fallback)

# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files first for dependency caching
COPY go.mod go.sum* ./

# Copy source code to determine dependencies
COPY . .

# Download dependencies and tidy (this will create go.sum if it doesn't exist)
RUN go mod download && go mod tidy

# Build static binary for AMD64 (x86_64) - matching t3.micro instances
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o server \
    ./cmd/server

# Runtime stage - use scratch for minimal image
FROM scratch

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary
COPY --from=builder /build/server /server

# Expose port
EXPOSE 8080

# Note: Health check is handled by Kubernetes liveness/readiness probes
# The /health endpoint is available at http://localhost:8080/health

# Run server
ENTRYPOINT ["/server"]

