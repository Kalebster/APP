import Foundation

/// The history of one exercise, as the exercise screen shows it: the finished sessions in which it had
/// a working or failure set done, the best sets and the evolution chart. Pure logic: it reads the values
/// it is given (`ExerciseHistoryLoader` reads the store) and never the store or the clock.
///
/// Rules, as approved:
/// - Only the working and failure sets done count (`SetType.countsTowardLiftedLoad`), as in the kg lifted.
///   Warm-up and feeder sets are shown in the history, but count for nothing.
/// - Only finished sessions; a session in which the exercise had no working or failure set done is left
///   out of the history and of the evolution. One point of the chart per session.
/// - Best set: more kg, then more repetitions; on a full tie the oldest one. Graviton (the kg is the
///   help): less kg, then more repetitions. Without kg in any set: more repetitions.
struct ExerciseHistory: Equatable {
    /// A set done of the exercise in one session.
    struct SetRecord: Equatable, Sendable {
        /// Its number among the sets done of the exercise in that session, from 1.
        let number: Int
        let type: SetType
        let weightKg: Double?
        let reps: Int?

        var counts: Bool { type.countsTowardLiftedLoad }
        /// The load, `nil` counted as 0.
        var load: Double { weightKg ?? 0 }
        /// The repetitions, `nil` counted as 0.
        var repetitions: Int { reps ?? 0 }
    }

    /// A finished session with the exercise.
    struct Entry: Identifiable, Equatable, Sendable {
        /// The session's id.
        let id: UUID
        /// The session's name ("Push", "Treino livre").
        let workoutName: String
        let startedAt: Date
        /// Every set done of the exercise, in order, of every type.
        let sets: [SetRecord]

        var countedSets: [SetRecord] { sets.filter(\.counts) }
    }

    /// What the chart and the best set read.
    enum Kind: Equatable, Sendable {
        /// With load: "Maior carga" and "Volume".
        case load
        /// Graviton, whose kg is the help of the machine: "Menor ajuda" and "Mais repetições".
        case assisted
        /// No kg in any set: "Mais repetições" and "Repetições no treino".
        case bodyweight
    }

    /// The best set and the session it is in.
    struct BestSet: Equatable, Sendable {
        let set: SetRecord
        let sessionID: UUID
        let startedAt: Date
    }

    /// The sessions that count, the oldest first.
    let entries: [Entry]
    let kind: Kind

    /// `entries` in any order; those without a working or failure set done are left out.
    init(entries: [Entry], isAssisted: Bool) {
        let counted = entries.filter { !$0.countedSets.isEmpty }
        self.entries = counted.sorted { $0.startedAt < $1.startedAt }
        if isAssisted {
            kind = .assisted
        } else if counted.allSatisfy({ $0.countedSets.allSatisfy { $0.load == 0 } }) {
            kind = .bodyweight
        } else {
            kind = .load
        }
    }

    var isEmpty: Bool { entries.isEmpty }

    /// The two metrics of the chart, the first chosen when the screen opens.
    var metrics: [ExerciseMetric] {
        switch kind {
        case .load: [.maxLoad, .volume]
        case .assisted: [.leastHelp, .maxReps]
        case .bodyweight: [.maxReps, .totalReps]
        }
    }

    /// "Última vez": the best set of the most recent session.
    var lastTime: BestSet? {
        entries.last.flatMap { best(in: [$0]) }
    }

    /// "Melhor série": the best set of every session.
    var bestSet: BestSet? {
        best(in: entries)
    }

