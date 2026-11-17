# App iOS (Coincoin) — instruções para o Claude Code

## Papel
Carteira e cliente leve. Não guarda a cadeia nem participa do consenso. Guarda a chave
privada, assina transações localmente e consulta os nós pela API HTTP.

## Escopo e telas (ADR 0003)
- Duas abas em `UITabBarController`: **Carteira** e **Histórico**.
- Sheets (`UISheetPresentationController`): **Enviar**, **Receber** (QR code) e **detalhe da transação**.
- Onboarding (criar a chave) aparece uma vez, antes das abas.
- Explorer e Network **não** fazem parte do app; o estado do nó é só um indicador na Carteira.

## Plataforma e visual
- Alvo mínimo **iOS 26.0** (ADR 0004). Liquid Glass via componentes do sistema e `UIGlassEffect`,
  nunca blur feito à mão.
- Cores, tipografia e componentes seguem `docs/design-system.md`. Cores pelos símbolos
  gerados do catálogo (`UIColor.accentSoft`, `.background`…), nunca hex nem `UIColor(named:)`.
- `App/AppComposer` é a raiz de composição: monta as abas e, nos próximos passos,
  injeta as dependências. As telas nunca criam as próprias dependências.
- Valores digitados com `.numberPad` (ADR 0005); validação no view model.

## Arquitetura
- **UIKit em código**, sem storyboard. Auto Layout programático.
- **MVVM**: view controllers finos; view models `@MainActor` com `@Published`; ligação via Combine.
- **Camadas**: Apresentação → View models → Serviços → Infraestrutura. Cada camada conhece a
  de baixo só por protocolos.
- **Injeção de dependência**: só a composição em `App/` decide implementações (mock ou HTTP,
  memória ou Secure Enclave).
- **Concorrência**: estado compartilhado em `actor` (ex.: `TransactionTracker`); UI só na main thread.

## Componentes previstos
- `NodeClient` (protocolo) com `MockNodeClient` (latência e falhas configuráveis) e `HTTPNodeClient`.
- `TransactionSigner` com `InMemorySigner` (simulador e testes) e `SecureEnclaveSigner`
  (aparelho físico; ADRs 0006 e 0007: `.userPresence`, `WhenUnlockedThisDeviceOnly`,
  uma carteira por aparelho, sem backup).
- `NodePool` (health check, escolha do melhor nó, failover).
- `TransactionTracker` (máquina de estados da transação, persistência em disco, write-ahead).
- Saldo disponível = saldo confirmado − saídas pendentes. Depósitos pendentes não contam.

## Estrutura de pastas (alvo)
Projeto Xcode em `app/Coincoin.xcodeproj`; código do app em `app/Coincoin/`:
```
App/  Features/{Onboarding,Wallet,Activity}/  Services/
Infrastructure/{API,Crypto,Storage}/
```
Testes em `app/CoincoinTests/` (Swift Testing) e `app/CoincoinUITests/` (XCTest).

## Convenções
- Códigos de erro da API são tratados pelo `code`, nunca pelo texto da mensagem.
- Toda chamada de rede tem timeout explícito.
- Testes de view model usam o mock com falhas e latência.
- Rodar os testes antes de considerar uma tarefa concluída.
