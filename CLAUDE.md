# Coincoin — instruções para o Claude Code

## Contexto
Projeto acadêmico de Sistemas Distribuídos (Engenharia de Computação, IFCE).
Uma blockchain permissionada: nós validadores em Go, consenso bizantino (n = 4, f = 1,
quórum 2f + 1), VM mínima para contratos, e um app iOS em UIKit como cliente leve.
A autora está aprendendo: o objetivo é o aprendizado dos conceitos, não só o código pronto.

## Como trabalhar comigo
- **Explique antes de escrever.** Para cada mudança, diga qual conceito de Sistemas
  Distribuídos ela exercita (ex.: idempotência, quórum, consistência entre réplicas,
  detecção de falhas, serialização) e por que a decisão foi tomada.
- **Passos pequenos.** Prefira mudanças pequenas e verificáveis a gerar muitos arquivos de uma vez.
  Quando a tarefa for grande, proponha um plano e espere confirmação.
- **Eu escrevo o código quando pedir para aprender.** Se eu disser "me guie", dê a estrutura,
  as dicas e os pontos de atenção, sem entregar a implementação completa.
- **Seja honesto** sobre limitações, alternativas e maturidade das bibliotecas.
- Responda em português.

## Regras do projeto
- `api/contrato.md` é a fonte da verdade da comunicação app ↔ nó. Qualquer mudança
  de endpoint ou formato começa por ele, no mesmo commit que altera app e nó.
- Toda decisão de arquitetura relevante vira um registro curto em `docs/decisoes/`
  (use `/decisao`).
- Nada que chega da rede é confiável: o nó valida tudo, inclusive o que o app já validou.
- Valores monetários são inteiros (`UInt64` / `uint64`). Nunca ponto flutuante.
- Assinaturas: ECDSA P-256, chaves e assinaturas em DER, payload assinado enviado como bytes exatos.

## Mapa
- `app/` — cliente iOS. Veja `app/CLAUDE.md`.
- `node/` — nó em Go. Veja `node/CLAUDE.md` (quando existir).
- `api/contrato.md` — especificação da API.
- `docs/decisoes/` — registro de decisões (ADRs).
