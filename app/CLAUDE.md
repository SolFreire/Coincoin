# App iOS (Coincoin) — instruções para o Claude Code

## Papel
Carteira e cliente leve. Não guarda a cadeia nem participa do consenso. Guarda a chave
privada, assina transações localmente e consulta os nós pela API HTTP.

## Arquitetura
- **UIKit em código**, sem storyboard. Auto Layout programático.
- **MVVM**: view controllers finos; view models `@MainActor` com `@Published`; ligação via Combine.
- **Camadas**: Apresentação → View models → Serviços → Infraestrutura. Cada camada conhece a
  de baixo só por protocolos.
- **Injeção de dependência**: só a composição em `App/` decide implementações (mock ou HTTP,
  Keychain ou Secure Enclave).
- **Concorrência**: estado compartilhado em `actor` (ex.: `TransactionTracker`); UI só na main thread.

## Componentes previstos
- `NodeClient` (protocolo) com `MockNodeClient` (latência e falhas configuráveis) e `HTTPNodeClient`.
- `TransactionSigner` com `KeychainSigner` (funciona no simulador) e `SecureEnclaveSigner`
  (só no aparelho físico).
- `NodePool` (health check, escolha do melhor nó, failover).
- `TransactionTracker` (máquina de estados da transação, persistência em disco, write-ahead).
- Saldo disponível = saldo confirmado − saídas pendentes. Depósitos pendentes não contam.

## Estrutura de pastas (alvo)
```
App/  Features/{Onboarding,Wallet,Activity,Explorer,Network}/  Services/
Infrastructure/{API,Crypto,Storage}/  Tests/
```

## Convenções
- Códigos de erro da API são tratados pelo `code`, nunca pelo texto da mensagem.
- Toda chamada de rede tem timeout explícito.
- Testes de view model usam o mock com falhas e latência.
- Rodar os testes antes de considerar uma tarefa concluída.
