package config

import (
	"reflect"
	"strings"
	"testing"
)

func TestParseAceitaConfiguracaoCompleta(t *testing.T) {
	cfg, err := Parse([]string{
		"-id", "n1",
		"-listen", "127.0.0.1:7001",
		"-peers", "n2@127.0.0.1:7002, n3@127.0.0.1:7003,,n4@127.0.0.1:7004",
	})
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}

	want := Config{
		ID:     "n1",
		Listen: "127.0.0.1:7001",
		Peers: []Peer{
			{ID: "n2", Address: "127.0.0.1:7002"},
			{ID: "n3", Address: "127.0.0.1:7003"},
			{ID: "n4", Address: "127.0.0.1:7004"},
		},
	}
	if !reflect.DeepEqual(cfg, want) {
		t.Errorf("config = %+v; esperado %+v", cfg, want)
	}
}

func TestParseUsaLoopbackPorPadrao(t *testing.T) {
	cfg, err := Parse([]string{"-id", "n1"})
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}
	if cfg.Listen != "127.0.0.1:7001" {
		t.Errorf("listen = %q; o padrão deve ser loopback", cfg.Listen)
	}
}

func TestParseRecusaConfiguracaoInvalida(t *testing.T) {
	cases := []struct {
		name string
		args []string
		want string
	}{
		{"sem id", []string{"-listen", "127.0.0.1:7001"}, "-id"},
		{"listen sem porta", []string{"-id", "n1", "-listen", "127.0.0.1"}, "-listen"},
		{"listen sem host", []string{"-id", "n1", "-listen", ":7001"}, "-listen"},
		{"par sem id", []string{"-id", "n1", "-peers", "127.0.0.1:7002"}, "-peers"},
		{"par com endereço inválido", []string{"-id", "n1", "-peers", "n2@localhost"}, "-peers"},
		{"par repetido", []string{"-id", "n1", "-peers", "n2@127.0.0.1:7002,n2@127.0.0.1:7003"}, "repetido"},
		{"par com o próprio id", []string{"-id", "n1", "-peers", "n1@127.0.0.1:7002"}, "repetido"},
		{"flag desconhecida", []string{"-id", "n1", "-porta", "7001"}, "porta"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := Parse(c.args)
			if err == nil {
				t.Fatalf("esperava erro para %v", c.args)
			}
			if !strings.Contains(err.Error(), c.want) {
				t.Errorf("erro %q não menciona %q", err, c.want)
			}
		})
	}
}
