package game

import (
	"context"
	"sync"

	"github.com/whooshgames/whoosh/go-game-edge/internal/redis"
)

// Manager manages all game lobbies
type Manager struct {
	lobbies    map[string]*Lobby
	lobbiesMux sync.RWMutex
	redis      *redis.Client
	jwtPubKey  interface{} // *rsa.PublicKey
}

// NewManager creates a new game manager
func NewManager(redisClient *redis.Client, jwtPubKey interface{}) *Manager {
	return &Manager{
		lobbies:   make(map[string]*Lobby),
		redis:     redisClient,
		jwtPubKey: jwtPubKey,
	}
}

// GetOrCreateLobby gets an existing lobby or creates a new one
func (m *Manager) GetOrCreateLobby(gameID string) *Lobby {
	m.lobbiesMux.Lock()
	defer m.lobbiesMux.Unlock()

	lobby, exists := m.lobbies[gameID]
	if !exists {
		lobby = NewLobby(gameID, m.redis)
		m.lobbies[gameID] = lobby
		go lobby.Start()
	}
	return lobby
}

// GetLobby gets an existing lobby
func (m *Manager) GetLobby(gameID string) (*Lobby, bool) {
	m.lobbiesMux.RLock()
	defer m.lobbiesMux.RUnlock()

	lobby, exists := m.lobbies[gameID]
	return lobby, exists
}

// RemoveLobby removes a lobby
func (m *Manager) RemoveLobby(gameID string) {
	m.lobbiesMux.Lock()
	defer m.lobbiesMux.Unlock()

	if lobby, exists := m.lobbies[gameID]; exists {
		lobby.Stop()
		delete(m.lobbies, gameID)
	}
}

// Shutdown gracefully shuts down all lobbies
func (m *Manager) Shutdown(ctx context.Context) {
	m.lobbiesMux.Lock()
	defer m.lobbiesMux.Unlock()

	for gameID, lobby := range m.lobbies {
		lobby.Stop()
		delete(m.lobbies, gameID)
	}
}

// GetJWTPublicKey returns the JWT public key
func (m *Manager) GetJWTPublicKey() interface{} {
	return m.jwtPubKey
}

