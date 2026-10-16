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
- Timer de descanso.
- RPE/RIR e notas.
- Superséries e bi-sets.
- Remover série ou exercício durante o treino.
- Mostrar a carga e as repetições da última vez.

### S7 — Ajustes
- Unidades, idioma, tema e notificações.
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

## Decisões

- Sem recursos sociais no início: "Privacidade e social" fica fora até nova decisão.
- O repositório é público para o CI rodar sem custo. Nunca colocar senhas, chaves ou dados pessoais nele.
- Secret Protection e Push protection estão ligados no GitHub.
- Identidade visual: preto, branco, cinza e azul-escuro.
- Toda etapa que mudar o banco de dados cria uma nova versão do schema, com teste de migração.
