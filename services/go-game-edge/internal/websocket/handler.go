package websocket

import (
	"encoding/json"
	"log"
	"net/http"

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
		// Get JWT token from query parameter
		token := r.URL.Query().Get("token")
		if token == "" {
			http.Error(w, "Missing token", http.StatusUnauthorized)
			return
		}

		// Validate JWT (placeholder - implement proper JWT validation)
		userID, gameID, err := validateJWT(token)
		if err != nil {
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

		// Create client
		client := NewClient(conn, userID, gameID)
		lobby.AddClient(client)

		// Start client goroutines
		go client.WritePump()
		go client.ReadPump(func(message []byte) {
			handleMessage(client, lobby, message)
		})

		log.Printf("Client connected: user=%s, game=%s", userID, gameID)
	}
}

// validateJWT validates JWT token and returns userID and gameID
// This is a placeholder - implement proper JWT validation with RSA public key
func validateJWT(token string) (userID, gameID string, err error) {
	// TODO: Implement proper JWT validation using RSA public key
	// For now, return placeholder values
	return "user_123", "game_456", nil
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

