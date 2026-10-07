import Foundation

/// An indicator that can be shown in the Home "Resumo rápido".
enum SummaryMetric: String, CaseIterable, Identifiable, Sendable {
    case bodyWeight
    case height
    case dailyCalorieGoal

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .bodyWeight: "Peso corporal"
        case .height: "Altura"
        case .dailyCalorieGoal: "Meta diária"
        }
    }

    var systemImage: String {
        switch self {
        case .bodyWeight: "scalemass"
        case .height: "ruler"
        case .dailyCalorieGoal: "flame"
        }
    }
}

/// The Home quick summary: which indicators are shown, how values are shown and how typed
/// values are read. Pure logic: no UI and no store access.
enum HomeSummary {
    static let maxVisibleMetrics = 3
    static let defaultMetrics: [SummaryMetric] = [.bodyWeight, .height, .dailyCalorieGoal]
    /// Key of the saved choice of indicators in the app preferences.
    static let metricsPreferenceKey = "home.summaryMetrics"
    /// The saved form of an explicit choice of no indicators.
    static let noMetricsStoredValue = "none"

    /// The indicators to show for a saved choice. `noMetricsStoredValue` shows none. Unknown and
    /// repeated entries are ignored and at most `maxVisibleMetrics` are kept; a value with no known
    /// indicator (never chosen, empty or invalid) shows the defaults.
    static func metrics(fromStored stored: String?) -> [SummaryMetric] {
        guard let stored else { return defaultMetrics }
        guard stored != noMetricsStoredValue else { return [] }
        var metrics: [SummaryMetric] = []
        for rawValue in stored.split(separator: ",") {
            if let metric = SummaryMetric(rawValue: String(rawValue)), !metrics.contains(metric) {
                metrics.append(metric)
            }
        }
        return metrics.isEmpty ? defaultMetrics : Array(metrics.prefix(maxVisibleMetrics))
    }

    /// The saved form of a choice of indicators; `noMetricsStoredValue` when none is chosen.
    static func storedValue(for metrics: [SummaryMetric]) -> String {
        metrics.isEmpty ? noMetricsStoredValue : metrics.map(\.rawValue).joined(separator: ",")
    }

    /// Removes the indicator when it is shown; otherwise adds it last, if there is room.
    static func toggled(_ metric: SummaryMetric, in metrics: [SummaryMetric]) -> [SummaryMetric] {
        if metrics.contains(metric) {
            return metrics.filter { $0 != metric }
        }
        guard metrics.count < maxVisibleMetrics else { return metrics }
        return metrics + [metric]
    }

    // MARK: - Values

    /// The app is in Brazilian Portuguese only: decimal comma, dot for thousands, 24-hour clock.
    private static let locale = Locale(identifier: "pt_BR")

    /// "80 kg", "80,5 kg": the same format as a planned load.
    static func weightText(_ weightKg: Double) -> String {
        PlannedSetFormatting.weightText(weightKg)
    }

    /// "180 cm".
    static func heightText(_ heightCm: Int) -> String {
        "\(heightCm.formatted(.number.locale(locale))) cm"
    }

    /// "2.300 kcal".
    static func calorieText(_ kcal: Int) -> String {
        "\(kcal.formatted(.number.locale(locale))) kcal"
    }

    /// The value as it is typed in the editor ("80,5", "180", "2300"); empty when there is none.
    static func fieldText(_ value: Double?) -> String {
        PlannedSetFormatting.weightFieldText(value)
    }

    /// Reads and checks a typed value for `metric`. Returns `nil` for an empty field; throws the
    /// metric's validation error for anything that is not an allowed value.
    static func value(for metric: SummaryMetric, text: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch metric {
        case .bodyWeight:
            // The same number reading as the load of a planned set (decimal comma or dot).
            guard let weightKg = try? PlannedSetFormatting.weightKg(trimmed) else { throw ValidationError.invalidBodyWeight }
            try Validation.bodyWeight(weightKg)
            return weightKg
        case .height:
            guard let heightCm = PlannedSetFormatting.reps(trimmed) else { throw ValidationError.invalidHeight }
            try Validation.height(heightCm)
            return Double(heightCm)
        case .dailyCalorieGoal:
            guard let kcal = PlannedSetFormatting.reps(trimmed) else { throw ValidationError.invalidCalorieGoal }
            try Validation.dailyCalorieGoal(kcal)
            return Double(kcal)
        }
    }

    // MARK: - Today's workout

    /// "Iniciado às 19:30" for a session started today; otherwise the day comes first,
    /// so a session left open on another day does not read as today's.
    static func startedText(_ startedAt: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = startedAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
        guard !calendar.isDate(startedAt, inSameDayAs: now) else {
            return String(localized: "Iniciado às \(time)")
        }
        let day = startedAt.formatted(.dateTime.day().month(.wide).locale(locale))
        return String(localized: "Iniciado em \(day), às \(time)")
    }
}

/// What the Home "Treino de hoje" card shows.
enum TodayWorkoutState: Equatable {
    /// A session is in progress.
    case inProgress(name: String, startedAt: Date)
    /// No planned workout exists yet.
    case noWorkouts
    /// Workouts exist, but none is planned for today.
    case nothingPlanned

    /// The in-progress session (the most recent, should the store hold more than one) comes first.
    static func resolve(activeSessions: [Session], hasWorkouts: Bool) -> TodayWorkoutState {
        if let session = activeSessions.max(by: { $0.startedAt < $1.startedAt }) {
            return .inProgress(name: session.workoutNameSnapshot, startedAt: session.startedAt)
        }
        return hasWorkouts ? .nothingPlanned : .noWorkouts
    }
}
