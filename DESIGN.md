# DESIGN.md — Guia de estilo do Iron Flow

Este guia diz como o Iron Flow deve parecer e se comportar. Ele vale para toda tela nova e para toda mudança visual. Leia junto com o `CLAUDE.md` e o `PROJECT_RULES.md`.

## 1. De onde vêm as medidas

1. **O protótipo aprovado é a referência.** O protótipo "Iron Flow — visual novo" fica em `design/prototipo.html` (fora do app) e mostra cada tela aprovada. Quando este guia e o protótipo divergirem, vale o protótipo, e o guia deve ser corrigido no mesmo PR.
2. **As imagens de referência saem do workflow "Referências do protótipo"** (manual, `.github/workflows/prototype-references.yml`): ele abre o protótipo no WebKit do macOS, com a SF Pro de verdade, e salva uma imagem de cada tela e estado que tem screenshot no CI, com o mesmo nome e o mesmo tamanho, com o protótipo começando no fim da área segura. Os passos de cada imagem ficam em `ci/prototype-references.json`; as imagens ficam no run e na pasta `prototipo/` do branch `ci-prototipo`.
3. **1 px do protótipo = 1 pt no app**, no tamanho de texto padrão do iPhone. Os prints do CI usam o iPhone 17 (402 × 874 pt).
4. **O prompt de cada etapa traz as medidas exatas das telas daquela etapa.** Este guia traz o que é comum a todas: cores, fonte, tamanhos de texto, espaçamentos, cantos e componentes.
5. **Nada de valores soltos.** Use sempre `Theme.Colors`, `Theme.Metrics`, `scaledFont` e os componentes da seção 6. Uma cor ou um componente novo entra primeiro aqui e no `DesignSystem/`, e só depois na tela.
6. **As notas do protótipo não entram no app.** As frases cinzas no pé das telas do protótipo (10, `--faint`), como "Protótipo · os números são exemplos" ou "Toque no ✓ para marcar a série · …", são notas para quem testa o protótipo e nunca entram no app.
7. **Mudanças neste guia só com a aprovação do dono do projeto.**

## 2. Princípios

- **Só modo escuro.** O app ignora a aparência do aparelho: cada cor tem um valor só no catálogo.
- **SF Pro, a fonte do sistema, em todos os textos do app**, sempre por `scaledFont(_:weight:)`, que mantém o Dynamic Type (o texto cresce com a configuração do iPhone). A fonte do sistema acompanha sozinha o "Texto em negrito" do iPhone. O app não leva nenhum arquivo de fonte.
- **Os componentes do próprio iOS continuam os do sistema:** barra de abas, alertas, menus, folhas de confirmação e teclado.
- **Preto, branco e cinza, com o azul só em detalhes.** O botão principal é branco com texto e ícone pretos (`primaryButton` e `primaryButtonText`). O azul (`AccentColor`) fica só nos detalhes: anel da semana, ponto de dia programado, barra de progresso do treino, anel do descanso, ✓ da série feita (fundo azul, ✓ branco), contorno e marca do exercício escolhido no seletor, marcas de Personalizar, interruptores, os músculos principais do boneco e a linha e os pontos do gráfico de evolução. Nada de azul escrito direto no código: sempre a cor `AccentColor` do catálogo, porque a cor do destaque vai poder ser escolhida (etapa S7). `Color.accentColor` segue o tint em volta, e dentro das abas o tint é o branco da aba escolhida; o que precisa do azul ali (o boneco e o gráfico do detalhe do exercício) usa `Theme.Colors.accent`, a cor do catálogo sem depender do tint. O cinza-claro (`LightAccent`) é para links, ícones e o "‹ Voltar".
- **Vidro do iOS 26 (Liquid Glass) só no que flutua sobre o conteúdo:** a barra de abas do sistema, a barra "Treino em andamento", a barra do descanso, os botões redondos (⌄ e ⋯ do treino, ⋯ do editor e ⋯ do detalhe do exercício), os botões secundários do "Treino de hoje" e as folhas do sistema. Nada de vidro em cartões, linhas, fundos de tela ou avisos. Com "Reduzir transparência", o próprio iOS deixa o vidro fosco; o app não troca o vidro por cor sólida.
- **Números com largura fixa** (`.monospacedDigit()`) onde mudam enquanto a pessoa olha: cronômetro, descanso, kg, contagens.
- **Área de toque de pelo menos 44 × 44 pt** em tudo que se toca, mesmo quando o desenho é menor.
- **Toda lista e toda tela que carrega dados tem estado vazio**, e toda ação que apaga algo pede confirmação, com a opção perigosa em vermelho.

## 3. Cores

Todas ficam em `Resources/Assets.xcassets` e são lidas por `Theme.Colors` (ou `Color.accentColor`). Os valores são os do protótipo "Iron Flow — visual novo" (novembro de 2026).

### Base

