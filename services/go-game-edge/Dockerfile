# Multi-stage build for Go WebSocket service
# Supports ARM64 (primary) and AMD64 (fallback)

# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary for ARM64
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
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

