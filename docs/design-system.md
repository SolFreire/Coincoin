# Design system — Coincoin

Fonte da verdade visual do app iOS. Inspirado na pelagem do Coincoin, o porquinho-da-índia.
Cada token de cor é uma Color Set em `app/Coincoin/Assets.xcassets`, com variantes
*Any Appearance* (claro) e *Dark*. No código, use o símbolo gerado pelo Xcode
(ex.: `UIColor.accentSoft`), verificado na compilação; nunca hex nem `UIColor(named:)`.

Nomes no catálogo que diferem do token:
- `Accent` → Color Set **`AccentColor`** (tint global do app; símbolo `UIColor.accent`).
- `Separator` → Color Set **`Divider`** (símbolo `UIColor.divider`), porque `UIColor.separator`
  já existe no UIKit e o símbolo gerado colidiria com ele.

## Princípios
- **Cor da marca só onde há marca ou ação.** Texto, fundos de lista e separadores de sistema
  usam as cores semânticas do UIKit (`.label`, `.secondaryLabel`, `.separator`…), que já
  se adaptam a claro, escuro e alto contraste.
- **Cor nunca é a única pista.** Status sempre combina ícone + texto + cor.
- **Contraste mínimo 4,5:1** (WCAG AA) para texto; todos os pares abaixo foram medidos.
- **Liquid Glass (iOS 26)** para tab bar, botões flutuantes e sheets: usar os componentes
  do sistema (`UITabBarController`, `UISheetPresentationController`, `UIGlassEffect`),
  não imitar com blur manual.

## Cores da marca

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `Accent` (caramelo) | `#9E5420` | `#E8A26A` | Cartão de saldo, botão principal, links, aba ativa |
| `OnAccent` | `#FFF8F0` | `#2A1608` | Texto e ícones sobre `Accent` |
| `AccentSoft` (bege) | `#FBEBDD` | `#4A2A14` | Fundo dos botões circulares, aba selecionada |
| `OnAccentSoft` (castanho) | `#6B3410` | `#FBDCC2` | Ícones e rótulos sobre `AccentSoft` |
| `Background` (creme) | `#FFF8EF` | `#1C1612` | Fundo das telas |
| `Surface` | `#FFFFFF` | `#2A221C` | Campos, cartões secundários |
| `Separator` | `#EBD9C6` | `#3D3128` | Linhas entre itens |

### Contraste medido (WCAG)

| Par | Claro | Escuro |
|---|---|---|
| `OnAccent` sobre `Accent` | 5,33:1 | 8,06:1 |
| `OnAccentSoft` sobre `AccentSoft` | 8,49:1 | 9,87:1 |
| `Accent` sobre `Background` (links) | 5,32:1 | 8,36:1 |
| `Accent` sobre `Surface` | 5,61:1 | 7,30:1 |

Histórico: o caramelo claro começou como `#B8652A` (~4,1:1, reprovado para texto pequeno)
e foi escurecido para `#9E5420`.

## Cores de status

Usam as cores de sistema, que já têm variantes para claro, escuro e alto contraste.

**Cor de status só em ícones e fundos de ícone, nunca em texto.** `.systemGreen` e
`.systemOrange` sobre o creme ficam em torno de 2:1, abaixo do mínimo de 4,5:1. Textos
de status e valores usam `.label` ou `.secondaryLabel`; o ícone carrega a cor.

| Status (`api/contrato.md`) | Cor | Fundo do ícone | SF Symbol |
|---|---|---|---|
| `pending` | `.systemOrange` | `.systemOrange` a 15% | `clock` |
| `confirmed` (recebida) | `.systemGreen` | `.systemGreen` a 15% | `arrow.down.left` |
| `confirmed` (enviada) | `.secondaryLabel` | `.tertiarySystemFill` | `arrow.up.right` |
| `failed` | `.systemRed` | `.systemRed` a 15% | `xmark` |

## Mascote (ilustração)

Cores fixas, iguais nos dois temas (a ilustração tem fundo próprio).

| Parte | Cor |
|---|---|
| Pelagem | `#C9763A` |
| Mancha branca | `#FFF3E6` |
| Orelhas e patas | `#8A4A1E` |
| Nariz | `#E89A9A` |
| Olho | `#2A1608` |

## Tipografia
- Valores monetários e títulos grandes: **SF Rounded** (`UIFontDescriptor.SystemDesign.rounded`)
  com dígitos tabulares (`.monospacedDigit`), para o saldo não "pular" ao mudar.
- Demais textos: estilos de texto do sistema (`.body`, `.subheadline`, `.caption1`…)
  com Dynamic Type. Nada abaixo de 12 pt.
- Endereços e hashes: fonte monoespaçada, agrupados de 4 em 4 caracteres.

## Componentes
- **Botão circular:** 56 pt, fundo `AccentSoft`, ícone `OnAccentSoft`, rótulo abaixo.
  Ação principal de uma sheet: 64 pt, fundo `Accent`, ícone `OnAccent`.
- **Alvo de toque mínimo:** 44 × 44 pt, inclusive para ícones de copiar e escanear.
- **Entrada de valor:** teclado do sistema (`keyboardType = .numberPad`); validação de
  inteiro, overflow de `UInt64`, zero e saldo no view model.
- **Biometria:** símbolo `faceid` ou `touchid` conforme `LAContext.biometryType`.

## Pendências
- Variantes de alto contraste (*Increase Contrast*) para as cores da marca.
- Ilustração definitiva do mascote (o desenho atual é provisório).