| `Theme.Colors` | Hex | Protótipo | Uso |
|---|---|---|---|
| `screenBackground` | #000000 | `--bg` | Fundo das telas; também o texto preto sobre as cores dos tipos de série |
| `cardBackground` | #121214 | `--card` | Cartões |
| `cardBorder` | #232326 | `--border` | Borda de 1 pt dos cartões e dos avisos; trilho do anel e −15/+15 do descanso |
| `rowSeparator` | #1E1E21 | `--sep` | Linha entre as linhas de um cartão |
| `brightText` | #F5F5F7 | `--fg` | Texto principal |
| `mediumText` | #C8C8CD | `--dim` | Texto entre o principal e o secundário (durações, contagens) |
| `secondaryText` | #9B9BA1 | `--muted` | Texto secundário, explicações, rótulos |
| `dimText` | #8C8C92 | `--faint` | Texto apagado: setas ›, datas, letras de dia sem treino |
| `futureDayText` | #7D7D83 | `--future` | Dias que ainda vão chegar, coluna ÚLTIMA |
| `Color.accentColor` | #3D7BF0 | `--accent` | O azul dos detalhes (seção 2) |
| `lightAccent` | #D1D1D6 | `--accent-soft` | Links, ícones, "‹ Voltar", ✓ da série atual, ponto da barra do treino |
| `primaryButton` / `primaryButtonText` | #F5F5F7 / #000000 | `--white` / `--bg` | Botão principal: "Iniciar", "Criar treino", "Concluir", os ▶, "Pular", "Adicionar", o botão de ação das folhas; também o quadrado do logo, o dia treinado, o número da série válida atual e o chip de grupo escolhido |
| `selectedTab` | #FFFFFF | `.tab[aria-current]` | A aba escolhida da barra de abas do sistema (o `tint` da `TabView`) |
| `iconTileBackground` | #1E1E21 | `--chip` | Quadradinho atrás dos ícones |
| `setFieldBackground` | #1E1E21 | `--input` | Campos, botões cinza das folhas, avisos |
| `unplannedDayBackground` | #1E1E21 | `--field` / `--plan-off` | Dia sem treino programado |

### Destaque (treino de hoje, meta da semana)

| `Theme.Colors` | Valor | Protótipo | Uso |
|---|---|---|---|
| `highlightBackground` | #0A0A0B | `--hero` | Fundo do destaque |
| `highlightBorder` | branco 14% | `--hero-border` | Borda do destaque, por dentro |
| `highlightLine` | branco 18% | `--hero-line` | Contornos dentro do destaque (chips), escolha de uma grade, cartão do exercício atual |
| `highlightText` | #F2F2F4 | `--hero-text` | Texto no destaque |
| `highlightSecondaryText` | #A6A6AC | `--hero-sub` | Texto secundário no destaque; coluna ÚLTIMA da série atual |
| `highlightLabel` | #A6A6AC | `--hero-eyebrow` | "TREINO DE HOJE" |
| `highlightBadge` | branco 10% | `--pill` | Cápsulas "Programado", "HOJE", "Abrir ˄"; escolha de uma grade |
| `highlightGlow` | branco 10% | `inset 0 1px 0` | Brilho de 1 pt na borda de cima do "Treino de hoje" do Início, por dentro (`highlightStyle(…, glow: true)`) |

### Semana

| `Theme.Colors` | Hex | Protótipo | Uso |
|---|---|---|---|
| `ringTrack` | #232326 | `--track` | Trilho do anel e dias passados sem treino |
| `markedDayBackground` / `markedDayNumber` / `markedDayBorder` | #1C1C1F / #D1D1D6 / #8E8E94 | `--manual-bg` / `--manual-text` | Dia marcado como treinado (tracejado de 1,5 pt) |
| `plannedDayBackground` / `plannedDayLetter` | #2A2A2D / #F2F2F4 | `--plan-on` / `--plan-on-text` | Dia com treino programado |

O dia treinado no app é um círculo `primaryButton` com o número em `primaryButtonText`.

### Treino em andamento e editor

| `Theme.Colors` | Hex | Uso |
|---|---|---|
| `currentSetBackground` | #1C1C1F | Linha da série atual |
| `currentSetBorder` | branco 35% | Contorno de 1,5 pt da linha da série atual, por dentro |
| `currentCheckBorder` | branco 55% | Contorno de 2 pt do ✓ da série atual ainda não marcada (o ✓ em `lightAccent`) |
| `currentFieldBackground` | #2C2C30 | Campos da série atual |
| `currentSuggestionText` | #9B9BA1 | Sugestão nos campos da série atual |
| `suggestionText` | #84868B | Sugestão (da última vez ou do plano) num campo vazio |
| `controlBorder` | #34363C | Contorno de 1,5 pt do ✓ das séries que não são a atual |
| `selectedCardBackground` | #1C1C1F | Exercício escolhido no seletor (contorno azul) |
| `dashedBorder` | #3A3D44 | Borda tracejada de "Adicionar exercícios" |

### Tela bloqueada de exemplo ("Avisar quando o descanso acabar?")

| `Theme.Colors` | Valor | Uso |
|---|---|---|
| `lockScreenTop` / `lockScreenMiddle` | #2C2C30 / #141416 | Luz de cima da tela bloqueada, sobre preto (`radial-gradient(120% 90% at 50% 0%)`) |
| `noticeBackground` | #30343E a 82% | Fundo do aviso |
| `noticeText` / `noticeSecondaryText` | #DDE1EA / #AEB4C2 | Texto do aviso e "agora" |

### Detalhe do exercício (boneco e gráfico)

