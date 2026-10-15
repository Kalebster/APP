import SwiftUI

/// A finished session, read-only: when it started, how long it took, and every exercise and set
/// as recorded. It receives plain values only, so it never reads or changes the store, the
/// planned workout or the exercise library.
struct HistorySessionDetailView: View {
    let detail: HistorySessionDetail

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
                header
                    .padding(.bottom, 4)

                if detail.exercises.isEmpty {
                    Text("Nenhum exercício registrado.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .accessibilityIdentifier("history.detail.empty")
                }

                ForEach(detail.exercises) { exercise in
                    HistoryExerciseCard(exercise: exercise)
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .screenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.detail")
        .navigationTitle(detail.name)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(SessionFormatting.dateText(detail.startedAt), systemImage: "calendar")
                .accessibilityIdentifier("history.detail.date")
            if let duration = detail.duration {
                let durationText = SessionFormatting.durationText(duration)
                Label(durationText, systemImage: "timer")
                    .accessibilityLabel(Text("Duração: \(durationText)"))
                    .accessibilityIdentifier("history.detail.duration")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

/// A performed exercise: its name and muscle group as recorded, and its sets.
private struct HistoryExerciseCard: View {
    let exercise: HistorySessionDetail.ExerciseRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                Text(exercise.muscleGroup.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(exercise.sets) { record in
                HistorySetRow(record: record)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.detail.exercise")
    }
}

/// A recorded set: its number and whether it was done, then its target, load and repetitions.
/// A set not done shows "Não concluída" and its values in the secondary color.
private struct HistorySetRow: View {
    let record: HistorySessionDetail.SetRecord

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    number
                    state
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    number
                        .frame(maxWidth: .infinity, alignment: .leading)
                    state
                }
            }
            // One text, so it wraps instead of truncating with large text sizes.
            Text(record.valuesText)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(record.isCompleted ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(record.accessibilityText)
        .accessibilityIdentifier("history.detail.set")
    }

    private var number: some View {
        Text("Série \(record.number)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
    }

    private var state: some View {
        Group {
            if record.isCompleted {
                Label("Concluída", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Label("Não concluída", systemImage: "circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline.weight(.semibold))
    }
}
