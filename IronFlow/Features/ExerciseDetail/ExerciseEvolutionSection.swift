import SwiftUI

/// EVOLUÇÃO: the last time and the best set, and the chart card. The chart is computed once for each
/// metric and period (`ExerciseChart`); choosing a point on it changes only the point chosen.
struct ExerciseEvolutionSection: View {
    let history: ExerciseHistory
    let today: Date
    let calendar: Calendar

    private struct ChartKey: Hashable {
        let metric: ExerciseMetric
        let period: ExercisePeriod
    }

    /// The first metric of the exercise when the screen opens.
    @State private var metric: ExerciseMetric
    @State private var period = ExercisePeriod.threeMonths
    @State private var chart: ExerciseChart?
    /// The session chosen on the chart; `nil` is the most recent one.
    @State private var selectedID: UUID?

    init(history: ExerciseHistory, today: Date, calendar: Calendar) {
        self.history = history
        self.today = today
        self.calendar = calendar
        _metric = State(initialValue: history.metrics[0])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Evolução")
            ExerciseBestSetTiles(history: history, today: today, calendar: calendar)
            if let chart {
                ExerciseChartCard(
                    chart: chart,
                    metrics: history.metrics,
                    showsPeriodMenu: history.entries.count > 1,
                    today: today,
                    calendar: calendar,
                    metric: $metric,
                    period: $period,
                    selectedID: $selectedID
                )
            }
        }
        .onChange(of: ChartKey(metric: metric, period: period), initial: true) { _, key in
            chart = history.chart(metric: key.metric, period: key.period, today: today, calendar: calendar)
            selectedID = nil
        }
        // The history read again (a session gone, a new kind of machine): the chart is made again. A new kind
        // (Graviton or not) has other metrics: the first one is chosen, unless the one in use is still offered.
        .onChange(of: history) {
            if !history.metrics.contains(metric) {
                metric = history.metrics[0]
            } else {
                chart = history.chart(metric: metric, period: period, today: today, calendar: calendar)
                selectedID = nil
            }
        }
    }
}
