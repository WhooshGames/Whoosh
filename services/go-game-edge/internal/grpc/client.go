package grpc

import (
	"context"
	"log"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Client represents a gRPC client for Django API
type Client struct {
	conn   *grpc.ClientConn
	addr   string
}

// NewClient creates a new gRPC client
func NewClient(addr string) (*Client, error) {
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, err
	}

	return &Client{
		conn: conn,
		addr: addr,
	}, nil
}

// SendGameResult sends game result to Django API
// This is a placeholder - implement proper gRPC service definition
func (c *Client) SendGameResult(ctx context.Context, gameID, winnerID string, participants map[string]interface{}) error {
	// TODO: Implement gRPC call to Django API
	// This would require:
	// 1. Define .proto file for game result service
	// 2. Generate Go code from proto
	// 3. Implement the actual gRPC call here
	log.Printf("Sending game result: game=%s, winner=%s", gameID, winnerID)
	return nil
}

// Close closes the gRPC connection
func (c *Client) Close() error {
	return c.conn.Close()
}

