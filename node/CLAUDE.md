# Nó (Coincoin) — instruções para o Claude Code

## Papel
Nó validador: conversa com os outros nós por TCP, mantém a cadeia, participa do consenso
bizantino (n = 4, f = 1, quórum 2f + 1) e atende o app pela API HTTP de `api/contrato.md`.

## Plataforma
- Go (versão em `go.mod`), módulo `github.com/SolFreire/Coincoin/node`.
- Só biblioteca padrão para rede, P2P e consenso (ADR 0002). Dependência externa só com ADR.
- Binário em `cmd/coincoin-node`; pacotes em `internal/` (não importáveis de fora).

## Rede
- Nada que chega da rede é confiável: toda leitura tem limite de tamanho e prazo (deadline).
- O nó escuta em loopback (`127.0.0.1`) por padrão. Escutar em outra interface é decisão
  explícita: dentro do Docker (fase 4) e na demonstração em LAN (fase 10).
- Toda operação de rede recebe um `context.Context` e para quando ele é cancelado.

## Convenções
- Valores monetários em `uint64`. Nunca ponto flutuante.
- Assinaturas e chaves seguem `api/contrato.md` e são conferidas com `testvectors/`.
- Logs com `log/slog`, sempre com o id do nó.
- Nomes no código em inglês; mensagens de erro e logs em português.
- Testes com `go test -race ./...` antes de considerar uma tarefa concluída.
- `gofmt` e `go vet` sem avisos.

## Estrutura (alvo)