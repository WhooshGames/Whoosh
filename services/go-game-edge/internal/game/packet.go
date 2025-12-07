package game

// Packet represents a WebSocket message packet
type Packet struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload"`
}

