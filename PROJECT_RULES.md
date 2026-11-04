# PROJECT RULES — NATIVE iPHONE APP

## 1. PROJECT PURPOSE

This project is a native iPhone application.

The application is being developed specifically for Apple's iOS platform and will be built, compiled, tested and distributed using Xcode.

The official implementation must use:

- Swift
- SwiftUI
- Xcode
- Native iOS frameworks and APIs whenever appropriate
- GitHub for version control

This is NOT a web application.

Do NOT design or implement the application as a website, web app, PWA or cross-platform web project.

Do NOT use web technologies as the foundation of the application.

The final product is a native iPhone application.

The code produced for this project must be intended to be opened, compiled, tested and maintained directly in Xcode.

Cloud Code is being used as the development/coding environment, but the final codebase is an Xcode project written in Swift and SwiftUI.

The application should be built as a real production-oriented product, not merely as a prototype or demonstration.

The codebase must remain modular, maintainable, scalable, reliable and easy to understand.

---

## 2. NATIVE iOS DEVELOPMENT

All architectural and implementation decisions must consider that this application will run natively on iPhone.

Prefer Apple's native technologies and frameworks whenever appropriate.

Use Swift and SwiftUI as the primary development technologies.

Code must be structured for:

- Xcode builds;
- iPhone Simulator;
- physical iPhone testing;
- Apple's native iOS APIs;
- App Store distribution requirements.

Do not optimize the project for Android, web or other platforms unless explicitly requested.

Do not introduce unnecessary abstractions or dependencies merely to support other platforms.

The application must behave and feel like a proper native iPhone application.

---

## 3. CORE DEVELOPMENT PRINCIPLE

This project must prioritize:

1. Correctness
2. Performance
3. Reliability
4. Maintainability
5. Simplicity
6. Excellent user experience

The application should feel fast, responsive, fluid and polished.

Performance is a first-class requirement, not an optional optimization to be addressed later.

Always prefer:

- simple solutions;
- efficient implementations;
- clear architecture;
- minimal necessary code;
- fast response times;
- low unnecessary memory usage;
- low unnecessary CPU usage;
- reliable behavior;
- maintainability;
- scalability.

Do not add complexity unless it provides a real and justified benefit.

The goal is not to have the fewest possible lines of code.

The goal is:

"Use the simplest and most efficient implementation that correctly solves the problem while maintaining excellent performance, reliability, security and maintainability."

The application should not merely work.

It should feel very good to use.

---

## 4. INSPECT BEFORE MODIFYING

Before modifying existing code:

1. Inspect the relevant project structure.
2. Identify the files, models, views, services and components related to the task.
3. Understand the current implementation and behavior.
4. Identify dependencies and possible side effects.
5. Reuse existing components and logic whenever appropriate.
6. Do not duplicate functionality that already exists.
7. Do not assume how the existing code works without inspecting it.

Never modify code based only on assumptions.

---

## 5. SCOPE CONTROL

Only implement the functionality explicitly approved for the current task.

Do NOT make unrelated:

- refactors;
- redesigns;
- renamings;
- reorganizations;
- architecture changes;
- performance changes;
- dependency changes;
- UI changes.

If an unrelated improvement is discovered:

1. Do not implement it automatically.
2. Report it as a separate suggestion.
3. Wait for explicit approval.

Never turn a small bug fix into an unrelated refactoring.

---

## 6. APPROVAL BEFORE CODE CHANGES

Before modifying, creating, deleting, moving or refactoring code, explain:

- what will be changed;
- which files will be affected;
- why the change is necessary;
- how the change will work;
- which existing functionality could be affected;
- how unrelated functionality will be protected;
- what tests will be performed.

Then STOP and wait for explicit approval.

Do not modify the code before approval.

---

## 7. PERFORMANCE AND OPTIMIZATION

Performance is extremely important for this project.

The application should be as fast, responsive and efficient as reasonably possible.

