# 0003 — Escopo do app iOS: só carteira

- Status: aceita
- Data: 2026-11-15

## Contexto e problema
O usuário só consulta saldo e transações e envia transações. O plano inicial
(`app/CLAUDE.md`) previa também telas de Explorer (blocos) e Network (nós). Quais telas
o app deve ter?

## Critérios de decisão
- O app é cliente leve: não guarda a cadeia nem participa do consenso.
- Pouca tela para manter num projeto de uma pessoa.
- Manter visível, na demonstração, o failover entre nós.

## Opções consideradas
- **Duas abas (Carteira e Histórico) + sheets**
- Cinco áreas (Carteira, Histórico, Explorer, Network, Onboarding)

## Decisão
Opção escolhida: **duas abas**, Carteira e Histórico. Enviar, Receber (QR code) e o detalhe
da transação são sheets. O estado do nó aparece só como indicador na Carteira (nó
conectado e altura).

### Consequências
- Positivas: `Features/` fica com `Onboarding`, `Wallet` e `Activity`.
- Positivas: o visual fica centralizado em `docs/design-system.md`.
- Negativas: inspecionar blocos e pares exige ferramenta fora do app (`curl` na API, script).

## Prós e contras das opções
### Duas abas + sheets
- Bom, porque cobre tudo que o usuário faz.
- Bom, porque o indicador de nó ainda mostra a troca de nó na demonstração.
### Cinco áreas
- Bom, porque mostra a rede por dentro.
- Ruim, porque Explorer e Network servem a quem opera as réplicas, não a quem usa a carteira.

## Conceito de Sistemas Distribuídos
Cliente leve × réplica completa; detecção de falhas e failover (indicador do `NodePool`).
