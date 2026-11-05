import SwiftData
import SwiftUI
import UIKit

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
    /// The rest between sets of the session in progress and its notice. Kept here, so it goes on while
    /// the session screen is minimized; its end time is kept in the preferences, never in the store.
    @State private var rest = RestController(
        settings: SessionSettings(store: AppPreferences.store),
        center: RestAlertCenterFactory.make(),
        store: AppPreferences.store
    )
    @Environment(\.scenePhase) private var scenePhase
    /// Rests that reached zero while the session screen was not open, for the vibration.
    @State private var restsEndedElsewhere = 0
    /// The notices over every tab, and the root's errors, its own and those of screens that already closed.
    @State private var feedback = RootFeedback()
    /// Changed to show the Início from its top, with nothing open over it.
    @State private var homeStackID = UUID()

    var body: some View {
        // Normally at most one; should there be more, the most recent is shown first.
        let currentSession = activeSessions.first
        @Bindable var feedback = feedback

        TabView(selection: $selectedTab) {
            Tab("Início", image: "tab-home", value: AppTab.home) {
                // No bar here: the "Treino de hoje" card offers "Continuar" instead.
                NavigationStack {
                    HomeView(sessionActions: sessionActions)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.home.root")
                        .navigationTitle("Início")
                }
                .id(homeStackID)
            }

            Tab("Treinos", image: "tab-workouts", value: AppTab.workouts) {
                NavigationStack {
                    WorkoutListView(sessionActions: sessionActions) {
                        selectedTab = .history
                    }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.workouts.root")
                        .navigationTitle("Treinos")
                }
                .activeSessionBar(currentSession, rest: rest) { openSession() }
            }

            Tab("Exercícios", image: "tab-exercises", value: AppTab.exercises) {
                NavigationStack {
                    ExerciseListView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.exercises.root")
                        .navigationTitle("Exercícios")
                }
                .activeSessionBar(currentSession, rest: rest) { openSession() }
            }

            Tab("Histórico", image: "tab-history", value: AppTab.history) {
                NavigationStack {
                    HistoryView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.history.root")
                        .navigationTitle("Histórico")
                }
                .activeSessionBar(currentSession, rest: rest) { openSession() }
            }

            Tab("Ajustes", image: "tab-settings", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.settings.root")
                        .navigationTitle("Ajustes")
                }
                .activeSessionBar(currentSession, rest: rest) { openSession() }
            }
        }
        .fullScreenCover(item: $openedSession) { session in
            SessionView(session: session, rest: rest, onFinish: showHomeAfterFinishing) {
                openedSession = nil
            }
        }
        // A session finished or discarded elsewhere is never left on screen, and its rest ends.
        .onChange(of: activeSessions.map(\.id)) { _, activeIDs in
            if let openedSession, !activeIDs.contains(openedSession.id) {
                self.openedSession = nil
            }
            rest.stopUnless(inProgress: activeIDs)
            updateIdleTimer()
        }
        // The end of the rest, wherever the app is: one wait until the end time, made again when it
        // changes. Nothing runs without a rest.
        .task(id: rest.timer.endsAt) {
            await endRestWhenOver()
        }
        // With the session screen closed, the end of the rest is a notice at the top, with a vibration.
        .onChange(of: rest.lastEnd) { _, end in
            guard let end, openedSession == nil, activeSessions.contains(where: { $0.id == end.sessionID }) else { return }
            restsEndedElsewhere += 1
            feedback.show(RestAlertText.notice(nextSet: end.nextSet))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: restsEndedElsewhere)
        .onChange(of: scenePhase, initial: true) { _, phase in
            // On screen, even inactive (Control Center, the iPhone's question): the end is shown there.
            rest.isOnScreen = phase != .background
            updateIdleTimer()
            if phase == .active {
                // A rest that ended while the app was away just goes; the permission may have changed in
                // the iPhone's Settings.
                rest.endIfOver(isActive: false)
                Task { await rest.refreshAuthorization() }
            }
        }
        .onChange(of: rest.settings.keepScreenOn) {
            updateIdleTimer()
        }
        .task {
            // The rest kept from before the app was closed: gone if its session is no longer in progress,
            // and just over if it ended meanwhile.
            rest.stopUnless(inProgress: activeSessions.map(\.id))
            rest.endIfOver(isActive: false)
            await rest.refreshAuthorization()
            updateIdleTimer()
        }
        .alert("Você já tem um treino em andamento.", isPresented: $isSessionInProgress) {
            Button("Continuar treino atual") {
                openSession()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Conclua ou descarte o treino atual antes de iniciar outro.")
        }
        .toast($feedback.toast)
        .errorAlert($feedback.errorMessage)
        .environment(feedback)
    }

    /// "Manter a tela ligada": the screen does not dim while a session is in progress and the app is on
    /// screen; otherwise it goes back to normal.
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = rest.settings.keepScreenOn && !activeSessions.isEmpty && scenePhase == .active
    }

    /// Waits until the rest's end and ends it, shown and felt when the app is on screen. Should the
    /// wait end a moment before the end time (a clock change), it waits the rest of the way.
    private func endRestWhenOver() async {
        guard let endsAt = rest.timer.endsAt else { return }
        while rest.timer.endsAt == endsAt, endsAt.timeIntervalSinceNow > 0 {
            do {
                try await Task.sleep(for: .seconds(endsAt.timeIntervalSinceNow))
            } catch {
                // Cancelled: the rest changed.
                return
            }
        }
        guard rest.timer.endsAt == endsAt else { return }
        rest.endIfOver(isActive: rest.isOnScreen)
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

    /// After a session is finished and saved: the Início, from its top, with "Concluído hoje" and the week
    /// updated, and the "Treino salvo" notice above. The weekly plan or a sheet left open there is closed.
    private func showHomeAfterFinishing() {
        homeStackID = UUID()
        selectedTab = .home
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
    func activeSessionBar(
        _ session: Session?,
        rest: RestController,
        open: @escaping @MainActor () -> Void
    ) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if let session {
                ActiveSessionBarHost(session: session, rest: rest, onOpen: open)
            }
        }
    }
}

/// Reads what the "Treino em andamento" bar shows of the session in progress: its sets done, and its
/// rest while one runs. A view of its own, so a set or a rest that changes draws only the bar again,
/// never the tabs. A session just discarded is never read: the bar goes before the list of sessions
/// in progress catches up.
private struct ActiveSessionBarHost: View {
    let session: Session
    let rest: RestController
    let onOpen: @MainActor () -> Void

    var body: some View {
        if !session.isDeleted, session.modelContext != nil {
            ActiveSessionBar(
                status: ActiveSessionBar.Status(
                    name: SessionFormatting.name(session.workoutNameSnapshot),
                    startedAt: session.startedAt,
                    setsText: SessionProgress(sets: session.orderedExercises.map(\.orderedSetLogs)).setsText,
                    restEndsAt: rest.timer.isRunning(for: session.id) ? rest.timer.endsAt : nil
                ),
                onOpen: onOpen
            )
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
