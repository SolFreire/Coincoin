package wire

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
)

const (
	headerSize   = 4
	MaxFrameSize = 1 << 20
)

var ErrFrameTooLarge = errors.New("quadro maior que o limite")

func WriteFrame(w io.Writer, payload []byte) error {
	if len(payload) > MaxFrameSize {
		return fmt.Errorf("%w: %d bytes", ErrFrameTooLarge, len(payload))
	}
	frame := make([]byte, headerSize+len(payload))
	binary.BigEndian.PutUint32(frame, uint32(len(payload)))
	copy(frame[headerSize:], payload)
	_, err := w.Write(frame)
	return err
}

func ReadFrame(r io.Reader) ([]byte, error) {
	var header [headerSize]byte
	if _, err := io.ReadFull(r, header[:]); err != nil {
		return nil, err
	}
	size := binary.BigEndian.Uint32(header[:])
	if size > MaxFrameSize {
		return nil, fmt.Errorf("%w: cabeçalho anuncia %d bytes", ErrFrameTooLarge, size)
	}
	payload := make([]byte, size)
	if _, err := io.ReadFull(r, payload); err != nil {
		if errors.Is(err, io.EOF) {
			return nil, io.ErrUnexpectedEOF
		}
		return nil, err
	}
	return payload, nil
}
