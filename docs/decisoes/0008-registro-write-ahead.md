# 0008 — Registro write-ahead das transações enviadas

- Status: aceita
- Data: 2026-11-18

## Contexto e problema
O `TransactionTracker` acompanha envios que podem já ter saído (`sending`, `unknown`,
`pending`). Se o app fechar no meio, esse estado em memória se perde e a usuária pode
enviar de novo, pagando em dobro. Como lembrar dos envios abertos depois de uma queda?

## Critérios de decisão
- Nenhum envelope chega à rede sem que o app consiga lembrar dele depois.
- Uma queda em qualquer ponto nunca leva a pagamento em dobro.
- Simples de testar sem derrubar o app de verdade.

## Opções consideradas
- **Arquivo JSON por carteira, gravado antes de enviar (write-ahead)**
- Keychain
- Core Data / SwiftData
- Só memória

## Decisão
Opção escolhida: **write-ahead em arquivo**. O tracker grava o envelope assinado (bytes do
payload, assinatura e chave pública) com a fase antes de chamar `POST /tx`; se a gravação
falhar, não envia (`storageFailed`). Gravações posteriores são de melhor esforço. Ao abrir,
o tracker relê o registro: `sending` vira `unknown` e é resolvido por `GET /tx` ou reenvio
dos mesmos bytes. O arquivo fica em Application Support, um por endereço, escrito com
`.atomic` e proteção `UntilFirstUserAuthentication`. Confirmadas saem do registro (estão no
nó). Registro ilegível bloqueia novos envios e nunca é sobrescrito. A composição injeta
`FileJournal` na carteira real e `InMemoryJournal` em testes e na demonstração.

### Consequências
- Positivas: queda em qualquer ponto é recuperável; reabrir equivale a retomar.
- Positivas: valor, destino e nonce vêm de dentro do payload, uma única fonte.
- Negativas: `.atomic` garante arquivo inteiro após morte do processo, mas não durabilidade
  absoluta se o aparelho desligar no instante da gravação (sem `F_FULLFSYNC`).
- Negativas: transações `failed` acumulam até a interface oferecer descartá-las.
- Negativas: registro ilegível deixa a carteira sem enviar até haver uma recuperação manual.

## Prós e contras das opções
### Arquivo JSON com write-ahead
- Bom, porque a escrita atômica é simples e o formato é legível para depuração.
- Bom, porque os testes simulam a queda criando um tracker novo sobre o mesmo registro.
### Keychain
- Bom, porque é cifrado.
- Ruim, porque não é feito para dados que mudam a cada envio nem para listas que crescem.
### Core Data / SwiftData
- Bom, porque tem transações e consultas.
- Ruim, porque é infraestrutura demais para uma lista curta de envios abertos.
### Só memória
- Ruim, porque uma queda esquece envios que podem ter saído.

## Conceito de Sistemas Distribuídos
Write-ahead logging e recuperação após falha: registrar a intenção de forma durável antes
do efeito irreversível. A recuperação só é segura porque o reenvio dos mesmos bytes é
idempotente; registro desatualizado é sempre conservador.
