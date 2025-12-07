package redis

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

// Client wraps the Redis client
type Client struct {
	*redis.Client
}

// NewClient creates a new Redis client
func NewClient(addr string, password string) *Client {
	rdb := redis.NewClient(&redis.Options{
		Addr:         addr,
		Password:     password,
		DB:           0,  // use default DB
		TLSConfig:    nil, // ElastiCache uses in-transit encryption but doesn't require TLS client config
		DialTimeout:  30 * time.Second,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		MaxRetries:   3,
		MinRetryBackoff: 100 * time.Millisecond,
		MaxRetryBackoff: 3 * time.Second,
		// ElastiCache with transit encryption still uses regular TCP, not TLS
		// The encryption is handled at the network layer
	})

	return &Client{Client: rdb}
}

// Ping tests the connection
func (c *Client) Ping(ctx context.Context) error {
	return c.Client.Ping(ctx).Err()
}

