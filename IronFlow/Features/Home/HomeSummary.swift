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

    /// The indicators to show for a saved choice. `nil` (never chosen) shows the defaults;
    /// unknown or repeated entries are ignored, and at most `maxVisibleMetrics` are kept.
    static func metrics(fromStored stored: String?) -> [SummaryMetric] {
        guard let stored else { return defaultMetrics }
        var metrics: [SummaryMetric] = []
        for rawValue in stored.split(separator: ",") {
            if let metric = SummaryMetric(rawValue: String(rawValue)), !metrics.contains(metric) {
                metrics.append(metric)
            }
        }
        return Array(metrics.prefix(maxVisibleMetrics))
    }

    /// The saved form of a choice of indicators.
    static func storedValue(for metrics: [SummaryMetric]) -> String {
        metrics.map(\.rawValue).joined(separator: ",")
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

    /// The app is in Brazilian Portuguese only: decimal comma, dot for thousands.
    private static let locale = Locale(identifier: "pt_BR")

    /// "80 kg", "80,5 kg".
    static func weightText(_ weightKg: Double) -> String {
        "\(weightKg.formatted(.number.precision(.fractionLength(0...2)).locale(locale))) kg"
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
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
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
            guard let heightCm = wholeNumber(trimmed) else { throw ValidationError.invalidHeight }
            try Validation.height(heightCm)
            return Double(heightCm)
        case .dailyCalorieGoal:
            guard let kcal = wholeNumber(trimmed) else { throw ValidationError.invalidCalorieGoal }
            try Validation.dailyCalorieGoal(kcal)
            return Double(kcal)
        }
    }

    /// Digits only; a number too large to store is read as `Int.max`, so it is out of range.
    private static func wholeNumber(_ text: String) -> Int? {
        guard text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(text) ?? Int.max
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
