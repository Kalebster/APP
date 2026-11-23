import SwiftUI

/// ÚLTIMA VEZ and MELHOR SÉRIE ★, side by side (one above the other with the largest text sizes): the set
/// and the day of its session; for Graviton, "de ajuda · " before the day.
struct ExerciseBestSetTiles: View {
    let history: ExerciseHistory
    let today: Date
    let calendar: Calendar

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 9))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 9))
        layout {
            if let last = history.lastTime {
                tile(title: "ÚLTIMA VEZ", star: false, best: last, identifier: "exercise.lastTime")
            }
            if let best = history.bestSet {
                tile(title: "MELHOR SÉRIE", star: true, best: best, identifier: "exercise.bestSet")
            }
        }
    }

    private func tile(title: LocalizedStringKey, star: Bool, best: ExerciseHistory.BestSet, identifier: String) -> some View {
        let date = ExerciseHistoryFormatting.dateText(best.startedAt, today: today, calendar: calendar)
        let detail = history.kind == .assisted ? String(localized: "de ajuda · \(date)") : date
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(title)
                    .scaledFont(10, weight: .heavy)
                    .tracking(1.4)
                    .foregroundStyle(Theme.Colors.secondaryText)
                if star {
                    Text(verbatim: "★")
                        .scaledFont(11)
                        .foregroundStyle(Theme.Colors.warmupSet)
                }
            }
            Text(verbatim: ExerciseHistoryFormatting.setText(best.set))
                .scaledFont(19, weight: .heavy, lineHeight: 1.15)
                .monospacedDigit()
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .truncationMode(.tail)
            Text(verbatim: detail)
                .scaledFont(12)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .cardStyle(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14), cornerRadius: 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(verbatim: "\(ExerciseHistoryFormatting.setText(best.set)), \(detail)"))
        .accessibilityIdentifier(identifier)
    }
}
