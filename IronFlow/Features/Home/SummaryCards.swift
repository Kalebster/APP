import SwiftData
import SwiftUI

/// The cards of the "Resumo rápido", in the order chosen in Personalizar. Only these indicators are
/// read (`SummaryIndicatorLoader`), and only again when what they show can have changed: another day,
/// another choice, another weekly plan goal, a body weight or profile change, a session finished or a
/// day marked this week, or the Início shown again (`refreshCount`), after the history was changed.
/// A set saved during a workout changes none of these, so it reads nothing.
///
/// The queries are those of the week's card, built from the week's limits when the view is created;
/// `HomeView` gives it the week's start as its identity, so a new week creates new queries.
struct SummaryCards: View {
    let metrics: [SummaryMetric]
    let now: Date
    let calendar: Calendar
    let known: SummaryIndicatorLoader.Known
    /// Grows each time the Início appears.
    let refreshCount: Int
    let onAction: @MainActor (SummaryCardAction) -> Void

    /// Finished sessions started this week.
    @Query private var weekSessions: [Session]
    /// Markings of this week's days.
    @Query private var weekMarkings: [ExternalWorkoutDay]

    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var values: [SummaryMetric: IndicatorValue] = [:]
    @State private var errorMessage: String?

    init(
        metrics: [SummaryMetric],
        week: WeekSummary.Week,
        now: Date,
        calendar: Calendar,
        known: SummaryIndicatorLoader.Known,
        refreshCount: Int,
        onAction: @escaping @MainActor (SummaryCardAction) -> Void
    ) {
        self.metrics = metrics
        self.now = now
        self.calendar = calendar
        self.known = known
        self.refreshCount = refreshCount
        self.onAction = onAction
        let start = week.start
        let end = week.end
        _weekSessions = Query(filter: #Predicate<Session> { session in
            session.endedAt != nil && session.startedAt >= start && session.startedAt < end
        })
        let keys = week.keys
        _weekMarkings = Query(filter: #Predicate<ExternalWorkoutDay> { marking in
            keys.contains(marking.day)
        })
    }

    /// What the values depend on; a change reads them again.
    private struct Inputs: Equatable {
        var metrics: [SummaryMetric]
        var day: String
        var planGoal: Int
        var latestWeightKg: Double?
        var profileUpdatedAt: Date?
        /// Each finished session of the week with its last change, so a session edited in the history
        /// counts too.
        var weekSessions: [UUID: Date]
        var weekMarkings: [String]
        var refreshCount: Int
    }

    private var inputs: Inputs {
        Inputs(
            metrics: metrics,
            day: TrainingDay.key(for: now, calendar: calendar),
            planGoal: known.planGoal,
            latestWeightKg: known.latestWeightKg,
            profileUpdatedAt: known.profile?.updatedAt,
            weekSessions: Dictionary(weekSessions.map { ($0.id, $0.updatedAt) }, uniquingKeysWith: { first, _ in first }),
            weekMarkings: weekMarkings.map(\.day).sorted(),
            refreshCount: refreshCount
        )
    }

    var body: some View {
        let month = calendar.component(.month, from: now)
        let cards = ForEach(metrics) { metric in
            Button {
                onAction(metric.cardAction(month: month))
            } label: {
                SummaryCard(metric: metric, value: values[metric])
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.metric.\(metric.rawValue)")
        }

        VStack(alignment: .leading, spacing: 8) {
            // One row; a column with the largest text sizes, so values are never cut.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 9) { cards }
            } else {
                // Cards in a row share the height of the tallest one.
                HStack(alignment: .top, spacing: 9) { cards }
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let errorMessage {
                Text(verbatim: errorMessage)
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.failureSet)
                    .accessibilityIdentifier("home.metrics.error")
            }
        }
        .onChange(of: inputs, initial: true) {
            load()
        }
    }

    private func load() {
        do {
            values = try SummaryIndicatorLoader(context: context, now: now, calendar: calendar)
                .values(for: metrics, known: known)
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// One card of the "Resumo rápido": the indicator's icon, its value large ("80" kg, "4 sem.") and what
/// it is below it ("Peso", "Na meta"). Without a value, the cards that edit one say "Adicionar"; the
/// others show "—".
private struct SummaryCard: View {
    let metric: SummaryMetric
    let value: IndicatorValue?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconTile(systemImage: metric.systemImage, side: 29, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 2) {
                if let number = value?.value {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(verbatim: number)
                            .scaledFont(19, weight: .heavy)
                        if let unit = value?.unit {
                            Text(verbatim: unit)
                                .scaledFont(12, weight: .semibold)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                } else if metric.bodyMetric != nil {
                    Text("Adicionar")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(Theme.Colors.lightAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text(verbatim: "—")
                        .scaledFont(19, weight: .heavy)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                Text(verbatim: value?.caption ?? "")
                    .scaledFont(11)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .cardStyle(padding: EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10), cornerRadius: 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.accessibilityText(metric: metric, value: value)))
    }

    /// The name and the value, and what a tap does on the cards that open something: "Peso: 80 kg,
    /// editar", "TMB: 1.780 kcal, calcular", "Sequência: 4 semanas seguidas batendo a meta".
    static func accessibilityText(metric: SummaryMetric, value: IndicatorValue?) -> String {
        var text = "\(String(localized: metric.title)): \(value?.spoken ?? "")"
        if metric.bodyMetric != nil, value?.value != nil {
            text += ", \(String(localized: "editar"))"
        } else if metric == .bmr {
            text += ", \(String(localized: "calcular"))"
        }
        return text
    }
}
