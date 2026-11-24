# Roteiro do Iron Flow

Plano das etapas do app. Atualizado ao fim de cada etapa. A ordem e o escopo de cada etapa são revistos antes de ela começar.

## Concluído

- Fundação: projeto Xcode, SwiftData com schemas versionados e migração testada, CI com screenshots.
- Exercícios: biblioteca padrão por grupo muscular, com busca e filtro.
- Treinos: criar, renomear e excluir treinos; adicionar e reordenar exercícios; séries planejadas.
- Sessão: iniciar a partir de um treino ou livre, registrar carga e repetições, concluir ou descartar, barra de treino em andamento.
- Início: treino de hoje e resumo rápido personalizável.
- Histórico: lista das sessões concluídas.
- S2 — Detalhe somente leitura de uma sessão concluída (PR #14).
- S3-A — Sua semana e marcação manual (PR #16).
- S3-B — Programação semanal (PR #17).
- Correções da auditoria: limites nos valores do treino, privacy manifest e tempo limite do CI (PR #18).
- S4-A — Tela Treinos no visual do protótipo: treinos em grade com menu, Treino livre e Treinos recentes (PR #19).
- Testes de interface mais rápidos e app somente escuro (PR #20).
- Correções da vistoria: teste do teclado escuro medindo as teclas, pergunta sobre o horário de fim ao concluir um treino esquecido aberto, campos do treino com 44 pt e linha de série para texto grande, e pequenos ajustes de testes e comentários (PR #21).
- Início e Treinos no modelo final aprovado: bloco "Treino de hoje" em destaque, semana com anel da meta, resumo em cartões, grade de treinos com o treino de hoje destacado e treinos recentes com "Ver tudo" (PR #22).
- Treino em andamento no modelo final aprovado: cabeçalho fixo com cronômetro e kg levantados, barra de progresso, cartões com a série atual destacada, coluna ÚLTIMA e sugestões em cinza gravadas pelo ✓, exercício terminado recolhido, timer de descanso e remoção de série ou exercício (PR #23).
- S4-B — Tela Exercícios no modelo final aprovado: lista única em ordem alfabética com busca, filtros de grupo ("Todos", "Meus" e os grupos) e de equipamento, e biblioteca nova com 157 exercícios, cada um com equipamento e foco (PR #24).
- S4-D — Criar e editar treino no modelo novo e tipos de série: uma tela só com todos os exercícios e as séries editáveis ali mesmo, ordenar, renomear, excluir e iniciar pelo editor; tipo de cada série (aquecimento, preparatória, válida e falha) no plano e no treino em andamento, com kg levantados só das séries válidas e de falha; seletor de exercícios em tela cheia com a busca e os filtros da tela Exercícios; SchemaV5 com migração das séries já gravadas como válidas (PR #25).
- S4-E — Acabamento do Início e Treinos: "Descanso hoje" e folha "Escolher treino"; editor de peso, altura e meta com − e +, últimos registros e um peso por dia; no máximo 2 casas decimais nos campos de kg; calculadora de TMB com SchemaV6; Personalizar com dez indicadores; Programação semanal no modelo; confirmação de remover exercício presa ao ⋯ dele (PR #28).
- Correções da revisão: "Última vez" pareada por tipo de série; o editor não sai nem inicia com um valor não salvo; folha "Concluir treino?", que salva só as séries feitas; avisos curtos de confirmação; barra "Treino em andamento" no modelo; exercício adicionado no treino com 3 séries; a meta da semana e a Sequência contam cada dia com treino uma vez; DESIGN.md na raiz; três cores de texto mais claras; fonte Inter (PR #29).
- S4-G — Acabamento visual, o app igual ao protótipo: os ícones do protótipo no catálogo (43 SVGs) e nas telas com modelo, inclusive na barra de abas; medidas conferidas com o CSS do protótipo, tela por tela; menus e confirmações com os textos do protótipo; ordenar com ↑ ↓ e arrastar; folha "Novo treino" no modelo; depois de concluir, o app volta ao Início; "N treinos esta semana" conta dias; avisos de 4 s para textos longos; destaque, falha e texto apagado com contraste de 4,5:1; a altura de linha do protótipo nos títulos e nos textos que têm line-height próprio; séries do editor a 39 pt; folha "Tipo da série" na altura do conteúdo; nome em branco avisado como no protótipo; regra de decisões pequenas no PROJECT_RULES.md (PR #30).
- S4-F — Descanso: tempo de descanso de cada exercício no editor (cápsula e folha "Descanso entre séries", "Sem timer"), copiado para o treino ao começar (SchemaV7); o descanso começa ao marcar uma série e não começa em "Sem timer" nem depois da última série; "Pronto" por 2,5 s com vibração leve, e "Descanso acabou. Próxima: …" no alto em outra tela; aviso por notificação local agendado no começo do descanso, refeito no −15, no +15 e quando o treino muda, e cancelado no Pular, ao concluir e ao descartar; a hora de fim guardada para o app fechado; pedido de permissão só no primeiro descanso, com a folha do app; folha "Opções do treino" com "Manter a tela ligada" e "Aviso do fim do descanso"; folhas a 29 pt do topo e margens dos cartões do editor; iOS 26.0 mínimo; testes de interface com banco em disco (PR da S4-F).
- Campos de série: toque na borda — no editor, tocar em qualquer ponto do fundo cinza dos campos kg, mín e máx dá o foco ao campo (área de toque retangular, como nos campos do treino, sem mudança visual); antes, os últimos 4 pt à direita davam o foco ao campo seguinte. No treino já funcionava. Teste firme do "Pronto" do descanso com um gancho só de teste (`-ui-rest-ready-seconds`) (PR #32).
- CI mais rápido — testes de interface em 3 máquinas ao mesmo tempo, divididos pelo tempo real de cada teste (`ci/ui-test-shards.json`), com a conferência de que cada teste do pacote roda uma vez, na parte dele, e passa; testes de unidade e build Release numa 4ª máquina; o run completo caiu de 59–74 min para cerca de 29 min. Rodada curta só para diagnóstico (disparo manual com os testes e de 1 a 10 repetições, validados), que nunca vale como o CI de uma etapa. Teste instável `WorkoutUITests.testReorderExercises` corrigido no ajudante `waitForEditor` (uma consulta só, até 30 s) (PR #33).
- CI: primeiro teste de cada parte num simulador frio — a apresentação do teclado é tocada de novo até sumir (até 30 s); gancho só de teste `-ui-toast-seconds` (só no Debug com `-ui-testing`), que deixa o aviso 15 s em 10 testes de interface sem mudar nenhum screenshot; o app é aberto e fechado uma vez antes dos testes de cada parte. Corrige as duas falhas do CI do main em 711820f (PR #34).
- Lista de exercícios: biblioteca de 157 para 220 exercícios, com os nomes no padrão do Hevy (equipamento entre parênteses; os de peso do corpo sem parênteses), cada um no grupo do músculo que mais trabalha; "Costas" vira quatro grupos (Dorsais, que mantém o valor gravado "back", Costas superiores, Trapézio e Lombar) e entra Adutores, nos filtros na ordem aprovada; keys, ids e equipamentos de antes não mudam, e o histórico continua com o nome e o grupo de cada dia; busca por palavras na aba Exercícios e no seletor, em qualquer ordem, sem diferenciar maiúsculas, acentos e espaços a mais; os 6 testes de interface que conferiam um aviso sem o gancho -ui-toast-seconds passam a usá-lo e, antes de um screenshot tirado sem o aviso, esperam ele sumir; o toque na barra "Treino em andamento" logo depois de abrir o app é repetido quando se perde, como já acontecia com as abas (PR #35).
- Lista de exercícios, parte 2: biblioteca de 220 para 420 exercícios, com os 200 da segunda lista aprovada, cada um com key e UUID novos, no fim do bloco do seu grupo; "Remada Alta (Máquina)" passa a "Remada Alta Articulada (Máquina)"; keys e ids de antes não mudam e não há schema novo; o seeder decide cada nome com os nomes que ficam no fim da passada, então um exercício recebe o nome que outro deixa, dois trocam de nome e o "Agachamento Búlgaro" novo é criado ativo (testado de 71, 157 e 220 para 420, sem nome mantido nem exercício escondido); a busca acha também pelo nome do equipamento ("halteres", "peso do corpo"); a contagem mostra "0 exercícios"; falha ao salvar registrada com Logger (tipo, domínio e código públicos, descrição privada); a verificação do Release confere os 12 textos dos ganchos de teste (todos no Debug, nenhum no Release); README; vibração ao marcar a série no DESIGN.md; ROTEIRO com o plano novo de etapas (PR da lista de exercícios, parte 2).
- Visual novo — o protótipo aprovado "Iron Flow — visual novo" em todas as telas que já existiam, sem mudar layout, textos, medidas nem funções: cores neutras (preto, branco e cinza, com o azul #3D7BF0 só em detalhes; botões principais brancos com texto preto); a fonte SF Pro, a do sistema, no lugar da Inter, com as alturas de linha do protótipo calculadas sobre a altura real da fonte; o vidro do iOS 26 nas barras "Treino em andamento" e do descanso, nos botões redondos, nos botões secundários do "Treino de hoje" e nas folhas do sistema; a coluna ÚLTIMA da série atual em #A6A6AC (7,0:1); o protótipo em `design/prototipo.html` e o workflow manual "Referências do protótipo", que gera as imagens de comparação com a SF Pro (PR #38).
- Detalhe do exercício e Mapa dos músculos: tela nova pela linha da aba Exercícios (com o ›) e pelo "Ver exercício" do ⋯ do editor e do treino; boneco de frente e de costas com os músculos principais e secundários dos 420 exercícios (dados no código, pela key) e o músculo do grupo nos exercícios próprios; tipo de máquina com a folha "Tipos de máquina"; última vez, melhor série, gráfico de evolução em Swift Charts (3 meses, 1 ano e Tudo; maior carga e volume, ou menor ajuda e mais repetições no Graviton, ou repetições sem carga) e o histórico do exercício; as séries dos 4 exercícios Graviton deixam de contar nos kg levantados, também nos treinos antigos; gancho só de teste `-ui-today` (PR da etapa Detalhe do exercício).

## Próximas etapas

Ordem aprovada pelo dono até o lançamento, nesta sequência. Cada etapa tem protótipo aprovado antes de qualquer tela nova e começa numa conversa nova do Code. Sem recursos sociais.

### S4-C — Exercícios próprios
- + Novo, editar e arquivar, com o equipamento dos exercícios próprios.
- Duplicar um exercício da biblioteca numa versão própria, com nome, evolução e recordes próprios (para as variações de máquina).
- Remover um exercício próprio que tem histórico arquiva o exercício, mas ele continua nos treinos. Decidir no modelo se o app pergunta se quer tirar dos treinos também.
- O exercício próprio escolhe os músculos principais e secundários e o tipo de máquina; até lá, o detalhe mostra o músculo do grupo.

### Ajustar o treino na hora
- Trocar exercício: no treino em andamento, trocar um exercício que ainda não tem série marcada por outro (o seletor abre no mesmo grupo), mantendo a posição e o número de séries, sem copiar cargas e com a "Última vez" do novo. No editor do treino, trocar mantém as séries planejadas.
- M18 — Mover o treino de um dia para outro, sem mudar a programação semanal.
- M4 — Ao concluir, salvar no treino planejado a carga nova, a série a mais ou a troca de exercício (conferir antes o que o app já faz).
- Entram junto os 4 acabamentos da lista (deslizar série, tela acesa por 1 h, desmarcar encerra o descanso, '+N' dos grupos) (16/11).

### Notas e esforço
- M3 — Nota fixa por exercício.
- Notas do treino e RPE/RIR por série.

### Séries avançadas
- M7 — Bi-set e tri-set.
- Descanso por série: cada série pode ter o próprio tempo de descanso (por exemplo, 1:30 nas primeiras e 3:00 na última), com o tempo do exercício como padrão.
- M16 — Tipos de série drop set e rest-pause.
- Os três mudam as regras do descanso e o banco, então ficam juntos: um protótipo e uma migração.

### M5 — Sugestão de carga e estagnação
- Sugestão de carga: subir a carga quando todas as séries válidas chegam ao topo da faixa de repetições. Ela diz o porquê ("bateu 12 em todas") e nunca troca um valor sozinha.
- Aviso de estagnação: um exercício que parou de progredir.

### S5 — Histórico completo
- Desenho no protótipo 'Iron Flow — visual novo': resumo e lista; períodos de 7, 30, 60 e 90 dias (sem "Tudo"); 4 indicadores personalizáveis, como no "Resumo rápido"; gráfico de volume por dia nos 7 dias e por semana nos outros, com a barra atual em azul; a lista com o mês atual aberto e os 3 anteriores recolhidos, e os meses mais antigos só na folha do calendário. A evolução de cada exercício fica no detalhe do exercício.
- Calendário com os dias treinados, mapa do ano com os dias treinados e o total de kg levantados desde o começo.
- Filtros; apagar ou corrigir um treino concluído.
- O detalhe de um treino concluído mostra o tipo de cada série e os kg só das séries válidas e de falha.
- Os recordes (os 3 recentes do resumo e os de cada treino da lista) entram na etapa Recordes e progresso.
- Os recordes recentes do Histórico abrem o detalhe do exercício.
- Mudança do banco, numa versão nova do schema e numa migração só:
  - índices (sessões por data, pesos por data, dias marcados);
  - em cada sessão, o dia local e o fuso de quando ela começou, para um treino não mudar de dia quando o iPhone está em outro fuso (hoje o dia é recalculado com o fuso atual do aparelho; as sessões antigas recebem o fuso do aparelho na migração);
  - em cada sessão, ao concluir, os totais (séries feitas, exercícios e kg levantados), para a lista não abrir todas as séries de cada treino;
  - a meta de dias de cada semana, para a Sequência contar cada semana passada com a meta que ela tinha na época; hoje a meta atual vale para todas (decisão do dono).
- Desempenho com muitos dados: um teste no CI que cria 3 anos de treinos e mede a abertura do app, o Início (inclusive a releitura dos indicadores a cada volta à aba), o Histórico, a rolagem, o ✓ e a digitação no treino em andamento.
  - A digitação: hoje cada tecla reordena e redesenha todos os cartões do treino; otimizar se passar do aceitável.
  - O ✓: cada série salva muda a sessão em andamento, e isso refaz as buscas do Histórico (todas as sessões concluídas), da semana e do resumo. Medir e, se preciso, salvar só a série.
- As buscas do Histórico e da coluna ÚLTIMA leem só o necessário. A ÚLTIMA hoje lê e ordena todas as sessões concluídas ao abrir o treino e a cada exercício adicionado; ler em lotes de 20 até achar todos os exercícios.
- Os testes de interface que contam por período ("hoje", "esta semana", "no mês") semeiam os treinos a partir do meio-dia de hoje, ou usam um gancho só de teste `-ui-now`, para não falhar na virada do dia, da semana ou do mês.

### Recordes e progresso
- Recordes pessoais e 1RM estimado, com o aviso de recorde na hora, durante o treino; os 3 recordes recentes do Histórico e os recordes de cada treino da lista.
- O 1RM estimado e a lista de recordes entram no detalhe do exercício (o gráfico ganha a métrica 1RM).
- Nos 4 exercícios Graviton o kg é a ajuda da máquina: o recorde é com menos kg, como a melhor série do detalhe (decisão do dono).
- M6 — Recordes pessoais comemorados e cartão do treino para os Stories.
- M8 — Resumo da semana e do mês com mapa do corpo: as séries válidas e de falha por grupo principal, semana contra semana, sem pontuar músculos secundários. Reaproveita o boneco do detalhe do exercício.
- M17 — Gráfico do peso do corpo com a linha da meta e o ritmo por semana.
- Apagar um registro de peso errado, com confirmação (hoje só dá para mudar o de hoje, e um peso errado de outro dia fica para sempre).

### M1 — Treino na tela bloqueada e na Ilha Dinâmica (Live Activity)
- Descanso, série atual e botões para usar sem abrir o app. Tocar no aviso do fim do descanso abre o treino direto (hoje o app só abre onde estava).
- Instalar o plugin context7 no Code antes de começar esta etapa.
- Tirar da Central de Notificações o aviso do fim do descanso que já foi entregue, quando o descanso acaba com o app aberto.
- Decidir se o aviso do fim do descanso fica "sensível ao tempo", para passar pelo modo Foco (pede uma capacidade nova do app; decisão do dono).
- O banco continua com a proteção de arquivo padrão do iOS (ver Decisões), porque esta etapa grava séries com o iPhone bloqueado.

### M2 — Widgets na tela inicial e na tela bloqueada
- Mesma base técnica da M1. O widget roda em outro processo e só lê um contêiner compartilhado (App Group): o app grava ali um resumo pequeno, sem mover o banco.

### S7 — Ajustes
- Desenho no protótipo 'Iron Flow — visual novo': Conta e assinatura; Perfil (peso, altura e meta de calorias pela calculadora); Treino (meta por semana, primeiro dia da semana, descanso padrão, aviso do fim do descanso, som ou só vibrar, vibrar, tela acesa, aquecimento nas estatísticas e lembrete de treino); Unidades e idioma (kg ou lb; o idioma segue o do iPhone); Apple Saúde; Seus dados; Fale com a gente; Sobre e ajuda; Zona de perigo (apagar tudo, com confirmação dupla).
- Apple Saúde: gravar o treino como treino de força e ler o peso. (A antiga M10 era a mesma coisa e saiu.)
- Unidades e idioma: um lugar só para o idioma (hoje `pt_BR` fixo em 6 arquivos) e para a unidade de carga (hoje "kg" fixo nos textos).
- Aparência: a pessoa escolhe a cor de destaque (rosa, vermelho, amarelo, verde e outras); tudo o que hoje é azul segue a cor escolhida, inclusive o boneco dos músculos. Protótipo antes, cuidando do contraste de cada cor em cada uso e da confusão com o amarelo do aquecimento e do recorde e com o vermelho da falha (decisão do dono, 23/11).
- Fale com a gente: enviar feedback e "Seja um influenciador", pelo app de e-mail do iPhone, para um e-mail só do app que o dono vai criar antes desta etapa (nunca um e-mail pessoal). O mesmo e-mail serve para o suporte da App Store e a política de privacidade.

### Seus dados
- M14 — Importar o histórico do Hevy e do Strong (CSV). Regras a decidir no plano: o mesmo exercício duas vezes no treino (os outros apps permitem, e o app hoje recusa); os limites de valores (100 repetições, 1.000 kg, 60 caracteres e 2 casas decimais, que recusariam libras convertidas); um caminho próprio no serviço para gravar uma sessão já concluída com data antiga; e uma tabela que liga os nomes dos outros apps às keys da biblioteca (o resto vira exercício próprio).
- Exportar os dados em planilha (CSV).
- Backup completo: um arquivo com todos os dados, que dá para guardar fora do iPhone, e "Restaurar backup", com teste de ida e volta. O backup leva também as preferências guardadas fora do banco (indicadores escolhidos e opções do treino). O "Restaurar" confere os ids que já existem antes de gravar, porque um id repetido substituiria o registro em silêncio.
- Lembrete periódico de fazer o backup.
- Se o Firebase entrar, as exclusões passam a deixar uma marca, para a sincronização saber apagar nos outros aparelhos.

### Assinatura
- Assinatura pela App Store (StoreKit), com o ID Apple e sem conta: 30 dias grátis e depois pago, "Restaurar compras" e "Gerenciar assinatura". O preço é decidido pelo dono perto do lançamento.
- Sem assinatura, o histórico, os recordes e a exportação continuam liberados, só para ler; registrar treinos novos pede a assinatura. Os dados nunca são apagados.
- A assinatura é sempre conferida com a Apple (transações assinadas do StoreKit), nunca por um valor salvo no iPhone.
- Um único lugar inicia sessões (`RootView.startSession`): é ali que entra a conferência da assinatura.
- Usar o plugin finecomb (revisão de código e de segurança) nesta etapa.

### Primeira abertura e planos prontos
- M19 — Boas-vindas na primeira abertura: meta por semana, peso (opcional) e começar por um plano pronto.
- M15 — Planos prontos: Push/Pull/Legs, Superior/Inferior, Corpo inteiro e 5×5.
- O fluxo termina na tela da assinatura: a pessoa começa o teste grátis de 30 dias (ou assina) antes de usar o app, sem pular.

### M9 — Cardio
- Área de cardio: a pessoa cronometra a corrida e o histórico guarda pace, gasto calórico aproximado e dados parecidos; calorias aproximadas também na musculação.

### S10 — Revisão final e TestFlight
- Revisão completa do app inteiro antes do TestFlight, e de novo antes do lançamento (as duas únicas revisões do app inteiro; nas outras etapas, o /code-review e as conferências olham só o que mudou).
- Plugins finecomb (revisão de código e de segurança) e Mobile Release Check, instalados só nesta etapa.
- Regressão completa, uso offline, acessibilidade e desempenho.
- Build Release, tamanho do app e envio ao TestFlight.
- Nome novo do app e bundle ID novo antes do envio (ver Pendências).
- `ITSAppUsesNonExemptEncryption` no projeto, para a Apple não perguntar sobre criptografia a cada envio.
- Nenhuma tela 'em breve' no envio à Apple, porque a revisão costuma recusar.
- Conferir no iPhone de verdade a seleção de texto com toque duplo e a lupa nos campos de série do editor (o CI não testa).
- Ícone do app.
- Mensagem amigável na tela de erro ao abrir os dados.
- Datas do Histórico e dos treinos recentes com o calendário do app (`TrainingDay.calendar`) em vez do calendário do aparelho: hoje o `SessionFormatting` usa o do aparelho por padrão, e num calendário budista ou japonês o ano sai errado.
- A biblioteca de 420 exercícios é lida e conferida a cada abertura, antes da primeira tela; guardar a versão aplicada e pular quando for a mesma, gravando a versão só quando a correção dos nomes terminar sem nenhum nome mantido (`keptNameKeys` vazio).
- Limpeza de código:
  - só usado nos testes: `SessionService.activeSession()` (com o erro `multipleActiveSessions`); o `RestTimer.isOver(at:)` é usado pelo app, no `RestController`.
  - sem tela: `WorkoutService.movePlannedSets`;
  - repetidos: `durationText` e `compactDurationText`; os nomes dos dias em `WeekSummary` e em `WeeklyPlanSummary`; as letras dos dias em `WeekSummary` e em `WorkoutListView`; a escolha em segmentos da calculadora de TMB e da folha "Concluir treino?";
  - repetidos, do /code-review do PR #29: o arredondamento da duração falada em `SessionFormatting.spokenDurationText`, e as duas funções quase iguais de criar série (`SessionService.makeSetLog`).
  - repetidos, da revisão completa de novembro: guardar o rascunho ao perder o foco (`SessionView` e `WorkoutEditorView`); as duas buscas da semana (`WeekCard` e `SummaryCards`); as sessões concluídas redeclaradas no `HistoryView` (já existem no `SessionService`); "hoje / ontem / data" (`SessionFormatting` e `SummaryIndicators`); o título de folha feito à mão no `SessionOptionsSheet` (o `SheetHeader` já faz isso).
- Com a folha "Concluir treino?" aberta por mais de 1 hora, a pergunta do treino esquecido (último registro ou agora) não aparece; ela só é feita quando a folha abre (do /code-review do PR #29).
- Diferenças antigas com o DESIGN.md nas telas ainda sem modelo, a refazer na etapa de cada uma:
  - Histórico e Ajustes: a tela vazia do sistema (`ContentUnavailableView`) e o título do detalhe do Histórico com a fonte do sistema; o Histórico com tamanhos 17/15/13 adaptados; cores `.secondary` do sistema;
  - tela de erro ao abrir os dados: o texto técnico em SF Mono;
  - essas telas continuam com SF Symbols até ter modelo.
- Opcional: um `.github/dependabot.yml`, para avisar de versões novas das ações do CI (hoje fixadas por SHA).
- Antes do lançamento, o dono decide se o repositório continua público ou vira privado. Se virar privado, os minutos de macOS do CI passam a ser cobrados, e o CI em paralelo usa mais minutos no total do que um CI numa máquina só. Rever o CI antes de mudar.

### Firebase (opcional)
Decidido pelo dono e pelo chat juntos, depois de testar o app no TestFlight. Se não entrar agora, vem com o projeto Android.
- Conta opcional (e-mail e senha, Google e Apple) que sobe os dados do iPhone, com sincronização. Ao criar a conta, os dados do aparelho são enviados para ela, nunca apagados.
- Usar o plugin finecomb nesta etapa.
- Lista de segurança obrigatória:
  - regras de segurança do Firebase: cada pessoa só lê e grava os próprios dados;
  - App Check e limites de uso, para que só o app fale com o servidor;
  - nenhuma chave de administrador no app, e o arquivo de configuração do Firebase fora do repositório público;
  - os dados também são validados no servidor;
  - campos protegidos que o app não pode alterar (por exemplo, a assinatura);
  - login sem guardar senhas no app;
  - apagar a conta dentro do app;
  - alertas de dependências do GitHub ligados quando entrar o SDK do Firebase;
  - política de privacidade e relatório de privacidade atualizados.

### Depois do lançamento
- M11 — Importar a ficha de treino por foto.
- M12 — Apple Watch.
- M13 — Strava.
- Projeto Android, com o Firebase (conta, sincronização entre iPhone e Android e assinatura valendo nos dois), se ele não tiver entrado antes.

Fora do plano: desafios entre amigos e feed social. Ideias avaliadas e não escolhidas: exercício reserva, repetições por lado, mapa de recuperação, fotos de progresso, rodízio A/B/C e instruções de execução dos exercícios.

## Acabamentos

Detalhes pequenos achados no caminho ficam aqui e não viram etapa sozinhos: cada um entra junto da próxima etapa que mexe naquela tela, com a aprovação do dono, como o resto do escopo.

- Tela do treino: deslizar uma série para apagar (com Desfazer) ou para copiar.
- Tela do treino: com "Manter a tela ligada", a tela pode apagar depois de 1 hora sem série marcada, o mesmo tempo do treino esquecido; hoje ela nunca apaga com um treino esquecido aberto (decisão do dono).
- Tela do treino: desmarcar a série que começou o descanso atual encerra esse descanso, com a barra e o aviso; hoje eles continuam correndo (decisão do dono).
- "Escolher treino" e Programação semanal: um treino com muitos grupos fica cortado com "…". Mostrar no máximo alguns grupos e "+N"; os detalhes se decidem quando a tela for mexida.
- Medidas acima de 1 pt contra o protótipo, achadas na etapa Visual novo (screenshots do CI contra as referências do workflow "Referências do protótipo"). Parte delas vem de dados de exemplo diferentes entre o protótipo e os testes: na hora de corrigir, comparar com os mesmos dados.
  - Início (screenshots 1, 22, 30, 38, 42, 50, 52, 53, 55 e 93): os cartões do resumo rápido estão 1,7 pt mais baixos que no protótipo (98,3 × 100). Nos estados "Descanso hoje", "Em andamento" e "Nada programado" (31, 32, 51, 54 e 83), o cartão da semana e o que vem abaixo ficam de 2,3 a 3,7 pt mais acima, porque o link "Programar semana" ocupa menos altura que no protótipo.
  - Treinos (2, 11, 26, 56, 57 e 58): cada cartão da grade de treinos está 2,7 pt mais alto (143,7 × 141), e a segunda linha da grade desce de 3 a 4,3 pt; o cartão "Nenhum treino ainda" e a linha da Programação semanal ficam 1,3 pt abaixo.
  - Programação semanal (41, 89 e 90): o cartão da meta da semana está 1,7 pt mais alto (72,7 × 71), e os dias abaixo dele descem de 1,3 a 1,7 pt.
  - Editor do treino (75, 78, 95 e 106): cada linha de série fica cerca de 0,3 pt mais baixa (−1,3 pt no fim da tela ou do segundo cartão); ao ordenar, de −1,3 a −2,0 pt; um nome longo quebra uma palavra antes, porque o app reserva mais espaço para o ⋯ que o protótipo.
  - Seletor de exercícios (77): a barra de cima ("Cancelar" e o título) está 4,3 pt mais alta.
  - Treino em andamento (25, 63 a 69, 80, 91, 92, 98 a 102 e 107): cada linha de série fica cerca de 0,3 pt mais baixa (−1,3 pt a partir do segundo cartão).
  - Folha "Avisar quando o descanso acabar?" (97): a tela bloqueada de exemplo tem a data em 13 e a hora em 52 (no protótipo, 12 e 46), e o conteúdo fica de 1,3 a 2,7 pt fora de lugar.

## Pendências da vistoria

- O app precisa de um nome novo antes do lançamento, porque já existe na App Store o "IronFlow: Gym Strength Tracker". O dono decide o nome depois. Antes do TestFlight, trocar também o bundle ID `com.ironflow.app`, que é o mesmo de um app de Android com esse nome. Os nomes internos do código (pastas, alvos e o arquivo do banco) ficam como estão.
- Conferir no iPhone de verdade, no TestFlight, o que o CI não consegue testar na S4-F: o aviso do fim do descanso com o celular bloqueado e com o app fechado, a pergunta real do iPhone sobre as notificações (com o texto do sistema) e o toque na notificação.
- Com o iOS 26 mínimo, ver se dá para aproximar as linhas dos títulos de duas linhas como no protótipo (sugestão; precisa da aprovação do dono).
- Nomes de treino repetidos ficam ambíguos no VoiceOver ("Opções de Push") e no menu de iniciar.
- O banco é aberto de forma síncrona ao iniciar o app; uma migração num banco grande atrasaria a abertura.
- Após uma falha ao salvar, o rollback() do SwiftData não restaura os valores alterados nos objetos em memória. O banco fica correto e o erro é mostrado, mas a tela pode exibir o valor não salvo até o objeto ser lido de novo. Raro (ex.: disco cheio). Prioridade baixa: resolver antes da S10. Coberto por teste com withKnownIssue.
- No editor do treino, "‹ Treinos" e "Iniciar" ficam na tela quando um valor digitado não pode ser salvo (PR #29). As outras ações que abrem algo (adicionar exercícios, tipo da série, ordenar, remover exercício) mostram o erro, mas seguem. Decidir se elas também devem parar.
- HomeUITests.testEditSummaryValues falhou uma vez por um toque perdido durante animação (run 39884902708) e falhou de novo no CI da main em db5c717 (run 40437064904, digitação antes de o campo ficar ativo); corrigido no PR #27, que também deixa mais lento o arraste do WorkoutUITests.testReorderExercises.
- Proteger o main no GitHub com uma regra (bloquear apagar e reescrever o main e exigir PR). O dono fará isso quando tiver um computador, porque pelo ambiente do Claude a alteração é bloqueada. Checks a exigir: 'Interface tests complete' e 'Unit tests and Release (Xcode 26.6, iPhone 17, iOS 26.5)'. O antigo 'Build and test' não existe mais.
- O primeiro toque nos filtros de Exercícios às vezes se perde no CI (PR #39: 2 vezes em 6 runs, cerca de 7 s depois de abrir a aba); o ajudante `tapFilter` toca de novo. Na etapa Detalhe do exercício, um diagnóstico temporário (os toques que chegam à janela, as ações dos filtros e as fases de rolagem, no commit ef18676) não reproduziu a perda em 66 toques: 60 em duas rodadas curtas (antes e depois de as linhas virarem links) e 6 em runs completos. Todo toque que chegou ao app acionou o filtro em até 4 ms, sem rolagem no meio. No run em que a perda fez o teste falhar (44635190069), o mesmo teste também perdeu o toque na barra de abas do sistema, com o app levando 20 s para abrir e cada consulta da tela até 10 s: tudo indica perda do toque sintetizado pelo simulador sob carga, não do app, mas sem prova direta. Se voltar a acontecer, rodar de novo o diagnóstico para ver se o toque chega à janela.
- Aquecimento do simulador no CI: custa de 25 a 87 s por parte e não mostrou ganho claro em 2 runs. Comparar o tempo do primeiro teste de cada parte nos próximos runs e decidir na próxima etapa que mexer no CI.

## Decisões

- Sem recursos sociais no início: "Privacidade e social" fica fora até nova decisão.
- O repositório é público para o CI rodar sem custo. Nunca colocar senhas, chaves ou dados pessoais nele.
- Secret Protection e Push protection estão ligados no GitHub.
- Identidade visual: preto, branco e cinza, com o azul só em detalhes, e o vidro do iOS 26 (Liquid Glass) só nos controles que flutuam sobre o conteúdo e nas folhas do sistema.
- Fonte: SF Pro, a fonte do sistema, em todo o app. A Inter saiu na etapa Visual novo (novembro de 2026).
- O protótipo aprovado fica em `design/prototipo.html`, fora do app. As imagens de referência saem do workflow manual "Referências do protótipo" (o protótipo no WebKit do macOS, com a SF Pro, no tamanho dos screenshots do CI), no run e na pasta `prototipo/` do branch `ci-prototipo`.
- O app é somente escuro: não há tema claro nem opção de tema nos Ajustes.
- Cada tela é construída a partir de um modelo visual aprovado pelo dono antes.
- Toda etapa que mudar o banco de dados cria uma nova versão do schema, com teste de migração.
- Os 6 commits iniciais com e-mail pessoal ficam como estão; commits novos usam um e-mail noreply (o do ambiente do Claude serve), nunca um e-mail pessoal.
- O app lança com a assinatura pela App Store, com o ID Apple e sem conta (a Apple não permite exigir cadastro para uma assinatura que não precisa de conta): 30 dias grátis, depois pago, e "Restaurar compras". A primeira abertura termina na tela do teste grátis, sem pular. Substitui o plano antigo de lançar grátis e ter o teste de 14 dias depois.
- Lançamento só com a Apple: os dados ficam no iPhone, protegidos pelo backup do iPhone e pelo arquivo de backup do app, com lembrete. O Firebase (conta opcional e sincronização) é uma etapa opcional, decidida junto depois do TestFlight, ou vem com o projeto Android.
- O banco usa a proteção de arquivo padrão do iOS (protegido até o primeiro desbloqueio depois de ligar o iPhone), porque a M1 grava séries com o iPhone bloqueado.
- Sem assinatura, o histórico, os recordes e a exportação continuam liberados, só para ler; registrar treinos novos pede a assinatura. Os dados nunca são apagados.
- Sem calculadora de anilhas.
- Revisões: em cada etapa, o /code-review e as conferências olham só o que mudou. O app inteiro é revisado só em dois momentos, antes do TestFlight e antes do lançamento.
- O app pede o iOS 26.0 ou mais novo (app e alvos de teste): ele só é testado e medido no iOS 26.
- Nomes dos exercícios no padrão do Hevy, com o equipamento entre parênteses (os de peso do corpo ficam sem parênteses). Exceções aprovadas: a pegada ou a máquina entre parênteses quando é isso que diferencia (por exemplo, "Barra Fixa (Pegada Aberta)" e "Barra Fixa (Graviton)"), e nomes conhecidos sem parênteses (por exemplo, "Kettlebell Swing"). Cada exercício fica no grupo do músculo que ele mais trabalha.
- O openGym (licença AGPL) serve só de fonte de ideias: nenhum código nem dado dele é copiado.