Always consider performance during implementation, not only after the feature is finished.

Avoid:

- unnecessary code;
- unnecessary calculations;
- unnecessary state;
- unnecessary state updates;
- unnecessary view recomputation;
- unnecessary rendering;
- unnecessary object creation;
- unnecessary memory usage;
- unnecessary CPU usage;
- unnecessary database operations;
- unnecessary network requests;
- unnecessary disk operations;
- unnecessary dependencies;
- duplicated processing;
- blocking the main thread;
- inefficient loops or data processing;
- avoidable delays;
- unnecessary animations or expensive visual effects.

Prefer efficient native Swift and SwiftUI solutions whenever appropriate.

Keep expensive operations away from the main UI thread when necessary.

Use lazy loading, caching, batching, memoization, asynchronous processing or other optimization techniques when they provide a real performance benefit and do not unnecessarily complicate the architecture.

Do not sacrifice correctness, reliability, security or maintainability merely to reduce code size.

Do not introduce premature optimizations without a reasonable technical justification.

After implementation, review the affected code for avoidable performance problems.

Consider:

- app startup performance;
- screen transition performance;
- scrolling performance;
- UI responsiveness;
- memory usage;
- CPU usage;
- database/query efficiency;
- network efficiency;
- battery impact;
- rendering performance.

The objective is not simply for the application to work.

The objective is for the application to feel fast, fluid and highly responsive during real-world iPhone use.

---

## 8. DATA AND ARCHITECTURE

Keep responsibilities clearly separated.

Where appropriate, separate:

- UI;
- models;
- business logic;
- persistence;
- services;
- networking;
- external integrations.

Keep planned workout data separate from performed workout/session data.

Historical data must not be accidentally deleted when modifying or deleting current/planned data.

Use stable unique identifiers and explicit relationships between entities.

Architecture should remain suitable for future Firebase integration.

---

## 9. USER EXPERIENCE

Every screen follows `DESIGN.md` and the approved prototype.

The application should prioritize:

- simplicity;
- speed;
- clarity;
- intuitive navigation;
- minimal unnecessary interactions.

Always consider:

- loading states;
- empty states;
- error states;
- success feedback;
- confirmation for destructive actions;
- invalid input;
- interrupted flows;
- offline/connection problems when relevant.

Do not add UI elements simply because they are common in other applications.

Every element should have a clear purpose.

The user should be able to perform common workout actions quickly, especially during an active workout.

---

## 10. ERROR HANDLING

Do not silently ignore errors.

Errors should:

- be detected;
- be handled appropriately;
- provide useful feedback when relevant;
- avoid crashing the application;
- preserve existing valid data whenever possible.

Do not hide problems simply to make a test appear successful.

---

## 11. TESTING REQUIREMENTS

After every implementation, test all relevant functionality.

At minimum, verify:

- navigation;
- creation;
- editing;
- deletion;
- persistence;
- loading states;
- empty states;
- error states;
- data relationships;
- integrations;
- edge cases;
- invalid input;
- interrupted flows;
- affected existing functionality.

Test the complete user flow, not only the individual code component.

Compilation alone does NOT mean the task is complete.

---

## 12. REGRESSION PREVENTION

Before considering a task complete:

1. Verify the new functionality.
2. Verify the existing functionality directly affected by the change.
3. Check for regressions.
4. Review the modified code.
5. Resolve relevant warnings and errors.
6. Re-run the relevant tests after fixes.

Never assume that fixing one problem cannot affect another feature.

---

## 13. GIT AND VERSION CONTROL

Keep the project version-controlled with GitHub.

Use clear commits for meaningful completed changes.

Do not intentionally leave the repository in a broken state after completing a task.

Keep the project history understandable.

---

## 14. DEPENDENCIES

Avoid unnecessary third-party dependencies.

Before adding a dependency:

- determine whether native Swift/SwiftUI functionality can solve the problem;
- determine whether an existing project dependency already provides the functionality;
- consider maintenance and long-term compatibility.

