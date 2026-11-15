# 0002 — Stack do projeto

**Data:** 2026-11-14
**Status:** aceita

## Decisão
- Nós em **Go**, comunicação entre nós por **sockets TCP** sem bibliotecas P2P prontas.
- App iOS em **Swift + UIKit**, cliente leve via HTTP.
- Assinaturas **ECDSA P-256** (compatível com o Secure Enclave).
- Rede de desenvolvimento em **Docker Compose**; demonstração em notebooks na mesma LAN.

## Por quê
Go: goroutines e channels modelam um nó conversando com vários pares; biblioteca padrão
com rede e criptografia. Sockets crus expõem o conteúdo da disciplina.
P2P/consenso implementados à mão para estudar os algoritmos, não só configurá-los.
