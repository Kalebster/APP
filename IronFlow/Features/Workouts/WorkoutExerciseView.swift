import SwiftData
import SwiftUI

/// The planned sets of one exercise in a workout: edit a set, add a set (a copy of the last one)
/// and remove sets. An exercise keeps at least one set. Every change is saved immediately.
struct WorkoutExerciseView: View {
    let item: WorkoutExercise

    @Environment(\.modelContext) private var context
    @State private var editingSet: PlannedSet?
    @State private var errorMessage: String?

    private var service: WorkoutService {
        WorkoutService(context: context)
    }

    var body: some View {
        let sets = item.orderedPlannedSets
        let canRemove = sets.count > 1

        List {
            if let exercise = item.exercise {
                Text(exercise.muscleGroup.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .cardListRow()
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, plannedSet in
                Button {
                    editingSet = plannedSet
                } label: {
                    PlannedSetRow(number: index + 1, plannedSet: plannedSet)
                        .cardStyle()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exercise.set")
                .cardListRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if canRemove {
                        Button("Remover") {
                            removeSet(plannedSet)
                        }
                        .tint(.red)
                    }
                }
            }

            Button(action: addSet) {
                Label("Adicionar série", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .cardStyle()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise.addSet")
            .cardListRow()

            if !canRemove {
                Text("O exercício precisa de pelo menos uma série.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("exercise.lastSetHint")
                    .cardListRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(item.exercise?.name ?? String(localized: "Exercício removido"))
        .sheet(item: $editingSet) { plannedSet in
            PlannedSetEditorSheet(
                number: (sets.firstIndex { $0.id == plannedSet.id } ?? 0) + 1,
                values: PlannedSetValues(weightKg: plannedSet.weightKg, repsMin: plannedSet.repsMin, repsMax: plannedSet.repsMax)
            ) { values in
                try service.updatePlannedSet(plannedSet, values: values)
            }
        }
        .errorAlert($errorMessage)
    }

    private func addSet() {
        do {
            try service.addPlannedSetCopyingLast(to: item)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func removeSet(_ plannedSet: PlannedSet) {
        do {
            try service.removePlannedSet(plannedSet)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// A planned set: its number, repetitions and load.
private struct PlannedSetRow: View {
    let number: Int
    let plannedSet: PlannedSet

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Série \(number)")
                    .font(.headline)
                Text(verbatim: "\(PlannedSetFormatting.repsText(min: plannedSet.repsMin, max: plannedSet.repsMax)) · \(PlannedSetFormatting.weightText(plannedSet.weightKg))")
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
