import SwiftUI

/// The chart card: the value of the session chosen (the most recent at first) with the metric and the
/// day, the period menu in the corner, the change in the period, the chart (or the message that takes its
/// place), and the metric buttons below.
struct ExerciseChartCard: View {
    let chart: ExerciseChart
    let metrics: [ExerciseMetric]
    /// With a single session there is nothing to choose.
    let showsPeriodMenu: Bool
    let today: Date
    let calendar: Calendar
    @Binding var metric: ExerciseMetric
    @Binding var period: ExercisePeriod
    @Binding var selectedID: UUID?

    var body: some View {
        let selectedIndex = chart.points.firstIndex { $0.id == selectedID } ?? (chart.points.count - 1)
        let point = chart.points.indices.contains(selectedIndex) ? chart.points[selectedIndex] : nil
        let isLastSelected = selectedIndex == chart.points.count - 1

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                ChartValueHeader(chart: chart, point: point, today: today, calendar: calendar)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showsPeriodMenu {
                    periodMenu
                }
            }

            if let message = chart.message {
                Text(verbatim: message)
                    .scaledFont(13, lineHeight: 1.4)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                    .accessibilityIdentifier("exercise.chart.message")
            } else {
                changeLine(isLastSelected: isLastSelected)
                    .padding(.top, 6)
                ExerciseChartPlot(chart: chart, selectedIndex: selectedIndex, today: today, calendar: calendar) { index in
                    // The most recent session is "none chosen": the change shows again.
                    selectedID = index == chart.points.count - 1 ? nil : chart.points[index].id
                }
                .padding(.top, 8)
                if chart.metric.isInverted {
                    Text("Menos ajuda fica mais alto no gráfico.")
                        .scaledFont(11)
                        .foregroundStyle(Theme.Colors.dimText)
                        .padding(.bottom, 2)
                }
            }

            metricButtons
                .padding(.top, 8)
        }
        .cardStyle(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 12), cornerRadius: 17)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exercise.chart")
    }

    /// "▲ 12 kg nos últimos 3 meses" while the most recent session is chosen. With an older one chosen the
    /// phrase goes, for the eye and for VoiceOver, and its line keeps its room, so nothing below moves: the
    /// prototype's hidden "·" of the same size. (Made only transparent, the phrase was still read.)
    @ViewBuilder
    private func changeLine(isLastSelected: Bool) -> some View {
        if isLastSelected, let change = chart.change {
            Text(verbatim: change.text)
                .scaledFont(12, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(change.isWorse ? Theme.Colors.secondaryText : Theme.Colors.lightAccent)
                .accessibilityIdentifier("exercise.chart.change")
        } else {
            Text(verbatim: "·")
                .scaledFont(12, weight: .semibold)
                .hidden()
                .accessibilityHidden(true)
        }
    }

    /// "3 meses ⌄": the iOS menu with the 3 periods and a ✓ on the one chosen.
    private var periodMenu: some View {
        Menu {
            Picker("Período do gráfico", selection: $period) {
                ForEach(ExercisePeriod.allCases, id: \.self) { (choice: ExercisePeriod) in
                    Text(verbatim: choice.title).tag(choice)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: period.title)
                    .scaledFont(13, weight: .semibold)
                    .lineLimit(1)
                AppIcon(.chevronDown, size: 11)
            }
            .foregroundStyle(Theme.Colors.lightAccent)
            .padding(.horizontal, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .fixedSize()
        // As in the prototype: 8 above its 44 points and 4 past the card's margin.
        .padding(.top, -8)
        .padding(.trailing, -4)
        .accessibilityLabel(Text("Período: \(period.title)"))
        .accessibilityIdentifier("exercise.chart.period")
    }

    /// The two metrics of the exercise: 32 points tall, 44 of touch; the one chosen in white.
    private var metricButtons: some View {
        HStack(spacing: 6) {
            ForEach(metrics, id: \.self) { (choice: ExerciseMetric) in
                MetricButton(title: choice.title, isSelected: choice == metric) {
                    metric = choice
                }
                .accessibilityIdentifier("exercise.chart.metric.\(metrics.firstIndex(of: choice) ?? 0)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("O que o gráfico mostra"))
    }
}

/// The value of the session chosen, large, with its unit, and "métrica · dia" below; "—" and the metric
/// without sessions in the period.
private struct ChartValueHeader: View {
    let chart: ExerciseChart
    let point: ExerciseChart.Point?
    let today: Date
    let calendar: Calendar

    @ScaledMetric(relativeTo: .subheadline) private var unitSize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let point {
                let number = Text(verbatim: ExerciseHistoryFormatting.number(point.value, metric: chart.metric)).tracking(-0.4)
                let unit = Text(verbatim: " \(chart.metric.unit)")
                    .font(.system(size: unitSize, weight: .bold))
                    .foregroundStyle(Theme.Colors.secondaryText)
                Text("\(number)\(unit)")
                    .scaledFont(28, weight: .heavy, lineHeight: 1.1)
                    .monospacedDigit()
                    .accessibilityIdentifier("exercise.chart.value")
                Text(verbatim: "\(chart.metric.title) · \(ExerciseHistoryFormatting.dateText(point.startedAt, today: today, calendar: calendar))")
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .accessibilityIdentifier("exercise.chart.date")
            } else {
                Text(verbatim: "—")
                    .scaledFont(28, weight: .heavy, lineHeight: 1.1)
                    .accessibilityIdentifier("exercise.chart.value")
                Text(verbatim: chart.metric.title)
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .accessibilityIdentifier("exercise.chart.date")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A metric button: a capsule outlined in the card border, white with black text once chosen.
private struct MetricButton: View {
    let title: String
    let isSelected: Bool
    let action: @MainActor () -> Void

    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 32

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .scaledFont(13, weight: .semibold)
                .foregroundStyle(isSelected ? Theme.Colors.primaryButtonText : Theme.Colors.mediumText)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .frame(minHeight: height)
                .background(isSelected ? Theme.Colors.primaryButton : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Theme.Colors.primaryButton : Theme.Colors.cardBorder, lineWidth: 1))
                // 44 points of touch without taking room.
                .padding(.vertical, ChipMetrics.touchExtra(for: height))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -ChipMetrics.touchExtra(for: height))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
