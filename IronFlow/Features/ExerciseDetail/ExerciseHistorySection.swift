import SwiftUI

/// HISTÓRICO: "N treinos" (for Graviton, "· kg é a ajuda"), the 5 most recent sessions and "Mostrar mais",
/// which shows 10 more. Each card opens the session's detail. The cards are built as they scroll into
/// sight.
struct ExerciseHistorySection: View {
    let history: ExerciseHistory
    let today: Date
    let calendar: Calendar
    let onOpen: @MainActor (UUID) -> Void

    @State private var shownCount = 5

    var body: some View {
        let recent = Array(history.entries.reversed())
        let best = history.bestSet

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                SectionTitle("Histórico", webKitLine: true)
                Spacer(minLength: 0)
                Text(verbatim: ExerciseHistoryFormatting.countText(history.entries.count, isAssisted: history.kind == .assisted))
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .accessibilityIdentifier("exercise.history.count")
            }
            LazyVStack(spacing: 9) {
                ForEach(recent.prefix(shownCount)) { entry in
                    ExerciseSessionCard(
                        entry: entry,
                        bestSetNumber: best?.sessionID == entry.id ? best?.set.number : nil,
                        today: today,
                        calendar: calendar
                    ) {
                        onOpen(entry.id)
                    }
                }
                if recent.count > shownCount {
                    showMoreButton
                }
            }
        }
    }

    private var showMoreButton: some View {
        Button(action: showMore) {
            Text("Mostrar mais")
                .scaledFont(14, weight: .semibold)
                .foregroundStyle(Theme.Colors.lightAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(Capsule().strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("exercise.history.more")
    }

    private func showMore() {
        shownCount += 10
    }
}

/// A session of the exercise: the workout's name, the day, the ›, and the sets done in two columns, each
/// with its number in the color of its type, as in the session, and "kg × reps" ("N reps" without a load);
/// ★ on the best set of all.
private struct ExerciseSessionCard: View {
    let entry: ExerciseHistory.Entry
    /// The number of the best set of all, when it is in this session.
    let bestSetNumber: Int?
    let today: Date
    let calendar: Calendar
    let action: @MainActor () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(verbatim: entry.workoutName)
                        .scaledFont(14, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: ExerciseHistoryFormatting.dateText(entry.startedAt, today: today, calendar: calendar))
                        .scaledFont(12)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    AppIcon(.chevronRight, size: 12)
                        .foregroundStyle(Theme.Colors.dimText)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(entry.sets, id: \.number) { record in
                        ExerciseSetRow(record: record, isBest: record.number == bestSetNumber)
                    }
                }
            }
            .cardStyle(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14), cornerRadius: 17)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("exercise.history.session")
    }

    /// "Push, sex, 9 out. Série 1, Aquecimento: 40 kg × 15. Série 2, Válida: 62 kg × 10, melhor série."
    private var accessibilityText: String {
        let date = ExerciseHistoryFormatting.dateText(entry.startedAt, today: today, calendar: calendar)
        let sets = entry.sets.map { record in
            var text = String(localized: "Série \(record.number), \(String(localized: record.type.displayName)): \(ExerciseHistoryFormatting.setText(record))")
            if record.number == bestSetNumber {
                text += String(localized: ", melhor série")
            }
            return text
        }
        return ([String(localized: "\(entry.workoutName), \(date)")] + sets).joined(separator: ". ")
    }
}

/// One set of a session card: its number in the circle of its type's color and "kg × reps".
private struct ExerciseSetRow: View {
    let record: ExerciseHistory.SetRecord
    let isBest: Bool

    @ScaledMetric(relativeTo: .caption) private var circleSide: CGFloat = 22

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(record.number)")
                .scaledFont(12, weight: .bold)
                .monospacedDigit()
                .foregroundStyle(record.type == .working ? Theme.Colors.secondaryText : record.type.numberColor)
                .frame(width: circleSide, height: circleSide)
                .background(record.type == .working ? Color.clear : record.type.numberBackground, in: Circle())
            Text(verbatim: ExerciseHistoryFormatting.setText(record))
                .scaledFont(14, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.brightText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if isBest {
                Text(verbatim: "★")
                    .scaledFont(11)
                    .foregroundStyle(Theme.Colors.warmupSet)
            }
        }
    }
}
