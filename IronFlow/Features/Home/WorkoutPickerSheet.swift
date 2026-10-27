import SwiftData
import SwiftUI

/// "Escolher treino": the planned workouts, the one planned for today first (with "HOJE"), the others
/// in the order of the Treinos tab. Tapping a row hands its workout to `onChoose` and closes the sheet;
/// the caller starts the session once the sheet is gone. A workout without exercises cannot be started:
/// its row is faded, has no ▶ and says where to add them.
struct WorkoutPickerSheet: View {
    /// The workout planned for today, shown first; `nil` on a rest day.
    let todayWorkoutID: UUID?
    let onChoose: @MainActor (Workout) -> Void

    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var cancelHeight: CGFloat = 50

    var body: some View {
        let ordered = Self.ordered(workouts, todayID: todayWorkoutID)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Escolher treino")
                        .scaledFont(20, weight: .heavy)
                        .accessibilityAddTraits(.isHeader)
                    Text("O treino começa assim que você tocar nele.")
                        .scaledFont(13)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if ordered.isEmpty {
                    Text("Nenhum treino ainda")
                        .scaledFont(14)
                        .foregroundStyle(Theme.Colors.secondaryText)
                } else {
                    rows(ordered)
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            cancelButton
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.cardBackground)
    }

    /// The workout planned for today first, then the others in their order.
    static func ordered(_ workouts: [Workout], todayID: UUID?) -> [Workout] {
        guard let todayID, let today = workouts.first(where: { $0.id == todayID }) else { return workouts }
        return [today] + workouts.filter { $0.id != todayID }
    }

    /// The workouts in one block, a line between them.
    private func rows(_ workouts: [Workout]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                if index > 0 {
                    Theme.Colors.rowSeparator
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                let isEmpty = workout.exercises.isEmpty
                Button {
                    choose(workout)
                } label: {
                    WorkoutPickerRow(workout: workout, isToday: workout.id == todayWorkoutID)
                }
                .buttonStyle(.plain)
                .disabled(isEmpty)
                .accessibilityIdentifier("workoutPicker.workout")
            }
        }
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var cancelButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Cancelar")
                .scaledFont(15, weight: .bold)
                .foregroundStyle(Theme.Colors.brightText)
                .frame(maxWidth: .infinity, minHeight: cancelHeight)
                .background(Theme.Colors.setFieldBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.Colors.cardBackground)
        .accessibilityIdentifier("workoutPicker.cancel")
    }

    private func choose(_ workout: Workout) {
        onChoose(workout)
        dismiss()
    }
}

/// A workout of the picker: its name ("HOJE" when planned for today), "4 exercícios · 15 séries" with
/// its muscle groups, and the ▶, white for today's workout and blue for the others. A workout without
/// exercises is faded, without ▶. VoiceOver reads all of it as one button.
private struct WorkoutPickerRow: View {
    let workout: Workout
    let isToday: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var playSide: CGFloat = 36

    var body: some View {
        let isEmpty = workout.exercises.isEmpty
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(verbatim: workout.name)
                        .scaledFont(17, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    if isToday {
                        CapsuleBadge(
                            text: String(localized: "HOJE"),
                            weight: .bold,
                            tracking: 0.9,
                            padding: EdgeInsets(top: 3, leading: 7, bottom: 3, trailing: 7)
                        )
                    }
                }
                Text(detail(isEmpty: isEmpty))
                    .scaledFont(12)
                    // One line, cut at its end, like the model; whole with the accessibility text sizes.
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isEmpty {
                Image(systemName: "play.fill")
                    .font(.system(size: playSide * 0.33, weight: .bold))
                    .foregroundStyle(isToday ? Theme.Colors.screenBackground : Color.white)
                    .frame(width: playSide, height: playSide)
                    .background(isToday ? Color.white : Color.accentColor, in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .opacity(isEmpty ? 0.45 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText(isEmpty: isEmpty)))
    }

    /// "4 exercícios · 15 séries" and, darker, " · Peito · Ombros · Tríceps"; for a workout without
    /// exercises, "Sem exercícios · adicione na tela Treinos".
    private func detail(isEmpty: Bool) -> AttributedString {
        guard !isEmpty else {
            var text = AttributedString(String(localized: "Sem exercícios · adicione na tela Treinos"))
            text.foregroundColor = Theme.Colors.secondaryText
            return text
        }
        var text = AttributedString(WorkoutListSummary.cardSummary(for: workout))
        text.foregroundColor = Theme.Colors.secondaryText
        let groups = WorkoutListSummary.muscleGroupsText(WorkoutListSummary.muscleGroups(of: workout))
        if !groups.isEmpty {
            var groupsText = AttributedString(" · \(groups)")
            groupsText.foregroundColor = Theme.Colors.dimText
            text += groupsText
        }
        return text
    }

    /// "Push, hoje, 4 exercícios · 15 séries, Peito · Ombros · Tríceps"; "Costas e Bíceps, Sem exercícios ·
    /// adicione na tela Treinos".
    private func accessibilityText(isEmpty: Bool) -> String {
        var parts = [workout.name]
        if isToday {
            parts.append(String(localized: "hoje"))
        }
        if isEmpty {
            parts.append(String(localized: "Sem exercícios · adicione na tela Treinos"))
        } else {
            parts.append(WorkoutListSummary.cardSummary(for: workout))
            let groups = WorkoutListSummary.muscleGroupsText(WorkoutListSummary.muscleGroups(of: workout))
            if !groups.isEmpty {
                parts.append(groups)
            }
        }
        return parts.joined(separator: ", ")
    }
}
