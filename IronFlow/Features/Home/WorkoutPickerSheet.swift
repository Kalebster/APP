import SwiftData
import SwiftUI

/// "Escolher um treino": the planned workouts, in the order of the Treinos tab. Choosing one hands it
/// to `onChoose` and closes the sheet; the caller starts the session once the sheet is gone.
/// A workout without exercises cannot be started and is shown unavailable.
struct WorkoutPickerSheet: View {
    let onChoose: @MainActor (Workout) -> Void

    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    @Environment(\.dismiss) private var dismiss
    /// Set once a workout is chosen, so a second tap while the sheet closes chooses nothing.
    @State private var isChosen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Metrics.cardSpacing) {
                    ForEach(workouts) { workout in
                        let count = workout.exercises.count
                        Button {
                            choose(workout)
                        } label: {
                            WorkoutPickerRow(name: workout.name, exerciseCount: count)
                        }
                        .buttonStyle(.plain)
                        .disabled(count == 0 || isChosen)
                        .accessibilityIdentifier("workoutPicker.workout")
                    }
                }
                .padding(Theme.Metrics.screenPadding)
            }
            .overlay {
                if workouts.isEmpty {
                    ContentUnavailableView("Nenhum treino ainda", systemImage: "list.bullet.rectangle")
                }
            }
            .screenBackground()
            .navigationTitle("Escolher um treino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .accessibilityIdentifier("workoutPicker.cancel")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func choose(_ workout: Workout) {
        guard !isChosen else { return }
        isChosen = true
        onChoose(workout)
        dismiss()
    }
}

/// A workout in the picker: name and number of exercises, and a start mark when it can be started.
private struct WorkoutPickerRow: View {
    let name: String
    let exerciseCount: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .lineLimit(2)
                Group {
                    if exerciseCount == 0 {
                        Text("Nenhum exercício")
                    } else {
                        Text("\(exerciseCount) exercícios")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if exerciseCount > 0 {
                Image(systemName: "play.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        }
        .opacity(exerciseCount == 0 ? 0.5 : 1)
        .cardStyle()
    }
}
