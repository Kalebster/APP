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
- Detalhe do exercício e Mapa dos músculos: tela nova pela linha da aba Exercícios (com o ›) e pelo "Ver exercício" do ⋯ do editor e do treino; boneco de frente e de costas com os músculos principais e secundários dos 420 exercícios (dados no código, pela key) e o músculo do grupo nos exercícios próprios; tipo de máquina com a folha "Tipos de máquina"; última vez, melhor série, gráfico de evolução em Swift Charts (3 meses, 1 ano e Tudo; maior carga e volume, ou menor ajuda e mais repetições no Graviton, ou repetições sem carga) e o histórico do exercício; as séries dos 4 exercícios Graviton deixam de contar nos kg levantados, também nos treinos antigos; gancho só de teste `-ui-today` (PR #40).
- S4-C — Exercícios próprios: criar, editar, duplicar e "Criar minha versão" de um exercício da lista, com nome (até 60 letras, único sem diferença de maiúsculas e acentos, contando os próprios arquivados), grupo, equipamento ("Outro" vale, com ícone novo), tipo de máquina (só com Máquina) e músculos principais e secundários (vindos do grupo até a pessoa mexer, nenhum nas duas listas), no formulário em tela cheia e nas folhas dos músculos; remover (decisão do dono, 1A): com histórico ou no treino em andamento o exercício é arquivado, sem histórico é apagado, e nos dois ele sai de todos os treinos planejados, com a ordem renumerada e o histórico com o nome do dia; restaurar volta para a lista e não para os treinos, com alerta se um exercício ativo tem o nome; Meus com os arquivados no fim; + Novo e + Criar na aba e no seletor (volta marcado); ⋯ no detalhe, selos MEU e ARQUIVADO e cartão do arquivado; Graviton próprio fora dos kg levantados e com a evolução invertida; busca pelo equipamento do próprio; SchemaV8 com migração testada; dois treinos no mesmo dia viram dois pontos do gráfico; os cartões de Exercícios com filtros no lugar do protótipo (71); treino apagado avisa no detalhe (gancho só de teste `-ui-delete-tapped-session`) (PR #41).
- Lista base de exercícios: biblioteca de 420 para 103 exercícios base e 1.525 combinações (391 comuns), cada combinação com histórico, evolução e recordes próprios, lidas de um JSON no app (`IronFlow/Library/ExerciseLibrary.json`, gerado do design/lista-base-dados.json aprovado e conferido por teste; escrita em Swift, a lista levava o build Release a mais de 28 minutos); migração na primeira abertura, numa gravação só e sem schema novo: 283 com o mesmo nome, 32 renomeados (os 4 "Remada Alta (…)" viram "Remada Ombro (…)"), 4 junções que levam o histórico e os treinos do segundo para o primeiro, e 105 que saem (com uso, viram exercícios em Meus com o histórico; sem uso, são apagados); combinação com o nome de um exercício próprio entra escondida e volta quando o nome fica livre; aba Exercícios e seletor com os exercícios base, filtro de equipamento pelos comuns e busca por nome base, variações, comuns, nomes antigos e populares; detalhe com as filas EQUIPAMENTO e PEGADA/VARIAÇÃO (cinzas, Barra W e Graviton) e "+ Adicionar a um treino"; folha de escolha no seletor (Escolher, Desmarcar, "Já está no treino", "Também escolhido", toque direto com o filtro de equipamento); "Montar treino" na aba e a folha "Adicionar a um treino" (treino que já tem tudo desligado, só o que falta entra, treino novo abre no editor); textos do formulário do exercício próprio ("Grupo principal" e "Pode marcar mais de um"); acabamentos: linha do WebKit nos textos de 11 e 12 pt das telas da etapa, e os botões da etapa desligados a 35 % (`PrototypeButtonStyle`); seção 15 "Segurança permanente" no PROJECT_RULES e as linhas de segredos no .gitignore; a abertura normal só confere a versão da biblioteca e a contagem (0,003 s, contra 0,048 s no main), e a aba lê só o treino mais recente de cada exercício feito (66 ms com 3 anos de 4 treinos por semana, eram 1,8 s) (PR #42).

## Próximas etapas

Ordem aprovada pelo dono até o lançamento, nesta sequência. Cada etapa tem protótipo aprovado antes de qualquer tela nova e começa numa conversa nova do Code. Sem recursos sociais.

### Ajustar o treino na hora
- Substituir exercício: item no ⋯ de cada exercício, no editor do treino e no treino em andamento, logo depois de "Ver exercício". Abre o seletor no grupo do exercício, com o título "Substituir exercício" e a linha do que acontece; escolher um exercício (toque direto ou "Substituir" na folha de equipamento) já substitui na mesma posição, com o aviso "Substituído por <nome>".
- No editor, as séries planejadas ficam. No treino em andamento, ficam o número e o tipo das séries, sem as cargas e com a "Última vez" do novo; o treino planejado não muda. Com série já marcada (resposta 1B do dono): as séries feitas ficam com o exercício antigo e o novo entra logo depois com as que faltavam; o item mostra "Nas séries que faltam" e o aviso é "<novo> entrou nas séries que faltam". No histórico, a sessão guarda os dois exercícios, cada um com as suas séries.
- A combinação atual aparece como "É o exercício atual" e a que já está no treino como "Já está no treino", as duas desligadas. Toque duplo substitui uma vez só.
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
- O arquivo de backup e a importação do Hevy e do Strong são tratados como não confiáveis: um arquivo malfeito, gigante ou com valores absurdos não trava o app nem estraga os dados. Checagem do Claude Security.
- Com a conta, as exclusões deixam uma marca, para a sincronização apagar nos outros aparelhos.
- Segurança (plano de 27/11): todo arquivo de fora é não confiável: limite de tamanho, validação de cada valor, nada é trocado antes de tudo ser conferido; o backup avisa que leva dados pessoais e fica onde a pessoa escolher; testes com arquivo vazio, gigante, cortado, com texto no lugar de número, com datas absurdas e com ids repetidos.

### Conta e sincronização
- Antes desta etapa, o chat lembra o dono da decisão do repositório: ele fica público enquanto isso não pesa na segurança (nenhuma chave secreta no repositório) e vira privado perto do lançamento.
- Firebase ou Supabase se decide no começo desta etapa, com uma comparação feita pelo chat com os números reais do app.
- Conta obrigatória na primeira abertura, com Entrar com a Apple, sem guardar senhas no app.
- Os dados também são validados no servidor.
- Nenhuma chave de administrador no app, e o arquivo de configuração do servidor fora do repositório público.
- Funcionar sem sinal e sincronizar depois, sem perder nem duplicar, inclusive com dois aparelhos; sincronizar só o que mudou e tentar de novo com espera crescente.
- Teste de carga no emulador do servidor.
- Relatório de travamentos.
- Avaliação do SDK do servidor (licença, tamanho e falhas conhecidas), com os alertas de dependências do GitHub ligados quando ele entrar.
- Checagem do Claude Security nas mudanças.
- Segurança (plano de 27/11):
  - toda linha tem dono, e a regra do banco compara o dono com o login; tudo começa negado; o servidor tira a identidade só do token e ignora qualquer id de dono que o app mande;
  - campos que só o servidor escreve (assinatura, dono, datas do servidor) ficam travados;
  - login só com Entrar com a Apple, no modo nativo, com nonce contra repetição; sessão no Keychain; sair apaga a sessão do aparelho;
  - apagar a conta dentro do app: revoga o login da Apple, apaga os dados do servidor e limpa o aparelho, dizendo quanto tempo leva;
  - abuso: só o app verdadeiro fala com o servidor (App Check ou equivalente), limite de pedidos e de tamanho, consultas paginadas, alerta e teto de gasto;
  - painel do servidor com verificação em duas etapas, conexão segura obrigatória, cópias automáticas do banco e um teste de restauração;
  - privacidade: política (LGPD), etiquetas da App Store e o manifesto de privacidade da Apple; treino, peso e saúde tratados como dados sensíveis;
  - testes de ataque no CI, num servidor local de teste: a pessoa A tenta ler, mudar e apagar os dados da B; sem login; token vencido; conta apagada; campo proibido; consulta gigante; texto com comando de banco. Tudo tem de ser negado.

### Assinatura
- Assinatura pela App Store (StoreKit), presa à conta e conferida no servidor pelos avisos da App Store: 30 dias grátis e depois pago, "Restaurar compras" e "Gerenciar assinatura". O preço é decidido pelo dono perto do lançamento.
- Um reembolso volta ao modo só leitura.
- Sem assinatura, o histórico, os recordes e a exportação continuam liberados, só para ler; registrar treinos novos pede a assinatura. Os dados nunca são apagados.
- A assinatura é sempre conferida com a Apple (transações assinadas do StoreKit), nunca por um valor salvo no iPhone.
- Um único lugar inicia sessões (`RootView.startSession`): é ali que entra a conferência da assinatura.
- Checagem do Claude Security nesta etapa.
- Segurança (plano de 27/11): o servidor recebe os avisos da App Store (versão 2) e confere a assinatura digital da Apple em cada um; o estado da assinatura é gravado só pelo servidor; a chave da API da App Store fica só no servidor; testes: aviso falso recusado, aviso repetido sem efeito, app tentando gravar "assinante" recusado.

### Primeira abertura e planos prontos
- M19 — Boas-vindas na primeira abertura: meta por semana, peso (opcional) e começar por um plano pronto.
- M15 — Planos prontos: Push/Pull/Legs, Superior/Inferior, Corpo inteiro e 5×5.
- O fluxo começa com Entrar com a Apple (conta obrigatória) e termina na tela da assinatura: a pessoa começa o teste grátis de 30 dias (ou assina) antes de usar o app, sem pular.

### M9 — Cardio
Ideia 3 do dono; desenho no protótipo, aba Treinos › Cardio.
- Aba Treinos em duas páginas lado a lado, "Musculação | Cardio" (seletor de duas partes nativo e páginas que se arrastam para o lado; abre na Musculação). Na página Cardio, as atividades em cartões como os treinos, com ▶ para começar direto, e CARDIO RECENTE.
- Atividades: corrida, caminhada, bicicleta, elíptico e natação. Corrida, caminhada e bicicleta na rua com o GPS do iPhone (distância, pace ou velocidade, voltas por km e percurso no mapa); esteira, ergométrica e elíptico só cronometram e a distância entra no fim; natação e qualquer outra se registram à mão.
- Tipos de corrida: Livre, Intervalado, Longão, Regenerativo e Prova.
- Intervalado com timer próprio (resposta 3B do dono): aquecimento opcional, tiros por tempo ou distância (na esteira, só por tempo), descanso por tempo e quantidade de tiros, com o Stepper do iOS; em andamento, a contagem da etapa, a barra de progresso, "A seguir" e "Pular"; a cada troca, vibração e um som curto que não para a música, também com o celular bloqueado; desaquecimento livre no fim; o resumo lista os tiros com o pace e o mais rápido.
- Registrar um cardio pelo Histórico ("Registrar" no bloco CARDIO), escolhendo a atividade na mesma folha.
- Ajustes › "Cardio conta na meta" (escolha da pessoa, começa desligado): ligado, um dia com cardio conta 1 no anel da semana.
- Permissão de localização só durante o cardio (pergunta do próprio iOS, com o motivo); negada, a rua explica e oferece a esteira. O percurso fica só com a pessoa.
- O tempo continua com o celular bloqueado; tempo e pace na tela de bloqueio (junto com a etapa da tela de bloqueio).
- Linhas de cardio numa linha só (tipo de corrida no lugar do local) com a duração à direita.
- Resumo com tempo, distância, pace/velocidade, voltas, mapa e calorias aproximadas pelo peso do perfil; entra no Histórico (bloco CARDIO) e pode ser apagado.
- Trazer do Apple Saúde o cardio que o Apple Watch (ou outro app) gravou, sem duplicar o que já veio do Iron Flow (resposta 3A do dono).
- Novidade de banco: uma versão nova do schema para o cardio (atividade, local, tipo, início, duração, distância, voltas, percurso e, no intervalado, a configuração e os tiros), com migração e teste.
- Segurança (plano de 27/11): o percurso do GPS fica no aparelho; do Apple Saúde, só o necessário, com permissão e nunca para publicidade.

### S10 — Revisão final e TestFlight
- Revisão completa do app inteiro antes do TestFlight, e de novo antes do lançamento (as duas únicas revisões do app inteiro; nas outras etapas, o /code-review e as conferências olham só o que mudou).
- Varredura completa do Claude Security, com simulação de ataques, no lugar do finecomb; o plugin Mobile Release Check fica, instalado só nesta etapa.
- Nova busca por ferramentas de segurança feitas para apps de iPhone e Swift.
- Etiquetas de privacidade da App Store.
- Regressão completa, uso offline, acessibilidade e desempenho.
- Build Release, tamanho do app e envio ao TestFlight.
- Nome novo do app e bundle ID novo antes do envio (ver Pendências).
- `ITSAppUsesNonExemptEncryption` no projeto, para a Apple não perguntar sobre criptografia a cada envio.
- Nenhuma tela 'em breve' no envio à Apple, porque a revisão costuma recusar.
- Conferir no iPhone de verdade a seleção de texto com toque duplo e a lupa nos campos de série do editor (o CI não testa).
- Ícone do app.
- Mensagem amigável na tela de erro ao abrir os dados.
- Datas do Histórico e dos treinos recentes com o calendário do app (`TrainingDay.calendar`) em vez do calendário do aparelho: hoje o `SessionFormatting` usa o do aparelho por padrão, e num calendário budista ou japonês o ano sai errado.
- A biblioteca de 1.525 exercícios é lida e conferida a cada abertura, antes da primeira tela; guardar a versão aplicada e pular quando for a mesma, gravando a versão só quando a correção dos nomes terminar sem nenhum nome mantido (`keptNameKeys` vazio).
- Revisar, com o dono, quais equipamentos são comuns e quais ficam em cinza em cada exercício da lista base: alguns estão trocados (ex.: máquina em cinza onde é comum). O funcionamento fica como está (dono, 26/11).
- Segurança (plano de 27/11):
  - revisão das regras do banco por um agente que não escreveu o código;
  - teste de ataque manual com duas contas no TestFlight;
  - chaves de produção novas e projetos de teste e produção separados;
  - varredura de segredos no arquivo do app pronto (.ipa) e no repositório;
  - plano de resposta a incidente escrito: conter, trocar as chaves, registrar e avisar as pessoas e a ANPD em até 3 dias úteis quando houver risco relevante (Resolução CD/ANPD nº 15/2024);
  - checklist final de segurança, item por item, com a prova de cada um: tabelas fechadas por padrão; testes de ataque passando; revisão independente das regras; Claude Security sem achado grave aberto; nenhuma chave secreta no app; chaves de produção novas só no servidor; login da Apple nativo com nonce e sessão no Keychain; apagar a conta funcionando com o login revogado; assinatura conferida no servidor; só o app verdadeiro fala com o servidor e limites ligados; alerta e teto de gasto testados; conexão segura obrigatória; cópias do banco e restauração testada; nada pessoal em registros e relatórios de travamento; política, etiquetas e manifesto de privacidade; verificação em duas etapas nas contas; main protegido e decisão sobre o repositório privado; alertas do Dependabot e varredura de segredos ligados; plano de incidente; teste manual com duas contas.
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
- Antes do lançamento, o dono decide se o repositório continua público ou vira privado. Se virar privado, os minutos de macOS do CI passam a ser cobrados, e o CI em paralelo usa mais minutos no total do que um CI numa máquina só. Rever o CI antes de mudar, comparando na hora o CI pago do GitHub com menos runs, o Xcode Cloud (25 h por mês com a conta de desenvolvedor) e um Mac próprio.

### Depois do lançamento
- M11 — Importar a ficha de treino por foto.
- M12 — Apple Watch.
- M13 — Strava.
- Projeto Android, com a mesma conta e a mesma sincronização (e a assinatura valendo nos dois).

Fora do plano: desafios entre amigos e feed social. Ideias avaliadas e não escolhidas: exercício reserva, repetições por lado, mapa de recuperação, fotos de progresso, rodízio A/B/C e instruções de execução dos exercícios.

## Acabamentos

Detalhes pequenos achados no caminho ficam aqui e não viram etapa sozinhos: cada um entra junto da próxima etapa que mexe naquela tela, com a aprovação do dono, como o resto do escopo.

- Testes: `SessionUITests.testStartCheckMinimizeContinueAndFinish` falha quando atravessa a meia-noite do simulador (UTC no CI): o treino começa num dia e termina no outro, e o Início mostra o dia novo, "Descanso hoje" (run 46082603203, das 23:59:15 às 00:00:34). Fixar o "hoje" do teste, como o `-ui-today` faz no detalhe do exercício (achado na lista base).
- Testes: em `HomeWeekUITests.testMarkAndUnmarkToday`, o toque fora da pergunta "Desmarcar este dia?" (ajudante `cancelDialog`) pode se perder numa máquina lenta, e a pergunta não fecha (run 46103823321, parte 2); repetir o toque uma vez quando a pergunta continua na tela, como nos toques perdidos das abas (achado na lista base).
- Tela do treino: deslizar uma série para apagar (com Desfazer) ou para copiar.
- Tela do treino: com "Manter a tela ligada", a tela pode apagar depois de 1 hora sem série marcada, o mesmo tempo do treino esquecido; hoje ela nunca apaga com um treino esquecido aberto (decisão do dono).
- Tela do treino: desmarcar a série que começou o descanso atual encerra esse descanso, com a barra e o aviso; hoje eles continuam correndo (decisão do dono).
- "Escolher treino" e Programação semanal: um treino com muitos grupos fica cortado com "…". Mostrar no máximo alguns grupos e "+N"; os detalhes se decidem quando a tela for mexida.
- Início: o ponto do dia programado fica branco dentro das abas, e na referência 42 ele é azul. O `Color.accentColor` segue o tint, que nas abas é o branco da aba escolhida; o ponto passa a usar o `Theme.Colors.accent`. Conferir também o arco do anel da semana, que deve ter o mesmo problema (achado na etapa Detalhe do exercício).
- Botão principal desligado nas telas de antes da S4-C: o `SheetButton` primário das folhas de antes (por exemplo, "Salvar" do editor das métricas com o campo vazio) fica com opacidade 0,4 e o estilo `.plain`, que escurece o texto de novo e o deixa quase invisível (o "Adicionar" do seletor e as folhas novas já passaram ao `PrototypeButtonStyle` na lista base; nas folhas de antes, basta `usesPrototypeStyle: true` no `SheetButton`). No protótipo, o botão branco inteiro fica a 35 % (`button:disabled { opacity: .35 }`), com o texto preto legível; o `PrototypeButtonStyle`, usado no formulário do exercício próprio e no "Restaurar" desde a S4-C, faz isso (achado do dono na S4-C).
- Medidas acima de 1 pt contra o protótipo, achadas na etapa Visual novo (screenshots do CI contra as referências do workflow "Referências do protótipo"). Parte delas vem de dados de exemplo diferentes entre o protótipo e os testes: na hora de corrigir, comparar com os mesmos dados.
  - Início (screenshots 1, 22, 30, 38, 42, 50, 52, 53, 55 e 93): os cartões do resumo rápido estão 1,7 pt mais baixos que no protótipo (98,3 × 100). Nos estados "Descanso hoje", "Em andamento" e "Nada programado" (31, 32, 51, 54 e 83), o cartão da semana e o que vem abaixo ficam de 2,3 a 3,7 pt mais acima, porque o link "Programar semana" ocupa menos altura que no protótipo.
  - Treinos (2, 11, 26, 56, 57 e 58): cada cartão da grade de treinos está 2,7 pt mais alto (143,7 × 141), e a segunda linha da grade desce de 3 a 4,3 pt; o cartão "Nenhum treino ainda" e a linha da Programação semanal ficam 1,3 pt abaixo.
  - Programação semanal (41, 89 e 90): o cartão da meta da semana está 1,7 pt mais alto (72,7 × 71), e os dias abaixo dele descem de 1,3 a 1,7 pt.
  - Editor do treino (75, 78, 95 e 106): cada linha de série fica cerca de 0,3 pt mais baixa (−1,3 pt no fim da tela ou do segundo cartão); ao ordenar, de −1,3 a −2,0 pt; um nome longo quebra uma palavra antes, porque o app reserva mais espaço para o ⋯ que o protótipo.
  - Seletor de exercícios (77): a barra de cima ("Cancelar" e o título) está 4,3 pt mais alta.
  - Treino em andamento (25, 63 a 69, 80, 91, 92, 98 a 102 e 107): cada linha de série fica cerca de 0,3 pt mais baixa (−1,3 pt a partir do segundo cartão).
  - Folha "Avisar quando o descanso acabar?" (97): a tela bloqueada de exemplo tem a data em 13 e a hora em 52 (no protótipo, 12 e 46), e o conteúdo fica de 1,3 a 2,7 pt fora de lugar.
  - Detalhe do exercício (108 a 112, 127 e 128), medidas de novo na lista base (run 46092177996): tudo a até 1 pt do protótipo. Os textos de 11 pt, os nomes da legenda e os de 12 pt em duas linhas usam a linha do WebKit (`webKitLine`). Fica:
    - no Graviton (109), a frase "Mais kg = mais ajuda. Menos kg é progresso." quebra antes do "é", porque o iOS evita uma palavra sozinha na última linha; a altura é a mesma (aceito pelo dono).
  - Exercícios próprios (120 a 125), achadas na S4-C (a linha dos textos de 12 pt em duas linhas foi acertada na lista base):
    - folha dos músculos (120): no protótipo os chips aparecem com letra de uns 13,6 px, embora o CSS diga 13 px; no app (13 pt, como o CSS) cabem mais chips por linha, a folha tem uma linha de chips a menos e começa mais abaixo, e "Concluir" fica 15 pt mais abaixo. Decisão do dono na S4-C: fica 13 pt, como o CSS; a diferença vem do desenho da SF Pro no WebKit do Mac, sem o tracking do iOS, e não do tamanho;
    - exercício próprio de nome longo (123 e 124): o título em duas linhas (aceito pelo dono) desce o resto de 2,3 a 4 pt (medido de novo na lista base); em Meus (125) e em 71, o nome longo quebra em duas linhas no app (regra do app) e termina em "…" no protótipo.

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
- App do Apple Watch e conexão com o Strava: o dono quer os dois; quando entram no plano fica para decidir depois (dono, 26/11).
- O dono liga a verificação em duas etapas no GitHub, no Apple ID e no Apple Developer (e no painel do servidor quando existir), e liga no GitHub os alertas do Dependabot e a varredura de segredos genéricos (o ambiente do Claude não pode mudar configurações do repositório).
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
- Conta obrigatória com Entrar com a Apple, com os dados na nuvem e sincronização entre aparelhos antes do lançamento (decisão do dono, 23/11).
- Assinatura pela App Store presa à conta, com 30 dias grátis e "Restaurar compras"; a primeira abertura termina na tela do teste grátis, sem pular.
- Sem assinatura, o histórico, os recordes e a exportação ficam só para ler.
- O banco usa a proteção de arquivo padrão do iOS (protegido até o primeiro desbloqueio depois de ligar o iPhone), porque a M1 grava séries com o iPhone bloqueado.
- Sem assinatura, o histórico, os recordes e a exportação continuam liberados, só para ler; registrar treinos novos pede a assinatura. Os dados nunca são apagados.
- Sem calculadora de anilhas.
- Remover um exercício próprio (decisão 1A): com histórico, ou se estiver no treino em andamento, ele é arquivado; sem histórico, é apagado; nos dois casos, sai de todos os treinos planejados em que está, e a confirmação mostra esses treinos. O histórico continua com o nome do dia, e restaurar não o devolve aos treinos.
- Revisões: em cada etapa, o /code-review e as conferências olham só o que mudou. O app inteiro é revisado só em dois momentos, antes do TestFlight e antes do lançamento.
- O app pede o iOS 26.0 ou mais novo (app e alvos de teste): ele só é testado e medido no iOS 26.
- Nomes dos exercícios no padrão do Hevy, com o equipamento entre parênteses (os de peso do corpo ficam sem parênteses). Exceções aprovadas: a pegada ou a máquina entre parênteses quando é isso que diferencia (por exemplo, "Barra Fixa (Pegada Aberta)" e "Barra Fixa (Graviton)"), e nomes conhecidos sem parênteses (por exemplo, "Kettlebell Swing"). Cada exercício fica no grupo do músculo que ele mais trabalha.
- O openGym (licença AGPL) serve só de fonte de ideias: nenhum código nem dado dele é copiado.
- Lista base (26/11): um exercício base por nome; o equipamento e a pegada ou variação são escolhidos nas filas do detalhe e na folha de escolha; cada combinação tem histórico, evolução e recordes próprios (resposta 1A do dono). As variações que saíram da lista e tinham histórico (ou estavam num treino) viram exercícios próprios em "Meus", com o histórico.
- Exercício próprio (26/11, resposta 1A): um grupo principal (onde ele aparece no filtro da lista) e vários músculos principais e secundários; não há vários grupos.
- Cardio na meta da semana (26/11): é uma escolha da pessoa nos Ajustes, e começa desligada (resposta 1A).
- Protótipo com etapas futuras (27/11): o botão escondido [data-act="proto-app"] ("Só o app") esconde os desenhos de etapas futuras que mudam telas já construídas; o workflow "Referências do protótipo" toca nele antes de cada referência. A cada etapa construída, o Claude do chat tira dali o que ela fez.
- Plano de segurança antes do lançamento (27/11), com as 12 regras permanentes no PROJECT_RULES (seção 15, Segurança permanente).
- Respostas ao relatório da lista base (28/11): "Criar treino novo" pelo detalhe aberto no treino em andamento cria o treino e mostra o aviso, sem sair do treino (1A); na junção cuja combinação está escondida, o exercício que sairia vira um exercício próprio, em Meus, com o histórico, como os 105 que saem (2B); a biblioteca guarda a versão conferida e as aberturas normais só conferem a versão e a contagem, com a conferência completa quando a versão muda ou quando um exercício próprio é criado, renomeado, arquivado, restaurado ou apagado (3A); as folhas ficam a 96 % e as perguntas "Descartar exercício?" e "Descartar treino?" no meio da tela, como o iOS 26 desenha, e o protótipo é atualizado depois do merge (4A).
