import SwiftData
import SwiftUI

/// The app's main navigation: five tabs.
///
/// While a session is in progress, every tab shows the "Treino em andamento" bar above the tab
/// bar, and the session screen opens over the tabs.
struct RootView: View {
    @Query(SessionService.activeSessionsDescriptor) private var activeSessions: [Session]
    @State private var isSessionOpen = false

    var body: some View {
        // Normally at most one; should there be more, the most recent is shown first.
        let currentSession = activeSessions.first

        TabView {
            Tab("Início", systemImage: "house") {
                NavigationStack {
                    HomeView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.home.root")
                        .navigationTitle("Início")
                }
                .activeSessionBar(currentSession, open: openSession)
            }

            Tab("Treinos", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    WorkoutListView(openSession: openSession)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.workouts.root")
                        .navigationTitle("Treinos")
                }
                .activeSessionBar(currentSession, open: openSession)
            }

            Tab("Exercícios", systemImage: "dumbbell") {
                NavigationStack {
                    ExerciseListView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.exercises.root")
                        .navigationTitle("Exercícios")
                }
                .activeSessionBar(currentSession, open: openSession)
            }

            Tab("Histórico", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    HistoryView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.history.root")
                        .navigationTitle("Histórico")
                }
                .activeSessionBar(currentSession, open: openSession)
            }

            Tab("Ajustes", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.settings.root")
                        .navigationTitle("Ajustes")
                }
                .activeSessionBar(currentSession, open: openSession)
            }
        }
        .fullScreenCover(isPresented: $isSessionOpen) {
            if let currentSession {
                SessionView(session: currentSession) {
                    isSessionOpen = false
                }
                .id(currentSession.id)
            }
        }
        .onChange(of: currentSession == nil) { _, hasNoSession in
            if hasNoSession {
                isSessionOpen = false
            }
        }
    }

    private func openSession() {
        isSessionOpen = true
    }
}

private extension View {
    /// The "Treino em andamento" bar above the tab bar, while `session` is in progress.
    func activeSessionBar(_ session: Session?, open: @escaping @MainActor () -> Void) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if let session {
                ActiveSessionBar(session: session, onOpen: open)
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
