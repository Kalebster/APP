import Charts
import SwiftUI

/// The evolution chart, drawn as the prototype's (an SVG of 340 × 150 at the card's width): the horizontal
/// lines with their values on the right, the months below, the line of the values over a light fill,
/// a point per session and the session chosen, larger, with a vertical line. The line, the fill and the
/// points are Swift Charts marks, which VoiceOver and the audio graph read; the lines and labels behind
/// them are drawn with the same proportions. "Menor ajuda" is drawn upside down: less help is higher.
///
/// A tap, or a sideways drag, chooses the session nearest to the finger; an up or down drag still scrolls
/// the screen.
struct ExerciseChartPlot: View {
    let chart: ExerciseChart
    let selectedIndex: Int
    let today: Date
    let calendar: Calendar
    let onSelect: @MainActor (Int) -> Void

    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10

    var body: some View {
        // The prototype's units, scaled to the width; the height keeps its proportion.
        GeometryReader { proxy in
            let scale = proxy.size.width / PrototypeChart.width
            ZStack(alignment: .topLeading) {
                ChartGuides(chart: chart, scale: scale, labelSize: labelSize, calendar: calendar)
                marks(scale: scale)
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                select(at: location.x, scale: scale)
            }
            .gesture(HorizontalScrubGesture { x in
                select(at: x, scale: scale)
            })
        }
        .aspectRatio(PrototypeChart.width / PrototypeChart.height, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: chart.accessibilitySummary(today: today, calendar: calendar) ?? chart.metric.title))
        .accessibilityIdentifier("exercise.chart.plot")
    }

    /// The marks, with scales that place the whole SVG box in the frame: the domain is widened by the
    /// prototype's margins around its plot (6 and 42 on the sides, 12 above and 32 below).
    private func marks(scale: CGFloat) -> some View {
        let span = chart.end.timeIntervalSince(chart.start)
        let plotWidth = PrototypeChart.plotRight - PrototypeChart.plotLeft
        let xStart = chart.start.addingTimeInterval(-span * PrototypeChart.plotLeft / plotWidth)
        let xEnd = chart.start.addingTimeInterval(span * (PrototypeChart.width - PrototypeChart.plotLeft) / plotWidth)
        // Plotted values: upside down for "Menor ajuda".
        let low = plotted(chart.metric.isInverted ? chart.highest : chart.lowest)
        let high = plotted(chart.metric.isInverted ? chart.lowest : chart.highest)
        let plotHeight = PrototypeChart.plotBottom - PrototypeChart.plotTop
        let yBottom = low - (high - low) * (PrototypeChart.height - PrototypeChart.plotBottom) / plotHeight
        let yTop = high + (high - low) * PrototypeChart.plotTop / plotHeight
        let selected = chart.points[min(selectedIndex, chart.points.count - 1)]

        return Chart {
            ForEach(chart.points) { point in
                AreaMark(
                    x: .value("Dia", point.day),
                    yStart: .value("Base", low),
                    yEnd: .value(chart.metric.title, plotted(point.value))
                )
                .foregroundStyle(Color.accentColor.opacity(0.12))
                .accessibilityHidden(true)
            }
            ForEach(chart.points) { point in
                LineMark(x: .value("Dia", point.day), y: .value(chart.metric.title, plotted(point.value)))
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))
                    .accessibilityHidden(true)
            }
            RuleMark(x: .value("Dia", selected.day), yStart: .value("Base", low), yEnd: .value("Topo", high))
                .foregroundStyle(Theme.Colors.chartRule)
                .lineStyle(StrokeStyle(lineWidth: 1 * scale))
                .accessibilityHidden(true)
            ForEach(Array(chart.points.enumerated()), id: \.element.id) { index, point in
                PointMark(x: .value("Dia", point.day), y: .value(chart.metric.title, plotted(point.value)))
                    .symbol {
                        if index == selectedIndex {
                            // r 5, white, with a 2,5 outline in the accent color.
                            Circle()
                                .fill(Theme.Colors.brightText)
                                .stroke(Color.accentColor, lineWidth: 2.5 * scale)
                                .frame(width: 10 * scale, height: 10 * scale)
                        } else {
                            // r 2,6 in the accent color, with a 1,5 outline of the card's color.
                            Circle()
                                .fill(Color.accentColor)
                                .stroke(Theme.Colors.cardBackground, lineWidth: 1.5 * scale)
                                .frame(width: 5.2 * scale, height: 5.2 * scale)
                        }
                    }
                    .accessibilityLabel(Text(verbatim: ExerciseHistoryFormatting.dateText(point.startedAt, today: today, calendar: calendar)))
                    .accessibilityValue(Text(verbatim: ExerciseHistoryFormatting.valueText(point.value, metric: chart.metric)))
            }
        }
        .chartXScale(domain: xStart...xEnd, range: .plotDimension(startPadding: 0, endPadding: 0))
        .chartYScale(domain: yBottom...yTop, range: .plotDimension(startPadding: 0, endPadding: 0))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    /// The value as plotted: negative for "Menor ajuda", so less help is higher.
    private func plotted(_ value: Double) -> Double {
        chart.metric.isInverted ? -value : value
    }

    /// Chooses the session whose point is nearest to `x`.
    private func select(at x: CGFloat, scale: CGFloat) {
        guard chart.points.count > 1 else { return }
        let unitX = Double(x / max(scale, 0.01))
        let positions = chart.points.map { PrototypeChart.plotLeft + chart.fraction(of: $0.day) * (PrototypeChart.plotRight - PrototypeChart.plotLeft) }
        guard let nearest = positions.indices.min(by: { abs(positions[$0] - unitX) < abs(positions[$1] - unitX) }) else { return }
        if nearest != selectedIndex {
            onSelect(nearest)
        }
    }
}

