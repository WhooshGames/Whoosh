package main

import (
	"context"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/whooshgames/whoosh/go-game-edge/internal/game"
	"github.com/whooshgames/whoosh/go-game-edge/internal/redis"
	"github.com/whooshgames/whoosh/go-game-edge/internal/websocket"
)

var (
	port         = flag.String("port", "8080", "Server port")
	redisAddr    = flag.String("redis-addr", "localhost:6379", "Redis address")
	jwtPublicKey = flag.String("jwt-public-key", "", "JWT public key (PEM format)")
)

func main() {
	flag.Parse()
	
	// Override with environment variables if set
	if envRedisAddr := os.Getenv("REDIS_ADDR"); envRedisAddr != "" {
		*redisAddr = envRedisAddr
	}
	if envJWTKey := os.Getenv("JWT_PUBLIC_KEY"); envJWTKey != "" {
		*jwtPublicKey = envJWTKey
	}
	if envPort := os.Getenv("PORT"); envPort != "" {
		*port = envPort
	}

	// Initialize Redis client
	redisClient := redis.NewClient(*redisAddr)
	if err := redisClient.Ping(context.Background()); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	log.Println("Connected to Redis")

	// Load JWT public key
	var pubKey *rsa.PublicKey
	if *jwtPublicKey != "" {
		block, _ := pem.Decode([]byte(*jwtPublicKey))
		if block == nil {
			log.Fatalf("Failed to decode JWT public key")
		}
		key, err := x509.ParsePKIXPublicKey(block.Bytes)
		if err != nil {
			log.Fatalf("Failed to parse JWT public key: %v", err)
		}
		pubKey = key.(*rsa.PublicKey)
	}

	// Initialize game manager
	gameManager := game.NewManager(redisClient, pubKey)

	// Setup HTTP server
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", websocket.HandleWebSocket(gameManager))
	mux.HandleFunc("/health", healthCheck)

	server := &http.Server{
		Addr:         ":" + *port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  300 * time.Second, // 5 minutes for WebSocket connections
	}

	// Graceful shutdown
	go func() {
		sigint := make(chan os.Signal, 1)
		signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
		<-sigint

		log.Println("Shutting down server...")
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()

		// Stop accepting new connections
		if err := server.Shutdown(ctx); err != nil {
			log.Printf("Server shutdown error: %v", err)
		}

		// Gracefully close all game lobbies
		gameManager.Shutdown(ctx)
		log.Println("Server stopped")
	}()

	log.Printf("Starting server on port %s", *port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server failed: %v", err)
	}
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "OK")
}

