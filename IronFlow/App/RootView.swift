import SwiftData
import SwiftUI

/// The app's main navigation: five tabs.
///
/// While a session is in progress, the tabs show the "Treino em andamento" bar above the tab bar
/// (except Início, whose "Treino de hoje" card offers "Continuar"), and the session screen opens
/// over the tabs. Sessions are started only here, through `SessionActions`.
struct RootView: View {
    /// The tabs, so a screen can open another one ("Ver tudo" in Treinos opens the Histórico).
    private enum AppTab: Hashable {
        case home, workouts, exercises, history, settings
    }

    @Query(SessionService.activeSessionsDescriptor) private var activeSessions: [Session]
    @Environment(\.modelContext) private var context
    @State private var selectedTab = AppTab.home
    /// The session shown over the tabs; `nil` while it is minimized or when none is in progress.
    @State private var openedSession: Session?
    @State private var isSessionInProgress = false
    /// The rest between sets of the session in progress. Kept here, so it goes on while the session
    /// screen is minimized; never stored.
    @State private var restTimer = RestTimer()
    /// The root's errors, its own and those of screens that already closed.
    @State private var feedback = RootFeedback()

    var body: some View {
        // Normally at most one; should there be more, the most recent is shown first.
        let currentSession = activeSessions.first
        @Bindable var feedback = feedback

        TabView(selection: $selectedTab) {
            Tab("Início", systemImage: "house", value: AppTab.home) {
                // No bar here: the "Treino de hoje" card offers "Continuar" instead.
                NavigationStack {
                    HomeView(sessionActions: sessionActions)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.home.root")
                        .navigationTitle("Início")
                }
            }

            Tab("Treinos", systemImage: "list.bullet.rectangle", value: AppTab.workouts) {
                NavigationStack {
                    WorkoutListView(sessionActions: sessionActions) {
                        selectedTab = .history
                    }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.workouts.root")
                        .navigationTitle("Treinos")
                }
                .activeSessionBar(currentSession) { openSession() }
            }

            Tab("Exercícios", systemImage: "dumbbell", value: AppTab.exercises) {
                NavigationStack {
                    ExerciseListView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.exercises.root")
                        .navigationTitle("Exercícios")
                }
                .activeSessionBar(currentSession) { openSession() }
            }

            Tab("Histórico", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                NavigationStack {
                    HistoryView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.history.root")
                        .navigationTitle("Histórico")
                }
                .activeSessionBar(currentSession) { openSession() }
            }

            Tab("Ajustes", systemImage: "gearshape", value: AppTab.settings) {
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
            SessionView(session: session, restTimer: $restTimer) {
                openedSession = nil
            }
        }
        // A session finished or discarded elsewhere is never left on screen, and its rest ends.
        .onChange(of: activeSessions.map(\.id)) { _, activeIDs in
            if let openedSession, !activeIDs.contains(openedSession.id) {
                self.openedSession = nil
            }
            if let restSessionID = restTimer.sessionID, !activeIDs.contains(restSessionID) {
                restTimer.stop()
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
        .errorAlert($feedback.errorMessage)
        .environment(feedback)
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
            feedback.errorMessage = UserFacingError.message(for: error)
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
