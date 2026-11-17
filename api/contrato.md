# Contrato da API — Coincoin

Fonte da verdade da comunicação entre o app e os nós. Rascunho: será refinado durante a fase 1.

## Convenções
- JSON com campos em `camelCase`.
- Hash da transação: SHA-256 dos bytes do `payload`, em hexadecimal minúsculo (64 caracteres).
- Endereço: primeiros 20 bytes do SHA-256 dos bytes de `publicKey` (ver "Chave pública"),
  em hexadecimal minúsculo (40 caracteres).
- Altura (`height`): número do bloco; o gênese é 0.
- Valores (`amount`, `balance`, `nonce`, `height`): número JSON inteiro sem sinal (`uint64`).
  Nunca string, nunca ponto flutuante.
- Datas (`timestamp`): segundos Unix, inteiro.
- Erros: `{"error": {"code": "...", "message": "...", "details": {...}}}`. Clientes tratam
  pelo `code`; `message` é só para leitura humana.

## Endpoints

| Método | Rota | Função |
|---|---|---|
| POST | `/tx` | Envia transação assinada (202 nova, 200 já conhecida) |
| GET | `/tx/{hash}` | Status: pending, confirmed, failed |
| GET | `/accounts/{address}` | Saldo, próximo nonce e altura |
| GET | `/accounts/{address}/txs` | Transações da conta (enviadas e recebidas) |
| GET | `/blocks/latest` | Último bloco confirmado |
| GET | `/blocks/{height}` | Bloco por altura |
| GET | `/contracts/{address}/state` | Estado de um contrato |
| GET | `/peers` | Nós conhecidos |
| GET | `/health` | Status do nó e altura |

## Envelope de transação
```json
{ "payload": "<base64>", "signature": "<base64 DER>", "publicKey": "<base64 DER>" }
```
Payload decodificado:
```json
{ "type": "transfer", "to": "<endereço>", "amount": 10, "nonce": 4 }
```

### Bytes assinados
- O cliente gera o JSON do payload **uma vez**, assina esses bytes e os envia em base64.
- O nó verifica a assinatura **sobre os bytes recebidos**, antes de interpretar o JSON.
- Ninguém reserializa o payload: ordem de campos e espaços não importam, valem os bytes.
- O hash da transação é o SHA-256 desses mesmos bytes. Reenviar os mesmos bytes é seguro:
  o nó reconhece o hash e responde 200 (idempotência).
- O remetente é derivado de `publicKey`; não vai no payload.

### Assinatura
- Algoritmo: **ECDSA na curva P-256 (secp256r1) com SHA-256**.
- A assinatura é calculada **sobre os bytes do payload**. O SHA-256 faz parte do algoritmo:
  o cliente não aplica hash antes (não assinar o hash da transação).
- `signature`: estrutura ASN.1 DER `SEQUENCE { r INTEGER, s INTEGER }`, de 70 a 72 bytes
  em geral, em base64.
- ECDSA é aleatório: assinar o mesmo payload duas vezes gera assinaturas diferentes, ambas
  válidas. Como o hash da transação cobre só o payload, as duas são **a mesma transação**
  (o nó responde 200 na segunda).

### Chave pública
- `publicKey`: `SubjectPublicKeyInfo` DER (X.509) de uma chave P-256 com ponto **não
  comprimido**, sempre 91 bytes, em base64.
- O nó recusa qualquer outra curva ou codificação, inclusive o ponto comprimido da mesma
  chave: o endereço é derivado desses bytes exatos, então duas codificações da mesma chave
  seriam duas contas.

### Ordem de validação no nó
1. Decodificar o base64 dos três campos → senão `MALFORMED`.
2. Ler `publicKey` como P-256 em 91 bytes → senão `MALFORMED`.
3. Verificar `signature` sobre os bytes do payload → senão `INVALID_SIGNATURE`.
4. Só então interpretar o JSON do payload → senão `MALFORMED`.
5. Regras de estado (nonce, saldo) → `INVALID_NONCE`, `INSUFFICIENT_FUNDS`.

Equivalências: Swift `P256.Signing.PublicKey.derRepresentation` e
`ECDSASignature.derRepresentation`; Go `x509.ParsePKIXPublicKey` e `ecdsa.VerifyASN1`.

## Respostas

### `POST /tx`
202 (nova) ou 200 (já conhecida). Corpo igual ao de `GET /tx/{hash}`: uma transação já
conhecida pode estar `confirmed` ou `failed`, não só `pending`.

### `GET /tx/{hash}`
```json
{ "hash": "<64 hex>", "status": "confirmed", "height": 1480, "failureCode": null }
```
- `status`: `pending`, `confirmed` ou `failed`.
- `height`: presente só quando `confirmed`; `null` nos demais.
- `failureCode`: presente só quando `failed` (um código da tabela de erros); `null` nos demais.
- Hash desconhecido: 404 `TX_NOT_FOUND`.

### `GET /accounts/{address}`
```json
{ "address": "<40 hex>", "balance": 1250, "nextNonce": 5, "height": 1482 }
```
- `balance`: saldo no estado **confirmado**, na altura `height`.
- Conta desconhecida: 200 com `balance` 0 e `nextNonce` 0 (carteira nova não é erro).

### `GET /accounts/{address}/txs?limit=50&before={height}`
```json
{
  "items": [
    { "hash": "<64 hex>", "from": "<40 hex>", "to": "<40 hex>", "amount": 300, "nonce": 3,
      "status": "confirmed", "height": 1480, "failureCode": null, "timestamp": 1794700000 }
  ],
  "nextBefore": 1402
}
```
- Enviadas e recebidas pela conta, da mais nova para a mais antiga.
- **Só transações confirmadas** (`status` sempre `confirmed`, com `height`): é o histórico
  da cadeia. Pendentes e falhas das próprias transações o app já conhece, porque foi ele
  quem as enviou, e as acompanha por `GET /tx/{hash}`.
- `timestamp`: hora do bloco em que a transação foi confirmada.
- `limit`: padrão 50, máximo 100. `before`: só transações em altura menor que esta.
- **Uma página nunca corta um bloco ao meio.** Se o limite cair no meio de um bloco, as
  demais transações desse bloco entram na mesma página (a página pode passar de `limit`).
  Sem isso, o cursor por altura pularia o resto do bloco na página seguinte.
- `nextBefore`: valor de `before` para a próxima página; `null` quando acabou.

### `GET /health`
```json
{ "nodeId": "n2", "status": "ok", "height": 1482 }
```
- `status`: `ok` ou `syncing`.

## Códigos de erro
| Código | HTTP | Significado |
|---|---|---|
| MALFORMED | 400 | Base64, chave pública ou JSON inválido |
| INVALID_SIGNATURE | 422 | Assinatura não confere |
| INSUFFICIENT_FUNDS | 422 | Saldo insuficiente no estado confirmado |
| INVALID_NONCE | 409 | Nonce já usado ou fora da janela aceita |
| TX_NOT_FOUND | 404 | Hash de transação desconhecido |
| SYNCING | 503 | Nó sincronizando |

Clientes devem tolerar códigos novos (tratar como erro genérico), não falhar ao decodificá-los.

## Riscos conhecidos
- Sem `chainId`: uma transação assinada vale em qualquer rede Coincoin com o mesmo estado.
  Aceitável numa rede única de laboratório.
