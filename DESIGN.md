# DESIGN.md — Guia de estilo do Iron Flow

Este guia diz como o Iron Flow deve parecer e se comportar. Ele vale para toda tela nova e para toda mudança visual. Leia junto com o `CLAUDE.md` e o `PROJECT_RULES.md`.

## 1. De onde vêm as medidas

1. **O protótipo aprovado é a referência.** O artifact "Iron Flow no celular" mostra cada tela aprovada. Quando este guia e o protótipo divergirem, vale o protótipo, e o guia deve ser corrigido no mesmo PR.
2. **1 px do protótipo = 1 pt no app**, no tamanho de texto padrão do iPhone. Os prints do CI usam o iPhone 17 (402 × 874 pt).
3. **O prompt de cada etapa traz as medidas exatas das telas daquela etapa.** Este guia traz o que é comum a todas: cores, fonte, tamanhos de texto, espaçamentos, cantos e componentes.
4. **Nada de valores soltos.** Use sempre `Theme.Colors`, `Theme.Metrics`, `scaledFont` e os componentes da seção 6. Uma cor ou um componente novo entra primeiro aqui e no `DesignSystem/`, e só depois na tela.
5. **Mudanças neste guia só com a aprovação do dono do projeto.**

## 2. Princípios

- **Só modo escuro.** O app ignora a aparência do aparelho: cada cor tem um valor só no catálogo.
- **Fonte Inter em todos os textos do app**, sempre por `scaledFont(_:weight:)`, que mantém o Dynamic Type (o texto cresce com a configuração do iPhone).
- **Os componentes do próprio iOS continuam com a fonte do iPhone:** barra de abas, alertas, menus, folhas de confirmação e teclado.
- **Um azul de destaque só** (`AccentColor`) para as ações principais. O azul-claro (`LightAccent`) é para links, ícones e o "‹ Voltar".
- **Números com largura fixa** (`.monospacedDigit()`) onde mudam enquanto a pessoa olha: cronômetro, descanso, kg, contagens.
- **Área de toque de pelo menos 44 × 44 pt** em tudo que se toca, mesmo quando o desenho é menor.
- **Toda lista e toda tela que carrega dados tem estado vazio**, e toda ação que apaga algo pede confirmação, com a opção perigosa em vermelho.

## 3. Cores

Todas ficam em `Resources/Assets.xcassets` e são lidas por `Theme.Colors` (ou `Color.accentColor`).

### Base

| `Theme.Colors` | Hex | Protótipo | Uso |
|---|---|---|---|
| `screenBackground` | #0D0E11 | `--bg` | Fundo das telas |
| `cardBackground` | #17181C | `--card` | Cartões e fundo das folhas |
| `cardBorder` | #2A2C31 | `--border` | Borda de 1 pt dos cartões e dos avisos |
| `rowSeparator` | #24262C | `--sep` | Linha entre as linhas de um cartão |
| `brightText` | #F2F3F5 | `--fg` | Texto principal |
| `mediumText` | #C9CBD1 | `--dim` | Texto entre o principal e o secundário (durações, contagens) |
| `secondaryText` | #9A9CA3 | `--muted` | Texto secundário, explicações, rótulos |
| `dimText` | #7E8187 | `--faint` | Texto apagado: rodapés, letras de dia sem treino |
| `futureDayText` | #7E8186 | `--future` | Dias que ainda vão chegar |
| `Color.accentColor` | #4A7BEA | `--accent` | Botões principais, ▶, anel da semana, série atual |
| `lightAccent` | #7FA3F2 | `--accent-soft` | Links, ícones, "‹ Voltar" |
| `iconTileBackground` | #1E2638 | `--chip` | Quadradinho atrás dos ícones |
| `setFieldBackground` | #1E1F24 | `--input` | Campos, botões cinza das folhas, avisos |
| `unplannedDayBackground` | #22242A | `--field` / `--plan-off` | Dia sem treino programado |

### Destaque (treino de hoje, barra do treino em andamento)