    /// The best of the working and failure sets of `sessions`; on a full tie, the oldest.
    func best(in sessions: [Entry]) -> BestSet? {
        var best: BestSet?
        for entry in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            for record in entry.countedSets {
                guard let current = best?.set else {
                    best = BestSet(set: record, sessionID: entry.id, startedAt: entry.startedAt)
                    continue
                }
                let isBetter: Bool
                switch kind {
                case .bodyweight:
                    isBetter = record.repetitions > current.repetitions
                case .assisted:
                    isBetter = record.load < current.load || (record.load == current.load && record.repetitions > current.repetitions)
                case .load:
                    isBetter = record.load > current.load || (record.load == current.load && record.repetitions > current.repetitions)
                }
                if isBetter {
                    best = BestSet(set: record, sessionID: entry.id, startedAt: entry.startedAt)
                }
            }
        }
        return best
    }

    /// The value of `metric` in one session, from its working and failure sets.
    static func value(of metric: ExerciseMetric, in entry: Entry) -> Double {
        let sets = entry.countedSets
        switch metric {
        case .maxLoad: return sets.map(\.load).max() ?? 0
        case .leastHelp: return sets.map(\.load).min() ?? 0
        case .maxReps: return Double(sets.map(\.repetitions).max() ?? 0)
        case .volume: return sets.reduce(0) { $0 + $1.load * Double($1.repetitions) }
        case .totalReps: return Double(sets.reduce(0) { $0 + $1.repetitions })
        }
    }

    /// The chart of `metric` over `period`, counted back from the day of `today`.
    func chart(metric: ExerciseMetric, period: ExercisePeriod, today: Date, calendar: Calendar) -> ExerciseChart {
        ExerciseChart(history: self, metric: metric, period: period, today: today, calendar: calendar)
    }
}

/// What the chart shows.
enum ExerciseMetric: CaseIterable, Sendable {
    case maxLoad
    case volume
    case leastHelp
    case maxReps
    case totalReps

    var title: String {
        switch self {
        case .maxLoad: String(localized: "Maior carga")
        case .volume: String(localized: "Volume")
        case .leastHelp: String(localized: "Menor ajuda")
        case .maxReps: String(localized: "Mais repetições")
        case .totalReps: String(localized: "Repetições no treino")
        }
    }

    /// Counted in repetitions rather than kg.
    var isRepetitions: Bool {
        self == .maxReps || self == .totalReps
    }

    /// Less is better: less help of the machine. The chart is drawn upside down, so better is higher.
    var isInverted: Bool {
        self == .leastHelp
    }

    /// " kg" or " reps", after the number.
    var unit: String {
        isRepetitions ? String(localized: "reps") : "kg"
    }
}

/// The period of the chart, counted back from today.
enum ExercisePeriod: CaseIterable, Sendable {
    case threeMonths
    case oneYear
    case all

    /// The days back from today; `nil` for every session.
    var days: Int? {
        switch self {
        case .threeMonths: 90
        case .oneYear: 365
        case .all: nil
        }
    }

    /// "3 meses", in the period menu.
    var title: String {
        switch self {
        case .threeMonths: String(localized: "3 meses")
        case .oneYear: String(localized: "1 ano")
        case .all: String(localized: "Tudo")
        }
    }

    /// The end of the change and of the messages: "nos últimos 3 meses".
    var phrase: String {
        switch self {
        case .threeMonths: String(localized: "nos últimos 3 meses")
        case .oneYear: String(localized: "no último ano")
        case .all: String(localized: "desde o primeiro treino")
        }
    }
}

/// The evolution chart of one metric over one period: its points, axes, change and texts, computed once
/// for each period and metric. Positions on the X axis are by day, from the start of the period to the
/// start of today, as in the prototype.
struct ExerciseChart: Equatable {
    struct Point: Identifiable, Equatable {
        /// The session's id.
        let id: UUID
        /// The start of the session's day.
        let day: Date
        let startedAt: Date
        let value: Double
    }

    /// The change from the first to the last point of the period.
    struct Change: Equatable {
        /// "▲ 12 kg nos últimos 3 meses", "Igual no último ano".
        let text: String
        /// Worse: shown in the secondary color.
        let isWorse: Bool
    }

    let metric: ExerciseMetric
    let period: ExercisePeriod
    let points: [Point]
    /// The start of the period and the start of today.
    let start: Date
    let end: Date
    /// The values of the horizontal lines, from the lowest; the axis goes from the first to the last.
    let ticks: [Double]
    /// The first day of each month labeled below the chart.
    let months: [Date]
    let change: Change?
    /// Instead of the chart, with fewer than 2 points.
    let message: String?