/// The lines and labels behind the marks: a line for each value of the axis, with the value on the right,
/// and a tick with the month's name below for each month labeled. Decorative: the chart's summary says
/// what they show.
private struct ChartGuides: View {
    let chart: ExerciseChart
    let scale: CGFloat
    let labelSize: CGFloat
    let calendar: Calendar

    var body: some View {
        Canvas { context, _ in
            let font = Font.system(size: labelSize)
            for tick in chart.ticks {
                let y = yPosition(of: tick) * scale
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: PrototypeChart.plotRight * scale, y: y))
                context.stroke(line, with: .color(Theme.Colors.cardBorder), lineWidth: 1)
                let label = Text(verbatim: ExerciseHistoryFormatting.number(tick, metric: chart.metric))
                    .font(font)
                    .foregroundStyle(Theme.Colors.dimText)
                context.draw(label, at: CGPoint(x: PrototypeChart.width * scale, y: y), anchor: .trailing)
            }
            for month in chart.months {
                let x = (PrototypeChart.plotLeft + chart.fraction(of: month) * (PrototypeChart.plotRight - PrototypeChart.plotLeft)) * scale
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: PrototypeChart.plotBottom * scale))
                tick.addLine(to: CGPoint(x: x, y: (PrototypeChart.plotBottom + 4) * scale))
                context.stroke(tick, with: .color(Theme.Colors.chartRule), lineWidth: 1)
                let label = Text(verbatim: SessionFormatting.monthAbbreviation(calendar.component(.month, from: month)))
                    .font(font)
                    .foregroundStyle(Theme.Colors.dimText)
                // The prototype's baseline at 136: the middle of the digits and lowercase letters about 3,5
                // above it.
                context.draw(label, at: CGPoint(x: x, y: (PrototypeChart.height - 14 - 3.5) * scale), anchor: .center)
            }
        }
        .accessibilityHidden(true)
    }

    /// Where a value of the axis falls, in the prototype's units: the lowest at the bottom of the plot
    /// (118) and the highest at its top (12); upside down for "Menor ajuda".
    private func yPosition(of value: Double) -> CGFloat {
        let span = max(chart.highest - chart.lowest, 0.000_001)
        let fraction = (value - chart.lowest) / span
        let plotHeight = PrototypeChart.plotBottom - PrototypeChart.plotTop
        return chart.metric.isInverted
            ? PrototypeChart.plotTop + fraction * plotHeight
            : PrototypeChart.plotBottom - fraction * plotHeight
    }
}
