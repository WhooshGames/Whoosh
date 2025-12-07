package game

// Client represents a WebSocket client connection
// This interface breaks the circular dependency between game and websocket packages
type Client interface {
	GetUserID() string
	GetGameID() string
	Send(data []byte) error
	GetSendChan() chan []byte
}

