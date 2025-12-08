package redis

import (
	"context"
	"crypto/tls"
	"time"

	"github.com/redis/go-redis/v9"
)

// Client wraps the Redis client
type Client struct {
	*redis.Client
}

// NewClient creates a new Redis client
// For ElastiCache with transit encryption, we need to use TLS
func NewClient(addr string, password string) *Client {
	// ElastiCache with transit encryption requires TLS
	// Even though encryption is at network layer, the client must use TLS
	tlsConfig := &tls.Config{
		InsecureSkipVerify: true, // ElastiCache uses self-signed certs
	}
	
	rdb := redis.NewClient(&redis.Options{
		Addr:         addr,
		Password:     password,
		DB:           0,  // use default DB
		TLSConfig:    tlsConfig,
		DialTimeout:  30 * time.Second,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		MaxRetries:   3,
		MinRetryBackoff: 100 * time.Millisecond,
		MaxRetryBackoff: 3 * time.Second,
	})

	return &Client{Client: rdb}
}

// Ping tests the connection
func (c *Client) Ping(ctx context.Context) error {
	return c.Client.Ping(ctx).Err()
}