| `Theme.Colors` | Valor | Protótipo | Uso |
|---|---|---|---|
| `accent` | #3D7BF0 (a `AccentColor` do catálogo) | `--m-pri`, `--accent` | Músculos principais no boneco e o quadradinho de PRINCIPAL; linha e pontos do gráfico; o fundo da linha é a mesma cor a 12% |
| `muscleSecondary` | #30569C | `--m-sec` | Músculos secundários no boneco e o quadradinho de SECUNDÁRIOS |
| `muscleInactive` | #2C2C30 (o mesmo valor de `currentFieldBackground`) | `--m-off` | Músculo que o exercício não usa |
| `figureBase` | #1E1E21 (o mesmo valor de `iconTileBackground`) | `--m-skin` | Cabeça, pescoço, mãos, joelhos e pés |
| `chartRule` | #3A3A3F | `#3A3A3F` | Risquinho dos meses e linha vertical do ponto escolhido |
| `sheetListSeparator` | branco 8% | `rgba(255, 255, 255, .08)` | Linha entre os tipos da folha "Tipos de máquina" |

As linhas horizontais do gráfico são `cardBorder`; os valores do eixo e os meses, `dimText`; o ponto escolhido é `brightText` com contorno azul, e os outros pontos têm contorno `cardBackground`.

### Tipos de série

| `Theme.Colors` | Hex | Fundo do número |
|---|---|---|
| `warmupSet` (aquecimento) | #F5B83D | a mesma cor a 16% |
| `feederSet` (preparatória) | #A98BF5 | a mesma cor a 17% |
| `failureSet` (falha) | #F36367 | a mesma cor a 16% |
| válida | `mediumText` | `unplannedDayBackground` |

Na série atual, o número fica na cor do tipo, cheia, com o número preto; a válida atual fica em `primaryButton`.

