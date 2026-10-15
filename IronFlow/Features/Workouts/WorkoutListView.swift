import SwiftData
import SwiftUI

/// The Workouts tab: the weekly plan row and one card per planned workout. Creating a workout opens
/// its editor; "Iniciar" starts a session from it.
struct WorkoutListView: View {
    /// Starts a session from a workout ("Iniciar").
    let sessionActions: SessionActions

    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    /// The weekly plan: at most seven records, so all of them are read.
    @Query private var weeklyPlan: [WeeklyPlanDay]
    @Environment(\.modelContext) private var context
    @State private var isShowingPlan = false
    @State private var isCreating = false
    /// Workout created in the name sheet, opened once the sheet is dismissed.
    @State private var createdWorkout: Workout?
    @State private var openedWorkout: Workout?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Metrics.cardSpacing) {
                // Without workouts there is nothing to plan.
                if !workouts.isEmpty {
                    Button {
                        isShowingPlan = true
                    } label: {
                        WeeklyPlanRow(
                            summary: WeeklyPlanSummary.summaryText(
                                WeeklyPlanSummary.plannedDayCount(plan: weeklyPlan, workouts: workouts)
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workouts.plan")
                }

                ForEach(workouts) { workout in
                    WorkoutCard(workout: workout) {
                        openedWorkout = workout
                    } onStart: {
                        sessionActions.start(workout)
                    }
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .overlay {
            if workouts.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum treino ainda", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Seus treinos aparecerão aqui.")
                } actions: {
                    Button("Criar treino") {
                        isCreating = true
                    }
                    .accessibilityIdentifier("workouts.empty.create")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("workouts.empty")
            }
        }
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Label("Criar treino", systemImage: "plus")
                }
                .accessibilityIdentifier("workouts.add")
            }
        }
        .sheet(isPresented: $isCreating, onDismiss: openCreatedWorkout) {
            WorkoutNameSheet(title: "Novo treino") { name in
                createdWorkout = try WorkoutService(context: context).createWorkout(name: name)
            }
        }
        .navigationDestination(item: $openedWorkout) { workout in
            WorkoutEditorView(workout: workout)
        }
        .navigationDestination(isPresented: $isShowingPlan) {
            WeeklyPlanView()
        }
    }

    private func openCreatedWorkout() {
        guard let createdWorkout else { return }
        self.createdWorkout = nil
        openedWorkout = createdWorkout
    }
}

/// The weekly plan row: its name, how many days are planned and a disclosure chevron.
private struct WeeklyPlanRow: View {
    let summary: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Programação semanal")
                    .font(.headline)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// A workout card: name, number of exercises and a disclosure chevron (opens the editor), and
/// "Iniciar", which is unavailable while the workout has no exercises.
private struct WorkoutCard: View {
    let workout: Workout
    let onOpen: @MainActor () -> Void
    let onStart: @MainActor () -> Void

    var body: some View {
        let count = workout.exercises.count
        VStack(spacing: 12) {
            Button(action: onOpen) {
                summary(count: count)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workouts.card")

            Button(action: onStart) {
                Label("Iniciar", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(count == 0)
            .accessibilityIdentifier("workouts.start")
        }
        .cardStyle()
    }

    private func summary(count: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline)
                    .lineLimit(2)
                Group {
                    if count == 0 {
                        Text("Nenhum exercício")
                    } else {
                        Text("\(count) exercícios")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
