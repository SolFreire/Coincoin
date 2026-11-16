# 0004 — Alvo mínimo iOS 26.0

- Status: aceita
- Data: 2026-11-15

## Contexto e problema
O Xcode 27 criou o projeto com alvo mínimo iOS 27.2, mas o simulador mais novo instalado
é o 27.0: os testes não rodavam em nenhum simulador. Qual alvo mínimo usar?

## Critérios de decisão
- Rodar os testes nos simuladores disponíveis.
- Ter Liquid Glass, base do design system.

## Opções consideradas
- **iOS 26.0**
- iOS 27.2, instalando o runtime 27.2

## Decisão
Opção escolhida: **iOS 26.0**.

### Consequências
- Positivas: os simuladores 26.4, 26.5 e 27.0 funcionam; aparelhos com iOS 26 rodam o app.
- Negativas: APIs exclusivas do iOS 27 exigem `if #available`.

## Prós e contras das opções
### iOS 26.0
- Bom, porque já tem Liquid Glass nos componentes do sistema.
### iOS 27.2
- Ruim, porque exclui aparelhos com iOS 26 e exige baixar outro runtime.

## Conceito de Sistemas Distribuídos
Nenhum, é infraestrutura.
