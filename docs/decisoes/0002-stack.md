# 0002 — Stack do projeto

- Status: aceita
- Data: 2026-11-14

## Contexto e problema
Que linguagens, frameworks, protocolos e criptografia usar nos nós, no app e na rede de
desenvolvimento?

## Critérios de decisão
- Expor o conteúdo da disciplina (rede, P2P, consenso) em vez de escondê-lo em bibliotecas.
- Modelar bem um nó conversando com vários pares ao mesmo tempo.
- Assinar no iPhone com hardware seguro.
- No app, estudar o framework mais presente no mercado, em especial em fintechs.

## Opções consideradas
- Nós: **Go com sockets TCP** · Go com biblioteca P2P pronta (ex.: libp2p)
- App: **UIKit** · SwiftUI
- Assinatura: **ECDSA P-256** · curvas fora do Secure Enclave (ex.: Ed25519, secp256k1)

## Decisão
- Nós em **Go**, comunicação entre nós por **sockets TCP**, sem bibliotecas P2P prontas.
- App iOS em **Swift + UIKit**, cliente leve via HTTP.
- Assinaturas **ECDSA P-256**.
- Rede de desenvolvimento em **Docker Compose**; demonstração em notebooks na mesma LAN.

### Consequências
- Positivas: P2P e consenso implementados à mão, estudando os algoritmos.
- Negativas: mais código de rede para escrever e testar (reconexão, framing de mensagens).
- Negativas: UIKit exige mais código de interface que SwiftUI (Auto Layout, ligação manual
  com os view models).

## Prós e contras das opções
### Go com sockets TCP
- Bom, porque goroutines e channels modelam um nó com vários pares.
- Bom, porque a biblioteca padrão já tem rede e criptografia.
### Biblioteca P2P pronta
- Ruim, porque esconde justamente o conteúdo da disciplina.
### UIKit
- Bom, porque é o framework de interface mais popular nas fintechs, com bases de código
  grandes e consolidadas; estudá-lo é o objetivo.
### SwiftUI
- Bom, porque é declarativo e exige menos código.
- Ruim, porque é menos presente nos apps de fintechs que se quer estudar.
### ECDSA P-256
- Bom, porque é a curva suportada pelo Secure Enclave.

## Conceito de Sistemas Distribuídos
Comunicação entre processos por troca de mensagens; autenticação por assinatura digital.
