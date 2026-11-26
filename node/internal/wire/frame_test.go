package wire

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"testing"
	"testing/iotest"
)

func TestQuadrosChegamSeparadosEInteiros(t *testing.T) {
	var stream bytes.Buffer
	sent := [][]byte{[]byte("primeiro"), {}, []byte("terceiro, mais longo")}
	for _, payload := range sent {
		if err := WriteFrame(&stream, payload); err != nil {
			t.Fatalf("WriteFrame: %v", err)
		}
	}

	for i, want := range sent {
		got, err := ReadFrame(&stream)
		if err != nil {
			t.Fatalf("quadro %d: %v", i, err)
		}
		if !bytes.Equal(got, want) {
			t.Errorf("quadro %d = %q; esperado %q", i, got, want)
		}
	}
	if _, err := ReadFrame(&stream); err != io.EOF {
		t.Errorf("fim do fluxo = %v; esperado io.EOF", err)
	}
}

func TestLeituraPicotadaRemontaOQuadro(t *testing.T) {
	var stream bytes.Buffer
	if err := WriteFrame(&stream, []byte("chega um byte por vez")); err != nil {
		t.Fatal(err)
	}

	got, err := ReadFrame(iotest.OneByteReader(&stream))
	if err != nil {
		t.Fatalf("ReadFrame: %v", err)
	}
	if string(got) != "chega um byte por vez" {
		t.Errorf("quadro = %q", got)
	}
}

func TestQuadroGrandeDemaisERecusadoNaEscrita(t *testing.T) {
	var stream bytes.Buffer
	err := WriteFrame(&stream, make([]byte, MaxFrameSize+1))
	if !errors.Is(err, ErrFrameTooLarge) {
		t.Fatalf("erro = %v; esperado ErrFrameTooLarge", err)
	}
	if stream.Len() != 0 {
		t.Errorf("%d bytes escritos; não deveria escrever nada", stream.Len())
	}
}

func TestCabecalhoMentirosoNaoAlocaOCorpo(t *testing.T) {
	var header [headerSize]byte
	binary.BigEndian.PutUint32(header[:], 0xFFFFFFFF)

	_, err := ReadFrame(bytes.NewReader(header[:]))
	if !errors.Is(err, ErrFrameTooLarge) {
		t.Fatalf("erro = %v; esperado ErrFrameTooLarge", err)
	}
}

func TestQuadroCortadoEErroNaoFimNormal(t *testing.T) {
	var full bytes.Buffer
	if err := WriteFrame(&full, []byte("conteúdo")); err != nil {
		t.Fatal(err)
	}
	data := full.Bytes()

	cases := map[string][]byte{
		"cabeçalho pela metade": data[:2],
		"corpo pela metade":     data[:headerSize+3],
	}
	for name, cut := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := ReadFrame(bytes.NewReader(cut))
			if err != io.ErrUnexpectedEOF {
				t.Errorf("erro = %v; esperado io.ErrUnexpectedEOF", err)
			}
		})
	}
}

func TestMensagensAtravessamUmaConexao(t *testing.T) {
	client, server := net.Pipe()
	defer client.Close()
	defer server.Close()

	sent := []Message{
		{Type: "ping"},
		{Type: "hello", Payload: []byte(`{"node":"n1"}`)},
	}
	go func() {
		for _, message := range sent {
			if err := Send(client, message); err != nil {
				t.Errorf("Send: %v", err)
				return
			}
		}
	}()

	for _, want := range sent {
		got, err := Receive(server)
		if err != nil {
			t.Fatalf("Receive: %v", err)
		}
		if got.Type != want.Type || !bytes.Equal(got.Payload, want.Payload) {
			t.Errorf("mensagem = %+v; esperado %+v", got, want)
		}
	}
}

func TestMensagemMalformadaERecusada(t *testing.T) {
	cases := map[string][]byte{
		"não é JSON":     []byte("isto não é json"),
		"sem tipo":       []byte(`{"payload":{}}`),
		"tipo vazio":     []byte(`{"type":""}`),
		"tipo não texto": []byte(`{"type":42}`),
	}
	for name, payload := range cases {
		t.Run(name, func(t *testing.T) {
			var stream bytes.Buffer
			if err := WriteFrame(&stream, payload); err != nil {
				t.Fatal(err)
			}
			if _, err := Receive(&stream); !errors.Is(err, ErrMalformed) {
				t.Errorf("erro = %v; esperado ErrMalformed", err)
			}
		})
	}

	if err := Send(io.Discard, Message{}); !errors.Is(err, ErrMalformed) {
		t.Errorf("Send sem tipo = %v; esperado ErrMalformed", err)
	}
}

func FuzzReadFrame(f *testing.F) {
	var valid bytes.Buffer
	_ = WriteFrame(&valid, []byte(`{"type":"ping"}`))
	f.Add(valid.Bytes())
	f.Add([]byte{0xFF, 0xFF, 0xFF, 0xFF})
	f.Add([]byte{0, 0, 0})

	f.Fuzz(func(t *testing.T, data []byte) {
		payload, err := ReadFrame(bytes.NewReader(data))
		if err == nil && len(payload) > MaxFrameSize {
			t.Fatalf("quadro de %d bytes passou do limite", len(payload))
		}
		_, _ = Receive(bytes.NewReader(data))
	})
}
