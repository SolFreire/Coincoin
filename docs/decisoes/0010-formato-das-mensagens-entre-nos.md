# 0010 — Formato das mensagens entre nós

- Status: aceita
- Data: 2026-11-26

## Contexto e problema
Os nós conversam por TCP (ADR 0002), que entrega um fluxo de bytes sem fronteiras entre
mensagens: uma escrita pode chegar picotada, ou duas escritas podem chegar juntas. Como
separar as mensagens e qual formato usar dentro de cada uma?

## Critérios de decisão
- Saber onde cada mensagem termina sem depender do conteúdo dela.
- Nada que chega da rede é confiável: limite de tamanho antes de alocar memória.
- Fácil de ler nos logs e de depurar durante a disciplina.
- Acrescentar tipos e campos sem quebrar nós de versões anteriores.

## Opções consideradas
- **Prefixo de tamanho (4 bytes, big-endian) + JSON `{"type", "payload"}`**
- Delimitador (uma mensagem por linha, JSON Lines)
- Prefixo de tamanho + formato binário (Protocol Buffers, CBOR)

## Decisão
Opção escolhida: **prefixo de 4 bytes com o tamanho, em big-endian, seguido do JSON**
`{"type": "...", "payload": {...}}`. Limite de 1 MiB por quadro, conferido no cabeçalho antes
de alocar o corpo; acima disso, a leitura falha com `ErrFrameTooLarge`. Mensagem sem `type`
ou que não seja JSON é `ErrMalformed`. Campos desconhecidos no JSON são ignorados.
Implementação em `node/internal/wire`.

### Consequências
- Positivas: o leitor sabe quantos bytes esperar; mensagens picotadas ou coladas se resolvem.
- Positivas: JSON legível nos logs; o `payload` de cada tipo evolui sem mudar o quadro.
- Negativas: JSON é maior e mais lento que binário (irrelevante para 4 nós em laboratório).
- Negativas: assinaturas sobre mensagens entre nós precisarão de bytes exatos, como no
  contrato do app, e não de JSON reserializado.

## Prós e contras das opções
### Prefixo de tamanho + JSON
- Bom, porque o tamanho vem antes do conteúdo e permite recusar sem ler.
### JSON Lines
- Ruim, porque o leitor só descobre o fim ao achar a quebra de linha: um par malicioso
  pode mandar uma linha infinita, e uma quebra de linha dentro do conteúdo precisa de escape.
### Prefixo + binário
- Bom, porque é compacto e tipado.
- Ruim, porque exige biblioteca externa (contra o ADR 0002) e não se lê nos logs.

## Conceito de Sistemas Distribuídos
Comunicação por troca de mensagens sobre um canal de fluxo: o protocolo de aplicação define
os limites das mensagens (framing) e trata todo dado recebido como não confiável.
