package websocket

import (
	"crypto/rsa"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"github.com/whooshgames/whoosh/go-game-edge/internal/game"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// In production, validate origin properly
		return true
	},
}

// HandleWebSocket handles WebSocket connections
func HandleWebSocket(gameManager *game.Manager) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Get JWT token from query parameter or Authorization header
		token := r.URL.Query().Get("token")
		if token == "" {
			authHeader := r.Header.Get("Authorization")
			if strings.HasPrefix(authHeader, "Bearer ") {
				token = strings.TrimPrefix(authHeader, "Bearer ")
			}
		}
		if token == "" {
			http.Error(w, "Missing token", http.StatusUnauthorized)
			return
		}

		// Get gameID from query parameter
		gameID := r.URL.Query().Get("game_id")
		if gameID == "" {
			http.Error(w, "Missing game_id", http.StatusBadRequest)
			return
		}

		// Validate JWT and extract user info
		userID, isGuest, displayName, err := validateJWT(token, gameManager.GetJWTPublicKey())
		if err != nil {
			log.Printf("JWT validation error: %v", err)
			http.Error(w, "Invalid token", http.StatusUnauthorized)
			return
		}

		// Upgrade connection
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("WebSocket upgrade error: %v", err)
			return
		}

		// Get or create lobby
		lobby := gameManager.GetOrCreateLobby(gameID)

		// Create client with user info
		client := NewClient(conn, userID, gameID, isGuest, displayName)
		lobby.AddClient(client)

		// Start client goroutines
		go client.WritePump()
		go client.ReadPump(func(message []byte) {
			handleMessage(client, lobby, message)
		})

		displayNameForLog := displayName
		if displayNameForLog == "" {
			displayNameForLog = userID
		}
		log.Printf("Client connected: user=%s, display_name=%s, is_guest=%v, game=%s", userID, displayNameForLog, isGuest, gameID)
	}
}

// validateJWT validates JWT token and returns userID, isGuest, displayName
func validateJWT(tokenString string, pubKey interface{}) (userID string, isGuest bool, displayName string, err error) {
	if pubKey == nil {
		return "", false, "", errors.New("JWT public key not configured")
	}

	rsaPubKey, ok := pubKey.(*rsa.PublicKey)
	if !ok {
		return "", false, "", errors.New("invalid public key type")
	}

	// Parse and validate token
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		// Validate algorithm
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return rsaPubKey, nil
	}, jwt.WithValidMethods([]string{"RS256"}))

	if err != nil {
		return "", false, "", fmt.Errorf("failed to parse token: %w", err)
	}

	if !token.Valid {
		return "", false, "", errors.New("invalid token")
	}

	// Extract claims
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", false, "", errors.New("invalid token claims")
	}

	// Extract user_id
	userIDVal, ok := claims["user_id"]
	if !ok {
		return "", false, "", errors.New("missing user_id in token")
	}
	userID = fmt.Sprintf("%v", userIDVal)

	// Extract is_guest (default to false if not present)
	isGuest = false
	if isGuestVal, ok := claims["is_guest"]; ok {
		if isGuestBool, ok := isGuestVal.(bool); ok {
			isGuest = isGuestBool
		}
	}

	// Extract display_name (optional)
	if displayNameVal, ok := claims["display_name"]; ok {
		if displayNameStr, ok := displayNameVal.(string); ok {
			displayName = displayNameStr
		}
	}

	return userID, isGuest, displayName, nil
}

// handleMessage handles incoming WebSocket messages
func handleMessage(client *Client, lobby *game.Lobby, message []byte) {
	var packet Packet
	if err := json.Unmarshal(message, &packet); err != nil {
		return
	}

	switch packet.Type {
	case "SUSPECT":
		// Update confidence meter
		if payload, ok := packet.Payload.(map[string]interface{}); ok {
			if target, ok := payload["target"].(string); ok {
				lobby.UpdateConfidenceMeter(client.UserID, target)
			}
		}
	default:
		// Unknown message type
	}
}

