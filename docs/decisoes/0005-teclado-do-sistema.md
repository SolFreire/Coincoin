# 0005 — Teclado numérico do sistema para valores

- Status: aceita
- Data: 2026-11-15

## Contexto e problema
A sheet Enviar precisa receber um valor inteiro. O primeiro rascunho tinha um teclado
desenhado dentro do app. Teclado próprio ou do sistema?

## Critérios de decisão
- Valores são inteiros (`UInt64`), nunca fracionados.
- Acessibilidade (VoiceOver, Dynamic Type) sem reimplementar.

## Opções consideradas
- **Teclado do sistema (`.numberPad`)**
- Teclado próprio

## Decisão
Opção escolhida: **`.numberPad`**. A validação (só dígitos, overflow de `UInt64`, zero,
saldo) fica no view model.

### Consequências
- Positivas: acessibilidade e visual do sistema de graça.
- Negativas: a tela muda de layout quando o teclado aparece (tratado com o detent `.large`).

## Prós e contras das opções
### `.numberPad`
- Bom, porque não tem separador decimal.
- Bom, porque já vem com acessibilidade.
### Teclado próprio
- Bom, porque mantém o layout estável.
- Ruim, porque reimplementa acessibilidade e não substitui a validação: texto colado
  ainda chega ao campo.

## Conceito de Sistemas Distribuídos
Não confiar na entrada: o app valida para dar resposta rápida, o nó valida de novo
(`INSUFFICIENT_FUNDS`, `MALFORMED`).
