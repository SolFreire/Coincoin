# 0001 — Registrar decisões de arquitetura

- Status: aceita
- Data: 2026-11-14

## Contexto e problema
O projeto tem decisões que dependem da teoria da disciplina e precisam ser justificadas
no relatório final. Como guardar essas justificativas sem que se percam?

## Critérios de decisão
- Reaproveitar no relatório final.
- Ficar junto do código, versionado.

## Opções consideradas
- Registros curtos em `docs/decisoes/`, no formato MADR
- Anotar só no relatório, no final do semestre

## Decisão
Opção escolhida: **registros em `docs/decisoes/`**, um arquivo por decisão, numerados em
ordem, no formato MADR. Novos registros são criados com `/decisao`.

### Consequências
- Positivas: o relatório final reaproveita os registros como seção de decisões de projeto.
- Negativas: exige disciplina de registrar no momento da decisão.

## Conceito de Sistemas Distribuídos
Nenhum, é processo.