| `Theme.Colors` | Hex | Protótipo | Uso |
|---|---|---|---|
| `highlightBackground` | #15213D | `--hero` | Fundo do destaque |
| `highlightBorder` | #2A3D6A | `--hero-border` | Borda do destaque |
| `highlightLine` | #34497A | `--hero-line` | Contornos dentro do destaque (chips, botão de contorno) |
| `highlightText` | #DCE5FB | `--hero-text` | Texto no destaque |
| `highlightSecondaryText` | #C3CEEA | `--hero-sub` | Texto secundário no destaque |
| `highlightLabel` | #A9BEEF | `--hero-eyebrow` | "TREINO DE HOJE" |
| `highlightBadge` | #24365F | `--pill` | Cápsulas "Programado", "HOJE", "Abrir ˄" |

### Semana

| `Theme.Colors` | Hex | Protótipo | Uso |
|---|---|---|---|
| `ringTrack` | #24262C | `--track` | Trilho do anel e dias passados sem treino |
| `markedDayBackground` / `markedDayNumber` | #1A2440 / #A9C1F7 | `--manual-bg` / `--manual-text` | Dia marcado como treinado |
| `plannedDayBackground` / `plannedDayLetter` | #22355F / #CFDCFA | `--plan-on` / `--plan-on-text` | Dia com treino programado |

### Treino em andamento e editor

| `Theme.Colors` | Hex | Uso |
|---|---|---|
| `currentSetBackground` | #162241 | Linha da série atual |
| `currentFieldBackground` | #20305A | Campos da série atual |
| `currentSuggestionText` | #7F92C2 | Sugestão nos campos da série atual |
| `suggestionText` | #84868B | Sugestão (da última vez ou do plano) num campo vazio |
| `controlBorder` | #34363C | Contorno do ✓ e da barra de descanso |
| `restBarBackground` | #1C1D22 | Barra de descanso |
| `selectedCardBackground` | #141B2C | Exercício escolhido no seletor (contorno azul) |
| `dashedBorder` | #3A3D44 | Borda tracejada de "Adicionar exercícios" |

### Tipos de série

| `Theme.Colors` | Hex | Fundo do número |
|---|---|---|
| `warmupSet` (aquecimento) | #F5B83D | a mesma cor a 16% |
| `feederSet` (preparatória) | #A98BF5 | a mesma cor a 17% |
| `failureSet` (falha) | #F2555A | a mesma cor a 16% |
| válida | `mediumText` | `unplannedDayBackground` |

