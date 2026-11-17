# 0007 — Uma carteira por aparelho, sem backup

- Status: aceita
- Data: 2026-11-16

## Contexto e problema
Com a chave no Secure Enclave (ADR 0006), ela não pode ser copiada para outro aparelho
nem restaurada de backup. Como o usuário usa o Coincoin em mais de um aparelho?

## Critérios de decisão
- Não abrir mão do Secure Enclave.
- Não ampliar o escopo do nó e do consenso agora.

## Opções consideradas
- **Uma carteira (endereço) por aparelho**
- Chave exportável com frase de recuperação
- Conta com várias chaves autorizadas, registradas na cadeia

## Decisão
Opção escolhida: **uma carteira por aparelho**. Cada aparelho gera sua chave e seu
endereço; para mover saldo entre eles, faz-se uma transferência comum. Se o app
encontrar a chave guardada mas o chip não conseguir abri-la (aparelho restaurado),
avisa o usuário e oferece criar uma carteira nova.

### Consequências
- Positivas: nenhuma mudança no contrato nem no nó.
- Negativas: apagar ou perder o aparelho perde o saldo para sempre.
- Negativas: o usuário precisa entender que iPhone e iPad são contas diferentes.

## Prós e contras das opções
### Uma carteira por aparelho
- Bom, porque mantém a chave presa ao hardware.
- Ruim, porque não há recuperação.
### Chave exportável
- Bom, porque permite backup e vários aparelhos.
- Ruim, porque a chave passa a existir fora do chip, perdendo a razão do ADR 0006.
### Várias chaves por conta
- Bom, porque une segurança de hardware e vários aparelhos.
- Ruim, porque muda o formato das contas, o contrato e a validação no nó.

## Conceito de Sistemas Distribuídos
Identidade em sistema sem autoridade central: não existe "esqueci a senha", porque nenhum
nó pode reemitir uma chave. A alternativa de várias chaves por conta tornaria a lista de
chaves autorizadas um estado replicado, alterado só por consenso.
