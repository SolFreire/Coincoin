# 0009 — Formato do QR code de pagamento

- Status: aceita
- Data: 2026-11-18

## Contexto e problema
A sheet Receber mostra um QR code e o Enviar vai lê-lo com a câmera. Quem gera e quem lê
podem ser apps diferentes, ou versões diferentes do mesmo app. O que vai dentro do QR?

## Critérios de decisão
- Um leitor precisa saber que o conteúdo é um pedido Coincoin, e não um texto qualquer.
- Dar para acrescentar campos (valor, descrição) sem quebrar leitores antigos.
- Nada é aceito pela metade: um campo inválido invalida o pedido.

## Opções consideradas
- **URI `coincoin:<endereço>?amount=<n>`, no estilo do BIP 21 do Bitcoin**
- Só o endereço em hexadecimal
- JSON (`{"address": …, "amount": …}`)

## Decisão
Opção escolhida: **URI `coincoin:`**, especificada em `api/contrato.md`, seção "Pedido de
pagamento". O app gera só o endereço; o leitor aceita `amount` e ignora parâmetros
desconhecidos, exceto os `req-`, que obrigam a recusar. O endereço puro também é aceito na
leitura. O QR usa correção de erros M, gerado pelo Core Image, com margem branca mesmo no
modo escuro.

### Consequências
- Positivas: o prefixo identifica o conteúdo; a câmera do sistema reconhece uma URI.
- Positivas: campos novos entram sem quebrar quem já lê.
- Negativas: um leitor antigo ignora um parâmetro novo opcional; o que precisar ser
  obrigatório tem de usar `req-`.

## Prós e contras das opções
### URI `coincoin:`
- Bom, porque segue uma convenção conhecida (BIP 21) e é texto curto.
### Só o endereço
- Ruim, porque não identifica o conteúdo nem permite acrescentar o valor depois.
### JSON
- Ruim, porque é mais longo (QR mais denso) e nenhum leitor do sistema o reconhece.

## Conceito de Sistemas Distribuídos
Serialização e evolução de formato entre processos independentes: versões diferentes
precisam ler o mesmo dado. Campos opcionais são ignorados quando desconhecidos; campos
obrigatórios (`req-`) fazem o leitor antigo recusar em vez de agir sem entender.