O vermelho de ações perigosas ("Excluir", "Descartar") é o mesmo `failureSet` (#F36367).

## 4. Tipografia

### Fonte e pesos

SF Pro, a fonte do sistema (`.system(size:weight:)` dentro do `scaledFont`), só nestes cinco pesos:

| Peso no código | No protótipo |
|---|---|
| `.regular` | 400 |
| `.medium` | 500 |
| `.semibold` | 600 |
| `.bold` | 700 |
| `.heavy` | 800 |

Todo texto usa `scaledFont(tamanho, weight:)`. Nunca `.font(.headline)`, `.font(.system(...))` direto na tela ou tamanho fixo. O "Texto em negrito" do iPhone deixa a fonte do sistema mais pesada sozinha; o app não faz nada para isso. O espaçamento entre letras (`.tracking`) é o `letter-spacing` do protótipo.

**Altura de linha.** O `normal` do CSS é a altura de linha da própria SF Pro, que muda com o tamanho: o desenho troca de Text para Display a partir de 20 pt. Os textos que têm `line-height` próprio no CSS do protótipo passam o mesmo valor em `scaledFont(tamanho, weight:, lineHeight:)`: 1,05 nos títulos grandes, 1 no número do anel da semana, 1,4 nos textos das folhas e no treino sem exercícios, 1,35 no aviso e nos textos pequenos das linhas de Treinos, da meta e do tipo da série. A sobra (o que a linha ganha ou perde) é calculada sobre a altura real da SF Pro naquele tamanho e peso (`SystemFont.lineHeight`), nunca sobre uma razão fixa: metade acima e metade abaixo do texto, e toda ela entre duas linhas. Quando um título com altura de linha menor que a da fonte (1,05) quebra em duas linhas ou mais, as linhas ficam com a altura própria da SF Pro entre elas, uns 4 pt a mais por linha num título de 29: o SwiftUI não aproxima as linhas além disso, e o dono aceitou assim. O espaço acima da primeira linha e abaixo da última segue o protótipo. Os ícones não são texto: vêm do catálogo `Icons` pelo `AppIcon`, no tamanho do protótipo, e crescem com o texto (seção 6, Ícones).

### Papéis de texto (tamanho em pt no texto padrão)

| Papel | Tamanho e peso | Detalhes | Exemplo |
|---|---|---|---|
| Título de tela | 29 heavy | espaçamento −0,5; altura de linha 1,05 | "Treinos", nome no editor, "Programação semanal" |
| Nome do treino de hoje | 26 heavy | altura de linha 1,05 | Destaque do Início |
| Número grande | 46 heavy | unidade em 17 | Editor de peso e altura |
| Número de cartão | 19 heavy | unidade em 12 semibold `secondaryText` | Resumo do Início, "3 de 4 treinos" |
| Marca | 17 heavy | espaçamento 0,5 | "Iron Flow" no topo do Início |
| Título de folha | 17 heavy | `brightText` | "Concluir treino?" |
| Texto de folha | 13 regular | `secondaryText`; altura de linha 1,4 | Explicação abaixo do título |
| Nome de treino em cartão | 15 heavy | | Grade de Treinos |
| Botão | 15 bold | | Botões das folhas e "Iniciar" do destaque |
| Título de linha | 14 bold | | Linhas de lista |
| Subtítulo de linha | 12 (Início) / 11 (Treinos e folhas) | `secondaryText`; altura de linha 1,35 nos cartões de Treinos | "5 exercícios · 55 min" |
| Link / ação de seção | 13 semibold | `lightAccent` | "Personalizar", "Ver tudo" |
| Botão de vidro do destaque | 13 semibold | `highlightText` | "Escolher outro", "Treino livre" |
| Aviso (toast) | 13 semibold | altura de linha 1,35 | "Peso salvo" |
| Rótulo de seção (tela) | 11 heavy | caixa alta, espaçamento 2,1 | "SUA SEMANA" (`SectionTitle`) |
| Rótulo de seção (folha) | 10 heavy | caixa alta, espaçamento 1,8, `secondaryText` | "ÚLTIMOS REGISTROS" (`SheetSectionTitle`) |
| Rótulo do destaque | 10 bold | caixa alta, espaçamento 1,7, `highlightLabel` | "TREINO DE HOJE" |
| Cápsula | 10 semibold | "HOJE": 10 bold, espaçamento 0,9; nas folhas, 9 | "Programado" |

## 5. Espaçamentos, cantos e tamanhos

### Espaçamentos (`Theme.Metrics`)

| Medida | Valor | Uso |
|---|---|---|
| `screenPadding` | 16 | Margem lateral das telas e das folhas |
| `cardSpacing` | 12 | Entre cartões |
| `cardPadding` | 16 | Dentro dos cartões das telas antigas |
| Cartões do Início e de Treinos | Linhas (Programação, Treino livre, recentes): 12 em cima e embaixo, 14 dos lados; grade de Treinos: 12 em cima, 9 à direita, 10 embaixo, 12 à esquerda; resumo: 12 e 10 | `cardStyle(padding:cornerRadius:)` |
| Folhas | 29 do topo da folha ao título; 12 abaixo do conteúdo; 8 em volta dos botões | `SheetStyle`, `sheetContentPadding()`, `sheetButtonBar()` |
| Cartões do editor do treino | 12 da borda do cartão ao ícone; nas linhas das colunas, das séries e de "+ Adicionar série", 12 de cada lado (o número da série começa 14 depois da borda) | `cardSegmentRow(_:gap:leading:trailing:)`; o treino em andamento usa 8 |

Espaços internos comuns: 4, 6, 8, 10 e 12.

### Medir nos screenshots

- **Folhas no iOS 26:** as folhas que não ocupam a tela toda ficam soltas das bordas, e o sistema as desenha em escala de cerca de 0,957. Quem medir folhas nos screenshots precisa descontar essa escala (dividir a medida por 0,957) antes de comparar com o protótipo.
- **Borda de 1 pt dos cartões:** é desenhada por dentro (`strokeBorder`) e não muda o tamanho do cartão. O protótipo foi ajustado para fazer igual.
- **Referências:** compare cada screenshot com a imagem de mesmo nome do workflow "Referências do protótipo" (seção 1), lado a lado e no mesmo tamanho. Os componentes do sistema (barra de abas, a folha em si, menus, alertas, confirmações e teclado) não são medidos contra o protótipo, que só os imita.

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
| Botão "Iniciar" do destaque | 42 de altura, `primaryButton` com texto `primaryButtonText` |
| Botão de vidro do destaque | 34 de altura |
| "Criar treino" / "Concluir" | 38 / 36 de altura |
| ▶ de iniciar | 32–34 |
| Quadradinho de ícone | 36 (listas), 29 (resumo) |
| Dia da semana | 31 |

## 6. Componentes (em `DesignSystem/` e `Features/Shared/`)

Use estes antes de criar outro. Se precisar de uma variação, acrescente um parâmetro ao componente existente.

| Componente | Para quê | Regras |
|---|---|---|
| `cardStyle()` / `cardStyle(padding:cornerRadius:)` | Cartão com borda de 1 pt | Fundo `cardBackground`, borda `cardBorder` |
| `highlightStyle(padding:cornerRadius:glow:)` | Destaque quase preto | Fundo `highlightBackground` e borda `highlightBorder` por dentro; `glow` (brilho de 1 pt branco 10% na borda de cima) só no "Treino de hoje" do Início. Para o treino de hoje e a meta da semana |
| `SectionTitle` / `SectionHeader` | Rótulo de seção e rótulo com ação à direita | A ação tem 44 pt de toque |
| `AppIcon` | Ícone do protótipo (catálogo `Icons`) | No tamanho do protótipo, crescendo com o texto; a cor vem de `foregroundStyle`; decorativo: escondido do VoiceOver |
| `IconTile` | Ícone do protótipo (catálogo `Icons`) num quadradinho | Decorativo: escondido do VoiceOver |
| `TextBackButton` | "‹ Treinos", "‹ Início" | Seta e texto em `lightAccent`, 44 pt de toque |
| `CapsuleBadge` | "Programado", "HOJE" | Fundo `highlightBadge`, texto `highlightText` |
| `SheetHeader`, `SheetSectionTitle`, `SheetButton`, `FittedSheet` | Folhas | A folha do sistema, de vidro, sem fundo próprio (nada de `presentationBackground`), com a altura do conteúdo; os botões do pé numa `safeAreaBar` (`sheetButtonBar()`), sem fundo, legíveis com o efeito de borda do iOS 26 quando o conteúdo rola por baixo; botão branco (`primaryButton`) para a ação, cinza para sair e cinza com texto vermelho (`failureSet`) para a ação perigosa; desabilitado = opacidade 0,4 |
| Vidro (`glassEffect(_:in:)`) | Barra "Treino em andamento" (`ActiveSessionBar`, cantos 18), barra do descanso (`RestTimerBar`, cantos 17), botões redondos de 32 (⌄ e ⋯ do treino, ⋯ do editor, ⋯ do detalhe do exercício), botões secundários do "Treino de hoje" (34 de altura, cantos 11) | O vidro do sistema na forma de cada um, sem fundo, contorno ou sombra próprios. `.regular.interactive()` no que responde ao toque (a barra "Treino em andamento", os botões redondos e os botões do destaque); `.regular` na barra do descanso, que não é um botão (só o −15, o +15 e o "Pular" dentro dela respondem). Os que ficam juntos vão num `GlassEffectContainer` (os dois do cabeçalho do treino, os dois do destaque). Por cima do vidro, só preenchimentos (a cápsula "Abrir", os botões −15 e +15) e o botão branco, nunca outro vidro. A barra de abas é a do sistema, sem fundo próprio, com a aba escolhida em branco |
| `toast(_:)` (`ToastMessage`) | Aviso curto de confirmação | No alto da tela, some em 2,5 s (em 4 s quando o texto tem mais de 40 caracteres), não bloqueia toques, não cobre o que mudou, o VoiceOver lê |
| `GroupFilterChip`, `EquipmentFilterChip`, `FilterChipRow` | Filtros da tela Exercícios e do seletor | |
| `FlowLayout` | Chips que quebram a linha | |
| `BalancedTextLayout` | Título com as linhas do mesmo tamanho (o `text-wrap: balance` do protótipo) | O texto fica com a largura mais estreita que mantém o número de linhas; numa linha só, nada muda. Usado no título do detalhe do exercício |
| `BodyFigure` | Boneco de frente e de costas do detalhe do exercício | Desenho original do protótipo (caminhos do `FIG`, viewBox 18 2 84 228, cada região desenhada do lado esquerdo e espelhada em x = 120), 81 × 220 pt (52 × 141 no formulário do exercício e 58 × 157 nas folhas dos músculos), desenhado de uma vez com `Canvas`; escondido do VoiceOver (o cartão lê os músculos) |
| `OptionGroup`, `OptionRow`, `OptionToggle` | Linhas de opções numa folha ("Opções do treino") | Grupo com fundo `screenBackground`, cantos 14 e linha `rowSeparator` entre as linhas; cada linha com 11 em cima e embaixo e 14 dos lados, título 14 bold, explicação 11 `secondaryText` que quebra linha, e à direita o `Toggle` do iOS na cor de destaque (rótulo lido pelo VoiceOver, não mostrado) ou um link em `lightAccent` com 44 pt de toque |
| `ExerciseFormView`, `ExerciseFormTopBar`, `ExerciseFormSectionTitle` | Formulário do exercício próprio (novo, editar, duplicar e minha versão) | Tela cheia, como o seletor de exercícios: topo de 36 a 8 do fim da área segura, com "Cancelar" (15, `lightAccent`, 44 de toque) e o título (16 heavy); blocos a 24 (18 abaixo do topo); título de bloco 11 heavy, espaçamento 2,1, em linha de 14, `brightText`; nome num campo de 46, cantos 12, fundo `unplannedDayBackground`, 16 semibold, exemplo 16 medium `dimText`, anel de 1,5 `lightAccent` ao digitar; nome repetido 12 `failureSet`, 4 mais perto do campo; nota da cópia num bloco `cardBackground` sem borda (cantos 17, 12 e 14 de margem, título 14 bold, texto 12 `secondaryText` 1,4); MÚSCULOS num bloco `cardBackground` sem borda (cantos 17; 12 em cima, embaixo e à esquerda, 4 à direita) com o boneco de 52 × 141 de frente e de costas (2 entre eles) e as linhas PRINCIPAIS e SECUNDÁRIOS (64 de altura, quadradinho de 9 da cor da lista, rótulo 10 heavy espaçamento 1,4, músculos 14 semibold 1,3, ou 14 medium `secondaryText` quando falta, e o ›); dicas 12 `secondaryText` 1,4; no pé, sobre `screenBackground` com a linha `rowSeparator`, "Falta: …" (12 `secondaryText`, linha de 16, 8 acima do botão) e o botão principal de 46. "Cancelar" com mudanças pergunta pelo `confirmationDialog` do iOS, no pé ("Descartar" em vermelho e "Continuar editando") |
| `FormChip`, `ExerciseFormChips`, `FormChipOption` | Fichas do formulário (grupo, equipamento, tipo de máquina e músculos) | Cápsula de 36 (44 de toque), 14 dos lados, 8 entre elas; `cardBackground` com borda de 1 `cardBorder` e texto 14 semibold `mediumText`; escolhida: `primaryButton` com texto e ícone `primaryButtonText`; o ícone do equipamento com 15 em `lightAccent`; bloqueada (músculo da outra lista): tracejada, sem fundo, texto `secondaryText` com "principal" ou "secundário" 11 semibold `dimText`, sem ação. Nas folhas dos músculos, 13 com 12 dos lados |
| `MusclesSheet` | "Músculos principais" e "Músculos secundários" | Folha do sistema (`FittedSheet`): título, explicação, o boneco de 58 × 157 de frente e de costas (12 entre eles, centralizado, 14 abaixo da explicação), que muda a cada toque, as 21 fichas de cima para baixo no corpo (`Muscle.bodyOrder`), 14 abaixo do boneco, e "Concluir" |
| Selos MEU e ARQUIVADO | O exercício próprio na lista, no seletor e no detalhe | `CapsuleBadge` 10 bold, espaçamento 0,8, `highlightText` sobre `highlightBadge`; na linha da lista, 3 e 8 de margem; no detalhe, 2 e 8, 8 depois de "grupo · equipamento" e 1 acima da linha de base. Na lista, o nome do arquivado fica em `mediumText` |
| `ArchivedExerciseCard` | "Exercício arquivado" no alto do detalhe de um arquivado | `cardStyle` com 14 de margem e cantos 17: título 14 bold, texto 12 `secondaryText` 1,4 e "Restaurar" 8 abaixo (cápsula `primaryButton` de 34, texto 13 bold `primaryButtonText`, 16 dos lados, 44 de toque) |
| `ExerciseEmptyCard` | "Nenhum exercício encontrado" | Com busca, "+ Criar "texto"": cápsula de 34 contornada de 1 `accentColor`, texto 12 bold `lightAccent`, 14 dos lados, 4 a mais acima; abre o formulário com o nome |
| `RestCapsuleButton` | "⏱ Descanso 1:30" do editor | 28 de altura, 44 de toque; texto 12 bold com números de largura fixa em `mediumText` ("Sem timer" em `dimText`), fundo `unplannedDayBackground`; contorno `lightAccent` por 0,9 s depois de escolher |

### Ícones

- Os ícones do app são os do protótipo, em `Assets.xcassets/Icons`: vetoriais, desenhados em 24 × 24 e usados como "template" (a cor vem do código).
- Cada ícone é usado no tamanho do protótipo. Os principais:
  - 12: chevron-right (linhas), chevron-up ("Abrir"), clock (cabeçalho do treino e cápsula de descanso), play ("Escolher treino"), plus ("Adicionar série"), check (exercício terminado);
  - 13: chevron-right-list (Exercícios), play (cartões de Treinos), check (séries do treino e marcas das folhas);
  - 14: play-hero ("Iniciar" do destaque), plus ("Criar treino", "Novo"), chevron-down (exercício terminado), eq-* (filtros de equipamento);
  - 15: metric-* (resumo), search, more-vertical;
  - 16: chevron-left (voltar), chevron-down (minimizar), more (⋯), target, metric-* (Personalizar);
  - 17: calendar, bolt, eq-* (editor e ordenar);
  - 18: menu-close ("Remover série"), menu-arrow-up e menu-arrow-down (ordenar);
  - 19: logo (preto, no quadrado branco de 34), eq-* (listas de exercícios);
  - 24: tab-* (barra de abas).
- No detalhe do exercício: info 20 (ⓘ do tipo de máquina, em `mediumText`), chart 18 (exercício nunca feito), chevron-down 11 (menu de período) e chevron-right 12 (cartões do histórico); o › das linhas de Exercícios é o chevron-right-list 13 em `futureDayText` (#7D7D83), como no protótipo.
- "Outro": eq-outro (4 quadrados de 6,5 com cantos de 1,5), no lugar do equipamento de um exercício próprio sem equipamento, no tamanho dos eq-* de cada lugar (listas, seletor, editor e a ficha "Outro").
- Ícones iguais do protótipo ficam num arquivo só: clock (também no lugar de timer), calendar (também em "Treinos no mês"), eq-halteres (também em "Kg na semana") e plus (também no lugar de plus-small).
- Ícones do sistema (SF Symbols) só nos componentes do próprio iOS (alertas, menus, teclado) e nas telas que ainda não têm modelo aprovado (Histórico, Ajustes, tela de erro), até a etapa delas.
- O − e o + do editor de peso e altura são texto, em SF Pro Medium 26, como no protótipo.

### Padrões de tela

- **Telas das abas:** título grande próprio ou o topo do modelo; a barra de abas é a do iOS.
- **Detalhe do exercício:** o ⋯ no alto, à direita, abre o menu do iOS: "Criar minha versão" num exercício da lista; "Editar", "Duplicar" e, separado e em vermelho, "Apagar exercício" (sem histórico) ou "Arquivar exercício" (com histórico) num próprio; "Restaurar", "Editar" e "Duplicar" num arquivado. As confirmações saem do ⋯. O arquivado tem o `ArchivedExerciseCard` no alto. Abre pela linha da aba Exercícios (com a barra de abas e Exercícios marcada; tocar na aba volta à lista) e pelo "Ver exercício" (ícone `info.circle`, primeiro item do menu ⋯ do exercício) do editor e do treino em andamento, sem a barra de abas e com o nome do treino no "‹". O treino continua correndo; o fim do descanso aparece no alto, como nas outras telas. Seções MÚSCULOS (boneco, legenda e tipo de máquina, que abre a folha "Tipos de máquina"), EVOLUÇÃO (ÚLTIMA VEZ, MELHOR SÉRIE ★ e o gráfico em Swift Charts, com o menu de período do iOS e os botões de métrica de 32 de altura e 44 de toque) e HISTÓRICO (5 treinos e "Mostrar mais"; cada cartão abre o detalhe do treino). Com texto de acessibilidade, a legenda vai para baixo do boneco, e os dois blocos e as séries do histórico ficam em uma coluna.
- **Exercícios › Meus:** sem busca e sem equipamento, os arquivados ficam no fim: ARQUIVADOS (`SectionTitle`) com a quantidade à direita (12 `secondaryText`), 26 abaixo dos cartões; a explicação (12 `secondaryText` 1,4) 6 abaixo; os cartões 10 abaixo dela. Com filtros, os cartões ficam 8 abaixo da contagem.
- **Telas empilhadas (editor, Programação):** "‹ Treinos" ou "‹ Início" no alto, à esquerda, sem barra de navegação do sistema, e o gesto de voltar deslizando da borda continua funcionando.
- **Folhas:** a folha do sistema, de vidro; título, explicação, conteúdo e botões no pé. Os botões ficam fixos no fim quando o conteúdo rola. Dentro das folhas, os blocos (grupos de opções, grades, campos) seguem o protótipo, com os fundos sólidos dele.
- **Menu ⋯ (ou ⋮):** abre o menu do próprio iOS (`Menu`), com SF Symbols e os textos do protótipo. A exceção é o ⋯ do treino em andamento, que abre a folha "Opções do treino" (as opções e "Descartar treino"), como no protótipo.
- **Grade de escolhas numa folha ("Descanso entre séries"):** 3 colunas com 8 entre elas, cada opção com 48 de altura, cantos 12, texto 16 bold em `mediumText` sobre `screenBackground`; a escolhida em `highlightText` sobre `highlightBadge` com contorno de 1 pt `highlightLine`.
- **Confirmação de apagar:** o `confirmationDialog` do iOS (o balão que sai do botão), com os textos do protótipo: o título diz o que sai ("Excluir “Push”?"), a mensagem explica, e a opção perigosa fica em vermelho (`role: .destructive`), com o botão de voltar ("Cancelar", ou "Voltar ao treino" ao descartar um treino).
- **Ordenar:** botões ↑ ↓ (quadrados de 36, ícones de 18, toque de 44; o ↑ do primeiro e o ↓ do último ficam desativados) e também tocar, segurar e arrastar o exercício para qualquer posição, sem a alça ≡ do iOS.

## 7. Estados e retorno para a pessoa

- **Avisos curtos** (`toast`) para confirmar o que acabou de acontecer: "Treino salvo · 5 séries · 2.640 kg", "Treino descartado", "Série removida", "Nome salvo", "Exercício criado", "Exercício criado e marcado", "Sua versão foi criada", "Cópia criada", "Exercício salvo", "Exercício arquivado", "Exercício apagado", "Exercício restaurado" e outros. Frases curtas, e um aviso por vez.
- **Erros de digitação** aparecem com a mensagem de `UserFacingError`, e o valor anterior é mantido.
- **Estados vazios** dizem o que falta e oferecem o próximo passo ("Nenhum treino criado" + "Iniciar treino livre").
- **Botão desabilitado:** opacidade 0,4 e sem ação.

## 8. Movimento

- As transições padrão do iOS: empurrar a tela, abrir a folha, fade do aviso.
- O ponto cinza-claro pulsando da barra do treino em andamento é a única animação contínua, e para quando "Reduzir movimento" estiver ligado.
- Nada de animação em cada toque. Vibração só onde o protótipo ou o prompt da etapa pedir: hoje, uma vibração leve, sem som, no fim do descanso, e a vibração de sucesso do sistema ao marcar uma série com o ✓ (só ao marcar, não ao desmarcar).

## 9. Acessibilidade

- **Dynamic Type:** todo texto cresce com `scaledFont`. Com letra grande, as linhas quebram ou empilham, sem cortar texto.
- **Toque de 44 pt** em tudo que se toca.
- **VoiceOver:** botões só com ícone têm rótulo; ícones decorativos ficam escondidos; avisos são anunciados. Gráficos têm um resumo ("Maior carga: de 56 kg em qui, 23 jul a 62 kg em sex, 9 out") e a acessibilidade do Swift Charts (cada ponto com a data e o valor, e o gráfico de áudio).
- **Contraste** (texto normal precisa de 4,5:1; texto grande ou negrito de 14 pt para cima, de 3:1; ícones e contornos que dizem algo, de 3:1). Cores do visual novo, cada texto sobre cada fundo em que aparece:

| Texto sobre fundo | Contraste | Situação |
|---|---|---|
| `brightText` sobre `cardBackground` / sobre `screenBackground` | 17,2 / 19,3 | ok |
| `mediumText` sobre `cardBackground` / sobre `cardBorder` (−15, +15) / sobre `setFieldBackground` | 11,2 / 9,4 / 10,0 | ok |
| `secondaryText` sobre `cardBackground` / `setFieldBackground` / `screenBackground` / `currentSetBackground` | 6,8 / 6,0 / 7,6 / 6,2 | ok |
| `dimText` sobre `cardBackground` / `unplannedDayBackground` / `screenBackground` | 5,6 / 5,0 / 6,3 | ok |
| `futureDayText` sobre `cardBackground` / `screenBackground` | 4,6 / 5,1 | ok |
| `suggestionText` sobre `setFieldBackground` | 4,6 | ok |
| `currentSuggestionText` sobre `currentFieldBackground` | 5,0 | ok |
| `highlightSecondaryText` (ÚLTIMA da série atual) sobre `currentSetBackground` | 7,0 | ok (era 4,0 com `futureDayText`) |
| `highlightText` / `highlightSecondaryText` e `highlightLabel` sobre `highlightBackground` | 17,7 / 8,2 | ok |
| `highlightText` sobre `highlightBadge` (no destaque / num cartão) | 14,2 / 12,8 | ok |
| `lightAccent` sobre `cardBackground` / `screenBackground` | 12,3 / 13,8 | ok |
| `primaryButtonText` sobre `primaryButton` (botões principais, também "Tentar novamente" da tela de erro) | 19,3 | ok (o "Tentar novamente" era branco sobre o azul novo, 4,0) |
| Número de ordem em Personalizar: `primaryButtonText` sobre `accentColor` | 5,3 | ok (era #F5F5F7 sobre o azul, 3,65) |
| `markedDayNumber` sobre `markedDayBackground` / `plannedDayLetter` sobre `plannedDayBackground` | 11,2 / 12,8 | ok |
| `failureSet` sobre o próprio fundo de 16% num cartão / sobre `setFieldBackground` ("Descartar") | 4,9 / 5,4 | ok |
| `warmupSet` e `feederSet` sobre o próprio fundo num cartão | 7,6 e 5,3 | ok |
| ✓ branco sobre `accentColor` (ícone, 3:1) / anel azul sobre `cardBackground` | 4,0 / 4,7 | ok |
| Detalhe do exercício: ★ (`warmupSet`) / mudança (`lightAccent`) / ▼ e textos secundários (`secondaryText`) / eixo do gráfico (`dimText`) sobre `cardBackground` | 10,5 / 12,3 / 6,8 / 5,6 | ok |
| › das linhas de Exercícios (`futureDayText`, ícone) / linha do gráfico (`accentColor`) sobre `cardBackground` | 4,6 / 4,7 | ok |
| "ESTE" (`primaryButtonText` sobre `primaryButton`) / textos da folha "Tipos de máquina" (`secondaryText` sobre `screenBackground`) | 19,3 / 7,6 | ok |
| Formulário do exercício: fichas (`mediumText` sobre `cardBackground`) / nome repetido (`failureSet` sobre `screenBackground`) / exemplo do nome (`dimText` sobre `unplannedDayBackground`) / "+ Criar" (`lightAccent` sobre `cardBackground`) / nome do arquivado (`mediumText` sobre `cardBackground`) | 11,2 / 6,8 / 5,0 / 12,3 / 11,2 | ok |
| Boneco: principal / secundário sobre músculo sem uso; principal sobre secundário | 3,5 / 1,9; 1,8 | o boneco é decorativo: a legenda escreve os músculos e o VoiceOver lê o cartão, então a cor não é a única forma de saber |

Sobre o vidro, o contraste depende do que passa por baixo; os valores abaixo foram medidos nos screenshots do CI (o pior caso de cada um):

| Texto sobre vidro | Contraste medido (pior / típico) | Situação |
|---|---|---|
| Barra do descanso: "DESCANSO" / "PRÓXIMA SÉRIE" (`secondaryText`, 8 bold) | 4,9 / 6,7 | ok (o pior é com texto claro do cartão passando por baixo) |
| Barra do descanso: o tempo e "Pronto" (`brightText`, 16 heavy) | 9,4 / 16,7 | ok |
| Barra "Treino em andamento": nome (`brightText`) / "Descanso 1:24" (`highlightSecondaryText`) | 17,1 / 5,4 (típico 7,7) | ok |
| Barra "Treino em andamento": "Abrir" (`highlightText` sobre `highlightBadge`) | 10,3 / 12,7 | ok |
| Botões de vidro do destaque (`highlightText`) | 13,5 / 16,3 | ok |
| Folhas: título (`brightText`) / explicação (`secondaryText`) / nota da calculadora (`dimText`) | 14,8 / 5,2 (típico 6,0) / 5,0 | ok (o vidro das folhas fica em cerca de #1C1C1E sobre o app escurecido) |
| Tela bloqueada de exemplo: texto do aviso (`noticeText`) / "agora" (`noticeSecondaryText`) / data (`lightAccent`) | 10,7 / 6,7 / 11,4 | ok |

Medidos nos screenshots do CI de `bfed25c` (iPhone 17, iOS 26.5, simulador), com o fundo logo acima e abaixo de cada linha de texto; o vidro muda com o que passa por baixo, então estes valores valem para os estados dos screenshots.

`dimText`, `futureDayText` e `suggestionText` foram clareados em 29/10/2026, com aprovação do dono do projeto, para chegar a 4,5:1. Toda cor de texto nova precisa de pelo menos 4,5:1 sobre o fundo em que aparece.
