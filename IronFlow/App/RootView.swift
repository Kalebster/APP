import SwiftData
import SwiftUI

/// The app's main navigation: five tabs.
///
/// While a session is in progress, the tabs show the "Treino em andamento" bar above the tab bar
/// (except Início, whose "Treino de hoje" card offers "Continuar"), and the session screen opens
/// over the tabs. Sessions are started only here, through `SessionActions`.
struct RootView: View {
    @Query(SessionService.activeSessionsDescriptor) private var activeSessions: [Session]
    @Environment(\.modelContext) private var context
    /// The session shown over the tabs; `nil` while it is minimized or when none is in progress.
    @State private var openedSession: Session?
    @State private var isSessionInProgress = false
    @State private var errorMessage: String?

    var body: some View {
        // Normally at most one; should there be more, the most recent is shown first.
        let currentSession = activeSessions.first

        TabView {
            Tab("Início", systemImage: "house") {
                // No bar here: the "Treino de hoje" card offers "Continuar" instead.
                NavigationStack {
                    HomeView(sessionActions: sessionActions)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.home.root")
                        .navigationTitle("Início")
                }
            }

            Tab("Treinos", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    WorkoutListView(sessionActions: sessionActions)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.workouts.root")
                        .navigationTitle("Treinos")
                }
                .activeSessionBar(currentSession) { openSession() }
            }

            Tab("Exercícios", systemImage: "dumbbell") {
                NavigationStack {
                    ExerciseListView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.exercises.root")
                        .navigationTitle("Exercícios")
                }
                .activeSessionBar(currentSession) { openSession() }
            }

            Tab("Histórico", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    HistoryView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.history.root")
                        .navigationTitle("Histórico")
                }
                .activeSessionBar(currentSession) { openSession() }
            }

            Tab("Ajustes", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.settings.root")
                        .navigationTitle("Ajustes")
                }
                .activeSessionBar(currentSession) { openSession() }
            }
        }
        .fullScreenCover(item: $openedSession) { session in
            SessionView(session: session) {
                openedSession = nil
            }
        }
        // A session finished or discarded elsewhere is never left on screen.
        .onChange(of: activeSessions.map(\.id)) { _, activeIDs in
            if let openedSession, !activeIDs.contains(openedSession.id) {
                self.openedSession = nil
            }
        }
        .alert("Você já tem um treino em andamento.", isPresented: $isSessionInProgress) {
            Button("Continuar treino atual") {
                openSession()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Conclua ou descarte o treino atual antes de iniciar outro.")
        }
        .errorAlert($errorMessage)
    }

    private var sessionActions: SessionActions {
        SessionActions(
            start: { workout in
                startSession { try $0.startSession(from: workout) }
            },
            startFree: {
                startSession { try $0.startFreeSession() }
            },
            open: {
                openSession()
            }
        )
    }

    /// Opens `session` over the tabs, or else the session in progress; nothing happens when there is none.
    private func openSession(_ session: Session? = nil) {
        openedSession = session ?? activeSessions.first
    }

    /// Starts a session through `SessionService` and opens it. A session already in progress is
    /// offered instead of starting another; other problems are reported.
    private func startSession(_ start: (SessionService) throws -> Session) {
        // A second tap while the session screen opens starts nothing.
        guard openedSession == nil else { return }
        do {
            openedSession = try start(SessionService(context: context))
        } catch SessionError.activeSessionExists {
            isSessionInProgress = true
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

private extension View {
    /// The "Treino em andamento" bar above the tab bar, while `session` is in progress.
    func activeSessionBar(_ session: Session?, open: @escaping @MainActor () -> Void) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if let session {
                ActiveSessionBar(
                    name: SessionFormatting.name(session.workoutNameSnapshot),
                    startedAt: session.startedAt,
                    onOpen: open
                )
            }
        }
    }
}

#Preview {
    if let container = try? ModelContainerFactory.makeInMemory() {
        let _ = try? ExerciseLibrarySeeder(context: container.mainContext).seed()
        RootView()
            .modelContainer(container)
    }
}
