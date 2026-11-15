# Coincoin

Blockchain permissionada com consenso tolerante a falhas bizantinas e smart contracts,
desenvolvida como projeto da disciplina de Sistemas Distribuídos (IFCE).

## Partes

| Pasta | Conteúdo | Estado |
|---|---|---|
| `app/` | Cliente iOS em Swift/UIKit (carteira e cliente leve) | Em construção |
| `node/` | Nó validador em Go | Não iniciado |
| `api/` | Contrato HTTP entre app e nó: a fonte da verdade | Rascunho |
| `deploy/` | Docker Compose da rede de nós | Não iniciado |
| `experiments/` | Scripts e resultados dos experimentos de falha | Não iniciado |
| `testvectors/` | Chave, payload e assinatura de referência (gerados pelo app) | Não iniciado |
| `docs/` | Relatório e registro de decisões | Em andamento |

## Fases

0. Ambiente e repositório
1. App com mock
2. Vetores de teste de assinatura
3. Fundamentos do nó: sockets, framing, heartbeat
4. Rede em Docker com gossip
5. Cadeia e API HTTP real
6. Integração app ↔ nó
7. Consenso bizantino
8. Experimentos de falha
9. Smart contracts
10. Demonstração na LAN e relatório
