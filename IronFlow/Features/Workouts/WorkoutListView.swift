import SwiftData
import SwiftUI

/// The Workouts tab: one card per planned workout. Creating a workout opens its editor.
struct WorkoutListView: View {
    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    @Environment(\.modelContext) private var context
    @State private var isCreating = false
    /// Workout created in the name sheet, opened once the sheet is dismissed.
    @State private var createdWorkout: Workout?
    @State private var openedWorkout: Workout?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Metrics.cardSpacing) {
                ForEach(workouts) { workout in
                    Button {
                        openedWorkout = workout
                    } label: {
                        WorkoutCard(workout: workout)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workouts.card")
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
    }

    private func openCreatedWorkout() {
        guard let createdWorkout else { return }
        self.createdWorkout = nil
        openedWorkout = createdWorkout
    }
}

/// A workout card: name, number of exercises and a disclosure chevron.
private struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        let count = workout.exercises.count
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
        .cardStyle()
    }
}
