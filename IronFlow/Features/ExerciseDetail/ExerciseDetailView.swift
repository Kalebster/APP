import SwiftData
import SwiftUI

/// The exercise screen, as in the approved prototype: the name, "grupo · equipamento", the muscles on the
/// body figure, the kind of machine, and the person's history with the exercise (the last time, the best
/// set, the evolution chart and the sessions). Read-only.
///
/// It opens from a row of the Exercícios tab (the tab bar stays, with Exercícios chosen) and from
/// "Ver exercício" in the ⋯ of an exercise in the workout editor or in the session (without the tab bar,
/// "‹" with the workout's name). The history is read once when the screen opens; the session in
/// progress never counts.
struct ExerciseDetailView: View {
    /// Where the screen was opened from: the back button and the tab bar follow it.
    enum Origin: Hashable {
        case exercises
        /// The workout editor or the session, with the workout's name.
        case workout(name: String)
    }

    let exercise: Exercise
    let origin: Origin

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// `nil` until read.
    @State private var history: ExerciseHistory?
    /// "Today" for the periods of the chart, taken when the screen opens.
    @State private var today = ExerciseDetailToday.current()
    @State private var isShowingMachineTypes = false
    /// The session of a history card, opened in its detail.
    @State private var openedSession: Session?
    @State private var errorMessage: String?

    var body: some View {
        let muscles = DefaultExerciseMuscles.muscles(of: exercise)
        let machine = DefaultExerciseMuscles.machine(of: exercise)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ExerciseDetailTitle(name: exercise.name, detail: detailText)
                    // 52 below the top of the screen, as in the prototype: 4 below the 44-point top row.
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle("Músculos")
                    ExerciseMusclesCard(
                        primary: muscles.primary,
                        secondary: muscles.secondary,
                        focus: focus,
                        isCustom: exercise.isCustom
                    )
                    if let machine {
                        MachineTypeRow(machine: machine) {
                            isShowingMachineTypes = true
                        }
                    }
                }

                if let history {
                    if history.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle("Evolução")
                            ExerciseNeverDoneCard()
                        }
                    } else {
                        ExerciseEvolutionSection(history: history, today: today, calendar: TrainingDay.calendar)
                        ExerciseHistorySection(history: history, today: today, calendar: TrainingDay.calendar, onOpen: openSession)
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                TextBackButton(verbatim: backTitle) {
                    dismiss()
                }
                .accessibilityIdentifier("exercise.back")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            // The prototype's 8 above its 36-point top row, with the 44-point back button centered on it.
            .padding(.top, 4)
            .background(Theme.Colors.screenBackground)
        }
        .screenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exercise.screen")
        // The navigation bar is hidden for the prototype's own top row; the swipe back stays. The name is the
        // title the session detail's back button shows.
        .navigationTitle(exercise.name)
        .background(InteractivePopEnabler())
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(origin == .exercises ? .automatic : .hidden, for: .tabBar)
        .task(id: exercise.id) {
            loadHistory()
        }
        .sheet(isPresented: $isShowingMachineTypes) {
            MachineTypesSheet(current: machine)
        }
        .navigationDestination(item: $openedSession) { session in
            HistorySessionDetailView(detail: HistorySessionDetail(session))
        }
        .errorAlert($errorMessage)
    }

    private var backTitle: String {
        switch origin {
        case .exercises: String(localized: "Exercícios")
        case .workout(let name): name
        }
    }

    /// "Peito · Barra"; for an exercise of the user's own, "Peito · Meu exercício".
    private var detailText: String {
        let group = String(localized: exercise.muscleGroup.displayName)
        if exercise.isCustom {
            return String(localized: "\(group) · Meu exercício")
        }
        guard let equipment = exercise.libraryKey.flatMap({ DefaultExerciseLibrary.byKey[$0] })?.equipment else { return group }
        return "\(group) · \(String(localized: equipment.displayName))"
    }

    private var focus: String? {
        guard !exercise.isCustom, let key = exercise.libraryKey else { return nil }
        return DefaultExerciseLibrary.byKey[key]?.focus
    }

    private func loadHistory() {
        do {
            history = try ExerciseHistoryLoader(context: context).history(of: exercise)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func openSession(_ id: UUID) {
        do {
            openedSession = try ExerciseHistoryLoader(context: context).session(id: id)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
