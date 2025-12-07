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
	port          = flag.String("port", "8080", "Server port")
	redisAddr     = flag.String("redis-addr", "localhost:6379", "Redis address")
	redisPassword = flag.String("redis-password", "", "Redis password")
	jwtPublicKey  = flag.String("jwt-public-key", "", "JWT public key (PEM format)")
)

func main() {
	flag.Parse()
	
	// Override with environment variables if set
	if envRedisAddr := os.Getenv("REDIS_ADDR"); envRedisAddr != "" {
		*redisAddr = envRedisAddr
	}
	if envRedisPassword := os.Getenv("REDIS_PASSWORD"); envRedisPassword != "" {
		*redisPassword = envRedisPassword
	}
	if envJWTKey := os.Getenv("JWT_PUBLIC_KEY"); envJWTKey != "" {
		*jwtPublicKey = envJWTKey
	}
	if envPort := os.Getenv("PORT"); envPort != "" {
		*port = envPort
	}

	// Initialize Redis client with retry logic
	redisClient := redis.NewClient(*redisAddr, *redisPassword)
	
	// Retry connection with exponential backoff
	var err error
	for i := 0; i < 5; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		err = redisClient.Ping(ctx).Err()
		cancel()
		
		if err == nil {
			log.Println("Connected to Redis")
			break
		}
		
		if i < 4 {
			waitTime := time.Duration(i+1) * 2 * time.Second
			log.Printf("Failed to connect to Redis (attempt %d/5): %v. Retrying in %v...", i+1, err, waitTime)
			time.Sleep(waitTime)
		}
	}
	
	if err != nil {
		log.Fatalf("Failed to connect to Redis after 5 attempts: %v", err)
	}

	// Load JWT public key (optional - service can work without it for testing)
	var pubKey *rsa.PublicKey
	if *jwtPublicKey != "" {
		block, _ := pem.Decode([]byte(*jwtPublicKey))
		if block == nil {
			log.Printf("Warning: Failed to decode JWT public key - JWT validation will be disabled")
		} else {
			key, err := x509.ParsePKIXPublicKey(block.Bytes)
			if err != nil {
				log.Printf("Warning: Failed to parse JWT public key: %v - JWT validation will be disabled", err)
			} else {
				pubKey = key.(*rsa.PublicKey)
				log.Println("JWT public key loaded successfully")
			}
		}
	} else {
		log.Println("Warning: No JWT public key provided - JWT validation will be disabled")
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