    init(history: ExerciseHistory, metric: ExerciseMetric, period: ExercisePeriod, today: Date, calendar: Calendar) {
        self.metric = metric
        self.period = period
        let end = calendar.startOfDay(for: today)
        let start: Date
        if let days = period.days {
            start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        } else {
            start = history.entries.first.map { calendar.startOfDay(for: $0.startedAt) } ?? end
        }
        self.start = start
        self.end = end
        points = history.entries.compactMap { entry in
            let day = calendar.startOfDay(for: entry.startedAt)
            guard day >= start else { return nil }
            return Point(id: entry.id, day: day, startedAt: entry.startedAt, value: ExerciseHistory.value(of: metric, in: entry))
        }
        ticks = Self.ticks(for: points.map(\.value), metric: metric)
        months = Self.monthLabels(start: start, end: end, calendar: calendar)

        if history.entries.count < 2 {
            message = String(localized: "Faça este exercício em mais um treino para ver a evolução.")
            change = nil
        } else if points.count < 2 {
            let count = points.isEmpty ? String(localized: "Nenhum treino") : String(localized: "Só 1 treino")
            message = String(localized: "\(count) com este exercício \(period.phrase). Escolha um período maior para ver a evolução.")
            change = nil
        } else {
            message = nil
            change = Self.change(from: points[0].value, to: points[points.count - 1].value, metric: metric, period: period)
        }
    }

    /// Whether the chart itself is drawn (2 points or more in the period).
    var showsChart: Bool { message == nil }

    // MARK: - Axes

    /// The value of the axis at the bottom and at the top; for "Menor ajuda" the top is the lowest value.
    var lowest: Double { ticks.first ?? 0 }
    var highest: Double { ticks.last ?? 1 }

    /// A "round" step: 1, 2, 2,5 or 5 times a power of 10, at least `value`.
    static func niceStep(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return 1 }
        let power = pow(10, floor(log10(value)))
        let fraction = value / power
        let nice: Double = fraction <= 1 ? 1 : fraction <= 2 ? 2 : fraction <= 2.5 ? 2.5 : fraction <= 5 ? 5 : 10
        return nice * power
    }

    /// The horizontal lines: about 3 steps of a round size from below the lowest value to above the
    /// highest (3 to 5 lines). Equal values get room above and below.
    static func ticks(for values: [Double], metric: ExerciseMetric) -> [Double] {
        guard var low = values.min(), var high = values.max() else { return [] }
        if high == low {
            let room: Double = metric == .volume ? 100 : 2
            high += room
            low = max(0, low - room)
        }
        var step = niceStep((high - low) / 3)
        // Repetitions and volume are written as whole numbers: a step under 1 would repeat a label.
        if metric.isRepetitions || metric == .volume, step < 1 {
            step = 1
        }
        low = (low / step).rounded(.down) * step
        high = (high / step).rounded(.up) * step
        var ticks: [Double] = []
        var value = low
        while value <= high + 1e-9 {
            ticks.append((value * 100).rounded() / 100)
            value += step
        }
        return ticks
    }

    /// Where `day` falls between the start of the period and today, from 0 to 1.
    func fraction(of day: Date) -> Double {
        Self.fraction(of: day, start: start, end: end)
    }

    static func fraction(of day: Date, start: Date, end: Date) -> Double {
        day.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))
    }

    /// The months labeled below the chart: the first day of each month after the start, every other one
    /// with more than 7, and none closer than 24 to the one before or past the end of the plot, measured
    /// in the prototype's chart (340 wide, the plot from 6 to 298).
    static func monthLabels(start: Date, end: Date, calendar: Calendar) -> [Date] {
        guard let startMonth = calendar.dateInterval(of: .month, for: start)?.start,
              var month = calendar.date(byAdding: .month, value: 1, to: startMonth) else { return [] }
        var candidates: [Date] = []
        while month <= end {
            candidates.append(month)
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        let every = candidates.count > 7 ? 2 : 1
        var labels: [Date] = []
        var lastX = -99.0
        for (index, month) in candidates.enumerated() {
            let x = PrototypeChart.plotLeft + fraction(of: month, start: start, end: end) * (PrototypeChart.plotRight - PrototypeChart.plotLeft)
            guard index % every == 0, x - lastX >= 24, x <= PrototypeChart.plotRight - 8 else { continue }
            lastX = x
            labels.append(month)
        }
        return labels
    }

    // MARK: - Texts

    /// "▲ 12 kg nos últimos 3 meses"; for "Menor ajuda", "▲ 10 kg a menos de ajuda …"; "Igual …" when
    /// nothing changed. Worse is ▼ (in the help, more help).
    static func change(from first: Double, to last: Double, metric: ExerciseMetric, period: ExercisePeriod) -> Change {
        // Rounded as it is written: kg to 2 decimals, volume and repetitions to whole numbers, so a change too
        // small to write is "Igual", never "▲ 0 kg".
        let difference = metric == .maxLoad || metric == .leastHelp
            ? ((last - first) * 100).rounded() / 100
            : (last - first).rounded()
        if difference == 0 {
            return Change(text: String(localized: "Igual \(period.phrase)"), isWorse: false)
        }
        let isBetter = metric.isInverted ? difference < 0 : difference > 0
        var amount = ExerciseHistoryFormatting.valueText(abs(difference), metric: metric)
        if metric.isInverted {
            amount += difference < 0 ? String(localized: " a menos de ajuda") : String(localized: " a mais de ajuda")
        }
        return Change(text: "\(isBetter ? "▲" : "▼") \(amount) \(period.phrase)", isWorse: !isBetter)
    }

    /// What VoiceOver reads for the chart: "Maior carga: de 50 kg em qua, 22 abr a 62 kg em sex, 9 out".
    func accessibilitySummary(today: Date, calendar: Calendar) -> String? {
        guard let first = points.first, let last = points.last, showsChart else { return nil }
        let firstText = ExerciseHistoryFormatting.valueText(first.value, metric: metric)
        let lastText = ExerciseHistoryFormatting.valueText(last.value, metric: metric)
        let firstDate = ExerciseHistoryFormatting.dateText(first.startedAt, today: today, calendar: calendar)
        let lastDate = ExerciseHistoryFormatting.dateText(last.startedAt, today: today, calendar: calendar)
        return String(localized: "\(metric.title): de \(firstText) em \(firstDate) a \(lastText) em \(lastDate)")
    }
}

