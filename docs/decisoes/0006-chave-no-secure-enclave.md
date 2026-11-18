# 0006 — Chave de assinatura no Secure Enclave

- Status: aceita
- Data: 2026-11-16

## Contexto e problema
O app assina transações com ECDSA P-256 (ADR 0002). A chave privada é a única prova de
posse da conta: quem a tiver gasta o saldo. Onde guardá-la e o que exigir para usá-la?

## Critérios de decisão
- A chave privada nunca deve existir em memória do app nem em backups.
- Um evento comum (recadastrar Face ID, trocar o código) não pode destruir a chave.
- Continuar testável no simulador.

## Opções consideradas
- **Secure Enclave (CryptoKit) com `.privateKeyUsage` + `.userPresence`**
- Secure Enclave com `.biometryCurrentSet`
- Chave P-256 comum no Keychain (`KeychainSigner`)

## Decisão
Opção escolhida: **Secure Enclave com `.userPresence`**, acessibilidade
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. A `dataRepresentation` da chave (bloco
que só aquele chip abre) é guardada como item do Keychain. Só a API do CryptoKit é usada
para essa chave, nunca `SecKey`. A composição decide por `SecureEnclave.isAvailable`:
quando é falso, injeta o `InMemorySigner`.

> Correção (2026-11-18): este registro dizia que o simulador não tem Secure Enclave. Nos
> simuladores iOS 26 e 27 usados no projeto, `isAvailable` é verdadeiro e chaves sem
> `.userPresence` funcionam (os testes do `SecureEnclaveSigner` usam essas). Já a chave da
> carteira, com `.userPresence`, não pode ser criada no simulador (LocalAuthentication
> -1020, "not supported on iOS Simulator"): lá a composição cai no `InMemorySigner` e cada
> abertura gera uma carteira nova. A decisão não muda.

### Verificação no aparelho (2026-11-18)
Roteiro manual num iPhone com código e Face ID:
- O pedido de Face ID aparece ao assinar, com a chave reaberta a partir da
  `dataRepresentation` e um `LAContext` novo (o problema relatado no fórum não ocorreu).
- Cancelar o Face ID volta à edição sem erro (`SignerError.cancelled`).
- Com o rosto recusado, o código do aparelho é aceito (`.userPresence`).
- Depois de fechar e reabrir o app, o endereço é o mesmo: a chave persiste.

Não verificado: a chave sobreviver a recadastrar o Face ID (vem da documentação e do fórum).

### Consequências
- Positivas: a chave privada não sai do chip; toda assinatura exige Face ID ou código.
- Negativas: a chave da carteira e o pedido de Face ID só existem no aparelho; no simulador
  a carteira é refeita a cada abertura.
- Negativas: exige `NSFaceIDUsageDescription` e tratar o erro "bloco existe mas não abre".

## Prós e contras das opções
### `.userPresence`
- Bom, porque aceita Face ID ou código e sobrevive a mudanças na biometria.
### `.biometryCurrentSet`
- Bom, porque um código descoberto não basta para assinar.
- Ruim, porque recadastrar o Face ID invalida a chave para sempre, e sem backup isso
  é perder o saldo.
### Chave comum no Keychain
- Bom, porque funciona no simulador e pode ter backup.
- Ruim, porque a chave privada passa pela memória do app.

## Conceito de Sistemas Distribuídos
Autenticação por assinatura digital: o nó só aceita transações assinadas pela chave
dona do endereço, então proteger a chave é proteger a identidade do participante.
