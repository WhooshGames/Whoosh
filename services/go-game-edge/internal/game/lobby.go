package game

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/whooshgames/whoosh/go-game-edge/internal/redis"
	"github.com/whooshgames/whoosh/go-game-edge/internal/websocket"
)

// Phase represents the current game phase
type Phase string

const (
	PhaseWaiting     Phase = "WAITING"
	PhaseInterrogation Phase = "INTERROGATION"
	PhaseVoting      Phase = "VOTING"
	PhaseFinished    Phase = "FINISHED"
)

// Lobby represents one active game match
type Lobby struct {
	ID          string
	Phase       Phase
	TickRate    *time.Ticker
	Clients     map[*websocket.Client]bool
	ConfMeter   map[string]string // userID -> suspectID
	Mutex       sync.RWMutex
	startTime   time.Time
	redis       *redis.Client
	stopChan    chan struct{}
	gameDuration time.Duration // 5 minutes default
}

// NewLobby creates a new game lobby
func NewLobby(gameID string, redisClient *redis.Client) *Lobby {
	return &Lobby{
		ID:          gameID,
		Phase:       PhaseWaiting,
		Clients:     make(map[*websocket.Client]bool),
		ConfMeter:   make(map[string]string),
		startTime:   time.Now(),
		redis:       redisClient,
		stopChan:    make(chan struct{}),
		gameDuration: 5 * time.Minute,
	}
}

// Start starts the game lobby tick loop
func (l *Lobby) Start() {
	l.Mutex.Lock()
	l.Phase = PhaseInterrogation
	l.TickRate = time.NewTicker(1 * time.Second) // 1Hz tick rate
	l.Mutex.Unlock()

	go l.tickLoop()
}

// Stop stops the game lobby
func (l *Lobby) Stop() {
	close(l.stopChan)
	if l.TickRate != nil {
		l.TickRate.Stop()
	}
}

// AddClient adds a WebSocket client to the lobby
func (l *Lobby) AddClient(client *websocket.Client) {
	l.Mutex.Lock()
	defer l.Mutex.Unlock()
	l.Clients[client] = true
}

// RemoveClient removes a WebSocket client from the lobby
func (l *Lobby) RemoveClient(client *websocket.Client) {
	l.Mutex.Lock()
	defer l.Mutex.Unlock()
	delete(l.Clients, client)
}

// UpdateConfidenceMeter updates the confidence meter for a user
func (l *Lobby) UpdateConfidenceMeter(userID, suspectID string) {
	l.Mutex.Lock()
	defer l.Mutex.Unlock()
	l.ConfMeter[userID] = suspectID
}

// GetConfidenceMeter returns a copy of the confidence meter
func (l *Lobby) GetConfidenceMeter() map[string]string {
	l.Mutex.RLock()
	defer l.Mutex.RUnlock()
	
	result := make(map[string]string)
	for k, v := range l.ConfMeter {
		result[k] = v
	}
	return result
}

// Broadcast sends a packet to all clients in the lobby
func (l *Lobby) Broadcast(packet websocket.Packet) {
	l.Mutex.RLock()
	defer l.Mutex.RUnlock()

	data, err := json.Marshal(packet)
	if err != nil {
		return
	}

	for client := range l.Clients {
		select {
		case client.SendChan <- data:
		default:
			// Channel full, skip this client
		}
	}
}

// tickLoop runs the main game loop
func (l *Lobby) tickLoop() {
	for {
		select {
		case <-l.stopChan:
			return
		case <-l.TickRate.C:
			l.processTick()
		}
	}
}

// processTick processes one game tick
func (l *Lobby) processTick() {
	l.Mutex.RLock()
	elapsed := time.Since(l.startTime)
	phase := l.Phase
	l.Mutex.RUnlock()

	// Check for breaking news event (3m30s into game)
	if elapsed >= 3*time.Minute+30*time.Second && phase == PhaseInterrogation {
		l.Mutex.Lock()
		l.Phase = PhaseVoting
		l.Mutex.Unlock()

		l.Broadcast(websocket.Packet{
			Type: "EVENT_NEWS",
			Payload: map[string]interface{}{
				"message": "Breaking news event!",
				"phase":   "VOTING",
			},
		})
	}

	// Check for game end
	if elapsed >= l.gameDuration {
		l.endGame()
		return
	}

	// Update scores and broadcast state
	l.updateScores()
	l.broadcastState()
}

// updateScores updates game scores (async Redis write)
func (l *Lobby) updateScores() {
	confMeter := l.GetConfidenceMeter()
	
	// Write to Redis asynchronously
	go func() {
		ctx := context.Background()
		data, _ := json.Marshal(confMeter)
		l.redis.Set(ctx, "game:"+l.ID+":confmeter", data, time.Minute*10)
	}()
}

// broadcastState broadcasts current game state
func (l *Lobby) broadcastState() {
	l.Mutex.RLock()
	phase := l.Phase
	elapsed := time.Since(l.startTime)
	remaining := l.gameDuration - elapsed
	l.Mutex.RUnlock()

	l.Broadcast(websocket.Packet{
		Type: "TICK",
		Payload: map[string]interface{}{
			"phase":     string(phase),
			"elapsed":   elapsed.Seconds(),
			"remaining": remaining.Seconds(),
			"confmeter": l.GetConfidenceMeter(),
		},
	})
}

// endGame ends the game and calculates results
func (l *Lobby) endGame() {
	l.Mutex.Lock()
	l.Phase = PhaseFinished
	l.Mutex.Unlock()

	// Calculate final results
	confMeter := l.GetConfidenceMeter()
	
	// Determine winner (placeholder logic - to be implemented based on game rules)
	winnerID := ""
	if len(confMeter) > 0 {
		// Simple logic: most suspected player wins (placeholder)
		suspectCounts := make(map[string]int)
		for _, suspectID := range confMeter {
			suspectCounts[suspectID]++
		}
		
		maxCount := 0
		for suspectID, count := range suspectCounts {
			if count > maxCount {
				maxCount = count
				winnerID = suspectID
			}
		}
	}

	// Broadcast game over
	l.Broadcast(websocket.Packet{
		Type: "GAME_OVER",
		Payload: map[string]interface{}{
			"winner_id": winnerID,
			"confmeter": confMeter,
		},
	})

	// Send result to Django API (gRPC call would go here)
	// For now, we'll use HTTP
	go l.sendGameResult(winnerID, confMeter)

	// Close all connections after a delay
	time.Sleep(5 * time.Second)
	l.Stop()
}

// sendGameResult sends game result to Django API
func (l *Lobby) sendGameResult(winnerID string, confMeter map[string]string) {
	// This would typically be a gRPC call
	// For now, placeholder for HTTP call
	// Implementation would go in internal/grpc package
}