/// The prototype's chart, in its own units (an SVG 340 × 150), which the app's chart follows scaled to
/// its width.
enum PrototypeChart {
    static let width = 340.0
    static let height = 150.0
    static let plotLeft = 6.0
    static let plotRight = 298.0
    static let plotTop = 12.0
    static let plotBottom = 118.0
}

/// How the exercise screen writes values and dates. Pure logic.
enum ExerciseHistoryFormatting {
    private static let locale = Locale(identifier: "pt_BR")

    /// The number of a value: "62,5" (kg), "1.234" (volume, rounded), "12" (repetitions).
    static func number(_ value: Double, metric: ExerciseMetric) -> String {
        switch metric {
        case .volume:
            return Int(value.rounded()).formatted(.number.grouping(.automatic).locale(locale))
        case .maxReps, .totalReps:
            return Int(value.rounded()).formatted(.number.grouping(.never).locale(locale))
        case .maxLoad, .leastHelp:
            return kilograms(value)
        }
    }

    /// "62,5 kg", "1.234 kg", "12 reps".
    static func valueText(_ value: Double, metric: ExerciseMetric) -> String {
        "\(number(value, metric: metric)) \(metric.unit)"
    }

    /// A load with up to 2 decimals and a decimal comma: "62", "17,5".
    static func kilograms(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    /// A set: "62 kg × 10"; without a load, "12 reps"; a missing count of repetitions is "—".
    static func setText(_ record: ExerciseHistory.SetRecord) -> String {
        let reps = record.reps.map { String($0) } ?? "—"
        guard record.load > 0 else { return String(localized: "\(reps) reps") }
        return "\(kilograms(record.load)) kg × \(reps)"
    }

    /// "sex, 9 out"; another year adds the year: "sex, 9 out 2025".
    static func dateText(_ date: Date, today: Date, calendar: Calendar) -> String {
        SessionFormatting.weekdayDateText(date, now: today, calendar: calendar).lowercased(with: locale)
    }

    /// "24 treinos", "1 treino"; for Graviton, "24 treinos · kg é a ajuda".
    static func countText(_ count: Int, isAssisted: Bool) -> String {
        let text = count == 1 ? String(localized: "1 treino") : String(localized: "\(count) treinos")
        return isAssisted ? String(localized: "\(text) · kg é a ajuda") : text
    }
}