O vermelho de ações perigosas ("Excluir", "Descartar") é o mesmo `failureSet` (#F2555A).

## 4. Tipografia

### Fonte e pesos

Inter (licença SIL OFL 1.1), só nestes cinco pesos:

| Peso no código | Arquivo da Inter | No protótipo |
|---|---|---|
| `.regular` | Inter Regular | 400 |
| `.medium` | Inter Medium | 500 |
| `.semibold` | Inter SemiBold | 600 |
| `.bold` | Inter Bold | 700 |
| `.heavy` | Inter ExtraBold | 800 |

Todo texto usa `scaledFont(tamanho, weight:)`. Nunca `.font(.headline)`, `.font(.system(...))` ou tamanho fixo. A exceção são os ícones SF Symbols, que podem usar a fonte do sistema para o tamanho do símbolo, como no `IconTile`.

### Papéis de texto (tamanho em pt no texto padrão)

| Papel | Tamanho e peso | Detalhes | Exemplo |
|---|---|---|---|
| Título de tela | 29 heavy | espaçamento −0,5; altura de linha 1,05 | "Treinos", nome no editor, "Programação semanal" |
| Nome do treino de hoje | 26 heavy | altura de linha 1,05 | Destaque do Início |
| Número grande | 46 heavy | unidade em 17 | Editor de peso e altura |
| Número de cartão | 19 heavy | unidade em 12 semibold `secondaryText` | Resumo do Início, "3 de 4 treinos" |
| Marca | 17 heavy | espaçamento 0,5 | "Iron Flow" no topo do Início |
| Título de folha | 17 heavy | `brightText` | "Concluir treino?" |
| Texto de folha | 13 regular | `secondaryText` | Explicação abaixo do título |
| Nome de treino em cartão | 15 heavy | | Grade de Treinos |
| Botão | 15 bold | | Botões das folhas e "Iniciar" do destaque |
| Título de linha | 14 bold | | Linhas de lista |
| Subtítulo de linha | 12 (Início) / 11 (Treinos e folhas) | `secondaryText` | "5 exercícios · 55 min" |
| Link / ação de seção | 13 semibold | `lightAccent` | "Personalizar", "Ver tudo" |
| Botão de contorno | 13 semibold | | Botões secundários do destaque |
| Aviso (toast) | 13 semibold | | "Peso salvo" |
| Rótulo de seção (tela) | 11 heavy | caixa alta, espaçamento 2,1 | "SUA SEMANA" (`SectionTitle`) |
| Rótulo de seção (folha) | 10 heavy | caixa alta, espaçamento 1,8, `secondaryText` | "ÚLTIMOS REGISTROS" (`SheetSectionTitle`) |
| Rótulo do destaque | 10 bold | caixa alta, espaçamento 1,7, `highlightLabel` | "TREINO DE HOJE" |
| Cápsula | 10 semibold | "HOJE": 10 bold, espaçamento 0,9; nas folhas, 9 | "Programado" |
| Rodapé | 10 regular | `dimText` | Notas no fim da tela |

## 5. Espaçamentos, cantos e tamanhos

### Espaçamentos (`Theme.Metrics`)

| Medida | Valor | Uso |
|---|---|---|
| `screenPadding` | 16 | Margem lateral das telas e das folhas |
| `cardSpacing` | 12 | Entre cartões |
| `cardPadding` | 16 | Dentro dos cartões das telas antigas |
| Cartões do Início e de Treinos | 12 em cima, embaixo e à esquerda; 14 à direita | `cardStyle(padding:cornerRadius:)` |
| Folhas | 20 acima do título; 12 abaixo do conteúdo; 8 em volta dos botões | `SheetStyle`, `sheetContentPadding()`, `sheetButtonBar()` |

Espaços internos comuns: 4, 6, 8, 10 e 12.

### Cantos (sempre `style: .continuous`)

| Elemento | Canto |
|---|---|
| Destaque do Início | 20 |
| Cartões do Início e de Treinos | 17 |
| Cartões do editor, do treino em andamento e da Programação, barra de descanso | 15–17 (o do protótipo da tela) |
| Botões de folha, botões grandes | 13 |
| Campos de série | 8–9 |
| Quadradinho de ícone | 10 (36 pt) e 9 (29–32 pt) |
| Cápsulas, chips, "Criar", "Concluir" | `Capsule()` |

### Tamanhos fixos

| Elemento | Tamanho |
|---|---|
| Botão de folha | 46 de altura (`SheetButton`) |
| Botão "Iniciar" do destaque | 42 de altura, fundo branco, texto escuro |
| Botão de contorno | 34 de altura |
| "Criar treino" / "Concluir" | 38 / 36 de altura |
| ▶ de iniciar | 32–34 |
| Quadradinho de ícone | 36 (listas), 29 (resumo) |
| Dia da semana | 31 |

## 6. Componentes (em `DesignSystem/` e `Features/Shared/`)

Use estes antes de criar outro. Se precisar de uma variação, acrescente um parâmetro ao componente existente.

| Componente | Para quê | Regras |
|---|---|---|
| `cardStyle()` / `cardStyle(padding:cornerRadius:)` | Cartão com borda de 1 pt | Fundo `cardBackground`, borda `cardBorder` |
| `highlightStyle(padding:cornerRadius:)` | Destaque azul-escuro | Só para o treino de hoje, o treino em andamento e a meta da semana |
| `SectionTitle` / `SectionHeader` | Rótulo de seção e rótulo com ação à direita | A ação tem 44 pt de toque |
| `IconTile` | Ícone SF Symbol num quadradinho | Decorativo: escondido do VoiceOver |
| `TextBackButton` | "‹ Treinos", "‹ Início" | Seta e texto em `lightAccent`, 44 pt de toque |
| `CapsuleBadge` | "Programado", "HOJE" | Fundo `highlightBadge`, texto `highlightText` |
| `SheetHeader`, `SheetSectionTitle`, `SheetButton`, `FittedSheet` | Folhas | Folha com a altura do conteúdo; botão azul para a ação e cinza para sair; desabilitado = opacidade 0,4 |
| `toast(_:)` (`ToastMessage`) | Aviso curto de confirmação | No alto da tela, some em 2,5 s, não bloqueia toques, não cobre o que mudou, o VoiceOver lê |
| `GroupFilterChip`, `EquipmentFilterChip`, `FilterChipRow` | Filtros da tela Exercícios e do seletor | |
| `FlowLayout` | Chips que quebram a linha | |

### Padrões de tela

- **Telas das abas:** título grande próprio ou o topo do modelo; a barra de abas é a do iOS.
- **Telas empilhadas (editor, Programação):** "‹ Treinos" ou "‹ Início" no alto, à esquerda, sem barra de navegação do sistema, e o gesto de voltar deslizando da borda continua funcionando.
- **Folhas:** título, explicação, conteúdo e botões no pé. Os botões ficam fixos no fim quando o conteúdo rola.
- **Confirmação de apagar:** `confirmationDialog` ou `alert` do sistema, com a opção perigosa em vermelho (`role: .destructive`) e "Cancelar".

## 7. Estados e retorno para a pessoa

- **Avisos curtos** (`toast`) para confirmar o que acabou de acontecer: "Treino salvo · 5 séries · 2.640 kg", "Treino descartado", "Série removida", "Nome salvo" e outros. Frases curtas, e um aviso por vez.
- **Erros de digitação** aparecem com a mensagem de `UserFacingError`, e o valor anterior é mantido.
- **Estados vazios** dizem o que falta e oferecem o próximo passo ("Nenhum treino criado" + "Iniciar treino livre").
- **Botão desabilitado:** opacidade 0,4 e sem ação.

## 8. Movimento

- As transições padrão do iOS: empurrar a tela, abrir a folha, fade do aviso.
- O ponto azul pulsando da barra do treino em andamento é a única animação contínua, e para quando "Reduzir movimento" estiver ligado.
- Nada de animação em cada toque. Vibração só onde o protótipo ou o prompt da etapa pedir.

## 9. Acessibilidade

- **Dynamic Type:** todo texto cresce com `scaledFont`. Com letra grande, as linhas quebram ou empilham, sem cortar texto.
- **Toque de 44 pt** em tudo que se toca.
- **VoiceOver:** botões só com ícone têm rótulo; ícones decorativos ficam escondidos; avisos são anunciados.
- **Contraste** (texto normal precisa de 4,5:1; texto grande ou negrito de 14 pt para cima, de 3:1):

| Texto sobre fundo | Contraste | Situação |
|---|---|---|
| `brightText` sobre `cardBackground` | 16,0 | ok |
| `secondaryText` sobre `cardBackground` | 6,5 | ok |
| `lightAccent` sobre `cardBackground` | 7,1 | ok |
| branco sobre `accentColor` (botão 15 bold) | 4,0 | ok para texto negrito de 14 pt para cima |
| `dimText` sobre `cardBackground` | 4,5 | ok |
| `futureDayText` sobre `cardBackground` | 4,5 | ok |
| `suggestionText` sobre `setFieldBackground` | 4,5 | ok |

`dimText`, `futureDayText` e `suggestionText` foram clareados em 29/10/2026, com aprovação do dono do projeto, para chegar a 4,5:1 (antes: 3,6, 2,8 e 2,3). Toda cor de texto nova precisa de pelo menos 4,5:1 sobre o fundo em que aparece.