Only add dependencies when there is a clear benefit.

---

## 15. SECURITY AND PRIVACY

Never hardcode:

- passwords;
- API keys;
- private tokens;
- secrets;
- credentials.

Protect user data appropriately.

Do not expose private user information.

Follow Apple's security and privacy best practices.

---

## 16. FUTURE MIGRATION AND MAINTAINABILITY

The project must remain easy to maintain and evolve.

Avoid unnecessary coupling between components.

Prefer reusable and clearly defined components.

Keep business logic independent from specific UI implementations whenever practical.

The application may later integrate with:

- Firebase;
- StoreKit;
- App Store services;
- additional native iOS functionality.

Do not create unnecessary dependencies on development tools or temporary environments.

---

## 17. COMPLETION STANDARD

A task is complete only when:

- the approved functionality has been implemented;
- the relevant code has been reviewed;
- unnecessary code has been removed;
- relevant errors have been addressed;
- the affected flows have been tested;
- existing functionality has been checked for regressions;
- no known critical issue remains.

Never report a task as complete simply because the code was written or compiled.

---

## 18. Decisões pequenas sem pedir aprovação

Depois que o plano da etapa foi aprovado, o Claude Code pode decidir sozinho, sem parar para perguntar:

- corrigir testes que quebraram por causa das mudanças da própria etapa;
- corrigir bugs que o /code-review achar no código do próprio PR, desde que a correção não mude o design nem a funcionalidade aprovados;
- organizar o código dos arquivos que a etapa já altera, sem mudar o comportamento do app;
- mudar números dos screenshots, comentários e nomes internos;
- rodar o CI de novo quando o GitHub cancelar por falta de máquina.

Continua obrigatório parar e pedir aprovação para:

- qualquer mudança de design (visual, medidas, cores, textos, telas) ou de funcionalidade (o que o app faz) que não esteja exatamente no protótipo aprovado e no prompt da etapa. Se o protótipo e o código divergirem, pergunte;
- banco de dados, migrações ou apagar dados;
- dependências novas, custos, permissões do iPhone e segurança;
- mudanças no CI e nas configurações do repositório;
- aumentar o escopo da etapa;
- merge, sempre.

Todo relatório final tem a parte "O que decidi sozinho", com cada uma dessas decisões.

---

## 19. Como trabalhamos neste projeto

Etapas e Git
- Uma etapa por vez: uma branch e um PR por etapa, com commit e push a cada parte.
- Plano primeiro; merge só com a aprovação do dono.
- Nunca force-push, reescrever o histórico ou apagar branches com trabalho não integrado.

Repositório público
- Nunca colocar senhas, chaves, tokens, dados pessoais ou e-mail pessoal no código, nos commits, nos screenshots ou nos relatórios.
- Os commits usam o e-mail noreply do GitHub.

CI e testes
- Se o CI falhar, descobrir a causa antes de rodar de novo. Só repetir sem correção quando a falha não for do código (por exemplo, o GitHub cancelou por falta de máquina).
- Teste instável se corrige; nunca se desliga um teste para o CI passar.

Revisões
- O /code-review roda uma vez no fim de cada PR e olha só o que o PR mudou.
- O app inteiro é revisado só em dois momentos: antes do TestFlight e antes do lançamento.

Protótipo e medidas
- 1 px do protótipo = 1 pt no app, no texto padrão.
- Comparar os screenshots com o protótipo no mesmo tamanho, com o protótipo começando no fim da área segura e renderizado com a mesma Inter do app.
- Diferença aceitável: até 1 pt.

Relatório final de cada etapa
- O que foi feito, com os commits.
- Resultado do CI, com o link do run.
- Screenshots novos e que mudaram.
- Achados do /code-review e o que foi feito com cada um.
- "O que decidi sozinho" (seção 18).
- "Para o dono decidir": cada divergência entre o protótipo e o código, sem mudar nada antes da resposta.
