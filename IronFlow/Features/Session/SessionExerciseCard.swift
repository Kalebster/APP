import SwiftUI

/// An exercise of the session: its name and muscle group (as performed), its sets and "Adicionar série".
struct SessionExerciseCard: View {
    let performed: SessionExercise
    let focusedField: FocusState<SetField?>.Binding
    let draft: @MainActor (SetLog) -> Binding<SetDraft>
    let onToggle: @MainActor (SetLog) -> Void
    let onAddSet: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var weightWidth = SetRowMetrics.weightWidth
    @ScaledMetric(relativeTo: .body) private var repsWidth = SetRowMetrics.repsWidth
    @ScaledMetric(relativeTo: .body) private var checkWidth = SetRowMetrics.checkWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(performed.exerciseNameSnapshot)
                    .font(.headline)
                Text(performed.muscleGroupSnapshot.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Série")
                    .frame(minWidth: SetRowMetrics.numberWidth, alignment: .leading)
                Text("Meta")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: "kg")
                    .frame(width: weightWidth)
                Text("Reps")
                    .frame(width: repsWidth)
                Color.clear
                    .frame(width: checkWidth, height: 1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

            ForEach(Array(performed.orderedSetLogs.enumerated()), id: \.element.id) { index, log in
                SessionSetRow(
                    number: index + 1,
                    log: log,
                    draft: draft(log),
                    focusedField: focusedField
                ) {
                    onToggle(log)
                }
            }

            Button(action: onAddSet) {
                Label("Adicionar série", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("session.addSet")
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session.exercise")
    }
}
