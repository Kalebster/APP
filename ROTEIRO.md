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

## Próximas etapas

### S4-B — Tela Exercícios
- Exercícios: lista única com filtros por grupo muscular, botão "+ Novo" para exercício próprio (a lógica já existe no ExerciseService) e equipamento de cada exercício (Barra, Halteres, Máquina, Peso do corpo...).
- Reorganizar o Início para o Resumo rápido não ficar escondido.

### S5 — Histórico completo
- Filtro por período: 7, 30 e 90 dias, e tudo.
- Totais: treinos, tempo, volume e recordes.
- Volume e recordes em cada treino da lista.
- Calendário com os dias treinados.
- Recordes recentes e gráficos de evolução.
- Apagar ou corrigir um treino concluído.

### S6 — Durante o treino
- Timer de descanso (feito no PR #23).
- RPE/RIR e notas.
- Superséries e bi-sets.
- Remover série ou exercício durante o treino (feito no PR #23).
- Mostrar a carga e as repetições da última vez (feito no PR #23).

### S7 — Ajustes
- Unidades, idioma e notificações.
- Preferências de treino.

### S8 — Conta
- Login e sincronização com Firebase.

### S9 — Assinatura
- Assinatura pela App Store (StoreKit) e "Gerenciar assinatura".

### S10 — Revisão final e TestFlight
- Regressão completa, uso offline, acessibilidade e desempenho.
- Build Release, tamanho do app e envio ao TestFlight.
- Ícone do app.
- Mensagem amigável na tela de erro ao abrir os dados.

## Pendências da vistoria

- Medir com dados reais o custo da busca do Histórico durante um treino (a lista pode buscar de novo todas as sessões concluídas a cada série salva).
- Nomes de treino repetidos ficam ambíguos no VoiceOver ("Opções de Push") e no menu de iniciar.
- Quem digita "12,500" querendo 12,5 kg recebe a mensagem sobre mil quilos; rever a mensagem.
- O banco é aberto de forma síncrona ao iniciar o app; uma migração num banco grande atrasaria a abertura.
- Após uma falha ao salvar, o rollback() do SwiftData não restaura os valores alterados nos objetos em memória. O banco fica correto e o erro é mostrado, mas a tela pode exibir o valor não salvo até o objeto ser lido de novo. Raro (ex.: disco cheio). Prioridade baixa: resolver antes da S10. Coberto por teste com withKnownIssue.
- Com o maior tamanho de texto (acessibilidade), a barra "Treino em andamento", mostrada com o treino minimizado, chega a 438 pt de altura e quebra "Treino em andamento" numa coluna estreita (89 pt). Rever o layout dela numa etapa futura (visto no PR #23).

## Decisões

- Sem recursos sociais no início: "Privacidade e social" fica fora até nova decisão.
- O repositório é público para o CI rodar sem custo. Nunca colocar senhas, chaves ou dados pessoais nele.
- Secret Protection e Push protection estão ligados no GitHub.
- Identidade visual: preto, branco, cinza e azul-escuro.
- O app é somente escuro: não há tema claro nem opção de tema nos Ajustes.
- Cada tela é construída a partir de um modelo visual aprovado pelo dono antes.
- Toda etapa que mudar o banco de dados cria uma nova versão do schema, com teste de migração.
- Os 6 commits iniciais com e-mail pessoal ficam como estão; commits novos usam o e-mail noreply do GitHub.
