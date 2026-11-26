package config

import (
	"errors"
	"flag"
	"fmt"
	"net"
	"strings"
)

type Peer struct {
	ID      string
	Address string
}

type Config struct {
	ID     string
	Listen string
	Peers  []Peer
}

func Parse(args []string) (Config, error) {
	flags := flag.NewFlagSet("coincoin-node", flag.ContinueOnError)
	id := flags.String("id", "", "identificador deste nó (ex.: n1)")
	listen := flags.String("listen", "127.0.0.1:7001", "endereço TCP onde este nó escuta")
	peers := flags.String("peers", "", "outros nós, separados por vírgula (ex.: n2@127.0.0.1:7002,n3@127.0.0.1:7003)")
	if err := flags.Parse(args); err != nil {
		return Config{}, err
	}

	cfg := Config{ID: *id, Listen: *listen}
	if cfg.ID == "" {
		return Config{}, errors.New("-id é obrigatório")
	}
	if err := checkAddress(cfg.Listen); err != nil {
		return Config{}, fmt.Errorf("-listen: %w", err)
	}

	seen := map[string]bool{cfg.ID: true}
	for _, entry := range splitList(*peers) {
		peer, err := parsePeer(entry)
		if err != nil {
			return Config{}, fmt.Errorf("-peers: %w", err)
		}
		if seen[peer.ID] {
			return Config{}, fmt.Errorf("-peers: id repetido ou igual ao deste nó: %q", peer.ID)
		}
		seen[peer.ID] = true
		cfg.Peers = append(cfg.Peers, peer)
	}
	return cfg, nil
}

func splitList(text string) []string {
	var items []string
	for item := range strings.SplitSeq(text, ",") {
		if item = strings.TrimSpace(item); item != "" {
			items = append(items, item)
		}
	}
	return items
}

func parsePeer(entry string) (Peer, error) {
	id, address, found := strings.Cut(entry, "@")
	if !found || id == "" {
		return Peer{}, fmt.Errorf("%q deveria ser id@host:porta", entry)
	}
	if err := checkAddress(address); err != nil {
		return Peer{}, fmt.Errorf("%q: %w", entry, err)
	}
	return Peer{ID: id, Address: address}, nil
}

func checkAddress(address string) error {
	host, port, err := net.SplitHostPort(address)
	if err != nil {
		return fmt.Errorf("endereço inválido %q", address)
	}
	if host == "" || port == "" {
		return fmt.Errorf("endereço %q precisa de host e porta", address)
	}
	return nil
}
