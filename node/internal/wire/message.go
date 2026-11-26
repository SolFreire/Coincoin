package wire

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
)

type Message struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

var ErrMalformed = errors.New("mensagem malformada")

func Send(w io.Writer, message Message) error {
	if message.Type == "" {
		return fmt.Errorf("%w: tipo vazio", ErrMalformed)
	}
	data, err := json.Marshal(message)
	if err != nil {
		return err
	}
	return WriteFrame(w, data)
}

func Receive(r io.Reader) (Message, error) {
	data, err := ReadFrame(r)
	if err != nil {
		return Message{}, err
	}
	var message Message
	if err := json.Unmarshal(data, &message); err != nil {
		return Message{}, fmt.Errorf("%w: %v", ErrMalformed, err)
	}
	if message.Type == "" {
		return Message{}, fmt.Errorf("%w: tipo vazio", ErrMalformed)
	}
	return message, nil
}
