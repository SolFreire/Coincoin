# Contrato da API — Coincoin

Fonte da verdade da comunicação entre o app e os nós. Rascunho: será refinado durante a fase 1.

## Convenções
- Hash da transação: SHA-256 dos bytes do `payload`, em hexadecimal.
- Endereço: primeiros 20 bytes do SHA-256 da chave pública (DER), em hexadecimal.
- Altura (`height`): número do bloco; o gênese é 0.
- Valores: inteiros sem sinal. Nunca ponto flutuante.
- Erros: `{"error": {"code": "...", "message": "...", "details": {...}}}`.

## Endpoints

| Método | Rota | Função |
|---|---|---|
| POST | `/tx` | Envia transação assinada (202 nova, 200 já conhecida) |
| GET | `/tx/{hash}` | Status: pending, confirmed, failed |
| GET | `/accounts/{address}` | Saldo, próximo nonce e altura |
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

## Códigos de erro
| Código | HTTP | Significado |
|---|---|---|
| MALFORMED | 400 | Base64 ou JSON inválido |
| INVALID_SIGNATURE | 422 | Assinatura não confere |
| INSUFFICIENT_FUNDS | 422 | Saldo insuficiente no estado confirmado |
| INVALID_NONCE | 409 | Nonce já usado ou fora da janela aceita |
| SYNCING | 503 | Nó sincronizando |
