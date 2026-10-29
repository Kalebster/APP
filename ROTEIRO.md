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

## Próximas etapas

### S4-C — Exercícios próprios
- Exercícios próprios: + Novo, detalhe do exercício, editar e arquivar, e equipamento dos exercícios próprios (precisa de modelo aprovado).

### S4-F — Descanso
Precisa de modelo aprovado.
- Aviso de fim do descanso por notificação, agendada quando o descanso começa e ajustada no −15, no +15 e no Pular; funciona com o celular bloqueado e com o app fechado.
- Opção de manter a tela ligada durante o treino.
- Tempo de descanso por exercício.

### S5 — Histórico completo
- Filtro por período: 7, 30 e 90 dias, e tudo.
- Totais: treinos, tempo, volume e recordes.
- Volume e recordes em cada treino da lista.
- Calendário com os dias treinados.
- Recordes recentes e gráficos de evolução.
- Apagar ou corrigir um treino concluído.
- Aviso de recorde na hora, durante o treino, e 1RM estimado.
- Desempenho com muitos dados: um teste que cria 3 anos de treinos e mede o Início, o Histórico e o ✓.
- As buscas do Histórico e da coluna ÚLTIMA leem só o necessário.

### S6 — Durante o treino
- Timer de descanso (feito no PR #23).
- RPE/RIR e notas.
- Superséries e bi-sets.
- Remover série ou exercício durante o treino (feito no PR #23).
- Mostrar a carga e as repetições da última vez (feito no PR #23).
- Sugestão de carga: subir a carga quando todas as séries válidas chegam ao topo da faixa de repetições.
- Descanso na tela bloqueada e na Dynamic Island (Live Activity).

### S7 — Ajustes
- Unidades, idioma e notificações.
- Preferências de treino.
- Apple Saúde: gravar o treino como treino de força e ler o peso.
- Exportar os dados em planilha (CSV).

### S10 — Revisão final e TestFlight
- Regressão completa, uso offline, acessibilidade e desempenho.
- Build Release, tamanho do app e envio ao TestFlight.
- Ícone do app.
- Mensagem amigável na tela de erro ao abrir os dados.
- Antes do lançamento, o dono decide se o repositório continua público ou vira privado.

### S8 — Conta
Depois da S10 (lançamento).
- Login e sincronização com Firebase.
- Lista de segurança obrigatória:
  - regras de segurança do Firebase: cada pessoa só lê e grava os próprios dados;
  - App Check e limites de uso, para que só o app fale com o servidor;
  - nenhuma chave de administrador no app, e o arquivo de configuração do Firebase fora do repositório público;
  - os dados também são validados no servidor;
  - campos protegidos que o app não pode alterar (por exemplo, a assinatura);
  - login com a Apple, sem guardar senhas;
  - apagar a conta dentro do app;
  - alertas de dependências do GitHub ligados quando entrar o SDK do Firebase;
  - política de privacidade e relatório de privacidade atualizados.

### S9 — Assinatura
Depois da S10 (lançamento).
- Assinatura pela App Store (StoreKit) e "Gerenciar assinatura".

## Pendências da vistoria

- Medir com dados reais o custo da busca do Histórico durante um treino (a lista pode buscar de novo todas as sessões concluídas a cada série salva).
- Nomes de treino repetidos ficam ambíguos no VoiceOver ("Opções de Push") e no menu de iniciar.
- O banco é aberto de forma síncrona ao iniciar o app; uma migração num banco grande atrasaria a abertura.
- Após uma falha ao salvar, o rollback() do SwiftData não restaura os valores alterados nos objetos em memória. O banco fica correto e o erro é mostrado, mas a tela pode exibir o valor não salvo até o objeto ser lido de novo. Raro (ex.: disco cheio). Prioridade baixa: resolver antes da S10. Coberto por teste com withKnownIssue.
- Com o maior tamanho de texto (acessibilidade), a barra "Treino em andamento", mostrada com o treino minimizado, chega a 438 pt de altura e quebra "Treino em andamento" numa coluna estreita (89 pt). Rever o layout dela numa etapa futura (visto no PR #23).
- HomeUITests.testEditSummaryValues falhou uma vez por um toque perdido durante animação (run 39884902708) e falhou de novo no CI da main em db5c717 (run 40437064904, digitação antes de o campo ficar ativo); corrigido no PR #27, que também deixa mais lento o arraste do WorkoutUITests.testReorderExercises.
- Os testes de interface já levam 38–46 min (58 testes); estudar como reduzir esse tempo antes que voltem a se aproximar do limite do CI.
- Proteger o main no GitHub com uma regra (bloquear apagar e reescrever o main e exigir PR). O dono fará isso quando tiver um computador, porque pelo ambiente do Claude a alteração é bloqueada.

## Decisões

- Sem recursos sociais no início: "Privacidade e social" fica fora até nova decisão.
- O repositório é público para o CI rodar sem custo. Nunca colocar senhas, chaves ou dados pessoais nele.
- Secret Protection e Push protection estão ligados no GitHub.
- Identidade visual: preto, branco, cinza e azul-escuro.
- O app é somente escuro: não há tema claro nem opção de tema nos Ajustes.
- Cada tela é construída a partir de um modelo visual aprovado pelo dono antes.
- Toda etapa que mudar o banco de dados cria uma nova versão do schema, com teste de migração.
- Os 6 commits iniciais com e-mail pessoal ficam como estão; commits novos usam o e-mail noreply do GitHub.
- Lançamento grátis, sem conta e sem assinatura. Depois de um tempo, o app passa a ser todo pago.
- Assinatura pela App Store, com o ID Apple, sem exigir conta no app (a Apple não permite exigir cadastro para assinar). Teste grátis de 14 dias para quem nunca assinou, dado pela própria App Store, e "Restaurar compras" para quem troca de aparelho.
- Sem assinatura, o app fica bloqueado, mas os dados nunca são apagados. Exportar os dados continua liberado.
- A conta é opcional e vem depois do lançamento. Ao criar a conta, os dados do aparelho são enviados para ela, nunca apagados.
- Sem calculadora de anilhas.
