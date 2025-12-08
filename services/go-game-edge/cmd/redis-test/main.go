package main

import (
	"context"
	"crypto/tls"
	"flag"
	"log"
	"net"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

func main() {
	addr := flag.String("addr", "", "Redis address (host:port)")
	password := flag.String("password", "", "Redis password")
	useTLS := flag.Bool("tls", false, "Use TLS")
	flag.Parse()

	if *addr == "" {
		*addr = os.Getenv("REDIS_ADDR")
	}
	if *password == "" {
		*password = os.Getenv("REDIS_PASSWORD")
	}

	log.Printf("=== Redis Connection Test ===")
	log.Printf("Address: %s", *addr)
	log.Printf("Password: %s", func() string {
		if *password != "" {
			return "***SET***"
		}
		return "NOT SET"
	}())
	log.Printf("TLS: %v", *useTLS)

	// Test 1: Basic connection without TLS
	log.Println("\n--- Test 1: Basic Connection (no TLS) ---")
	opts1 := &redis.Options{
		Addr:         *addr,
		Password:     *password,
		DB:           0,
		DialTimeout:  10 * time.Second,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,
	}
	client1 := redis.NewClient(opts1)
	
	ctx1, cancel1 := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel1()
	
	start := time.Now()
	err1 := client1.Ping(ctx1).Err()
	duration := time.Since(start)
	
	if err1 == nil {
		log.Printf("✅ SUCCESS: Connected in %v", duration)
	} else {
		log.Printf("❌ FAILED: %v (took %v)", err1, duration)
	}
	client1.Close()

	// Test 2: Connection with TLS (if enabled)
	if *useTLS {
		log.Println("\n--- Test 2: Connection with TLS ---")
		opts2 := &redis.Options{
			Addr:         *addr,
			Password:     *password,
			DB:           0,
			TLSConfig: &tls.Config{
				InsecureSkipVerify: true, // For testing
			},
			DialTimeout:  10 * time.Second,
			ReadTimeout:  5 * time.Second,
			WriteTimeout: 5 * time.Second,
		}
		client2 := redis.NewClient(opts2)
		
		ctx2, cancel2 := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel2()
		
		start = time.Now()
		err2 := client2.Ping(ctx2).Err()
		duration = time.Since(start)
		
		if err2 == nil {
			log.Printf("✅ SUCCESS with TLS: Connected in %v", duration)
		} else {
			log.Printf("❌ FAILED with TLS: %v (took %v)", err2, duration)
		}
		client2.Close()
	}

	// Test 3: DNS resolution
	log.Println("\n--- Test 3: DNS Resolution ---")
	host := *addr
	// Extract hostname (remove port if present)
	for i := len(host) - 1; i >= 0; i-- {
		if host[i] == ':' {
			host = host[:i]
			break
		}
	}
	log.Printf("Resolving hostname: %s", host)
	
	// Try to resolve DNS
	ips, err3 := net.LookupIP(host)
	if err3 != nil {
		log.Printf("❌ DNS resolution failed: %v", err3)
	} else {
		log.Printf("✅ DNS resolved to: %v", ips)
	}

	// Test 4: Raw TCP connection
	log.Println("\n--- Test 4: Raw TCP Connection ---")
	conn, err4 := net.DialTimeout("tcp", *addr, 5*time.Second)
	if err4 != nil {
		log.Printf("❌ TCP connection failed: %v", err4)
	} else {
		log.Printf("✅ TCP connection successful")
		conn.Close()
	}

	fmt.Println("\n=== Test Complete ===")
}

