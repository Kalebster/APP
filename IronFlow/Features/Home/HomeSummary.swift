import Foundation

/// An indicator that can be shown in the Home "Resumo rápido".
enum SummaryMetric: String, CaseIterable, Identifiable, Sendable {
    case bodyWeight
    case height
    case dailyCalorieGoal

    var id: String { rawValue }

    /// The full name: in Personalizar and for VoiceOver.
    var title: LocalizedStringResource {
        switch self {
        case .bodyWeight: "Peso corporal"
        case .height: "Altura"
        case .dailyCalorieGoal: "Meta diária"
        }
    }

    /// The short name under the value of a summary card.
    var cardTitle: LocalizedStringResource {
        switch self {
        case .bodyWeight: "Peso"
        case .height: "Altura"
        case .dailyCalorieGoal: "kcal / dia"
        }
    }

    var systemImage: String {
        switch self {
        case .bodyWeight: "scalemass"
        case .height: "ruler"
        case .dailyCalorieGoal: "flame"
        }
    }

    /// The body data value the indicator shows, which its card edits.
    var bodyMetric: BodyMetric {
        switch self {
        case .bodyWeight: .bodyWeight
        case .height: .height
        case .dailyCalorieGoal: .dailyCalorieGoal
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

    /// A number in the Brazilian format, with up to two decimals: "20", "8.000", "80,5", "80,25".
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    /// A value as a summary card shows it: the number large and the unit small beside it ("80" and
    /// "kg", "180" and "cm"); the calorie goal has no unit there, its card's name says "kcal / dia".
    static func cardValue(of metric: SummaryMetric, value: Double) -> (number: String, unit: String?) {
        switch metric {
        // The number of `weightText`: up to two decimals with a comma.
        case .bodyWeight: (value.formatted(.number.precision(.fractionLength(0...2)).locale(locale)), "kg")
        case .height: (Int(value).formatted(.number.locale(locale)), "cm")
        case .dailyCalorieGoal: (Int(value).formatted(.number.locale(locale)), nil)
        }
    }

    /// The value as the editor's field shows it ("80,5", "180", "2.300"); empty when there is none.
    static func fieldText(_ value: Double?, for metric: BodyMetric) -> String {
        guard let value else { return "" }
        switch metric {
        case .bodyWeight: return PlannedSetFormatting.weightFieldText(value)
        case .height: return Int(value.rounded()).formatted(.number.grouping(.never).locale(locale))
        case .dailyCalorieGoal: return Int(value.rounded()).formatted(.number.locale(locale))
        }
    }

    /// Reads and checks a typed value for `metric`. Returns `nil` for an empty field; throws the
    /// metric's validation error for anything that is not an allowed value, and `tooManyDecimals` for
    /// a weight with three or more decimals ("80,500"), never read as another number.
    static func value(for metric: BodyMetric, text: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch metric {
        case .bodyWeight:
            let weightKg: Double
            do {
                // The same reading as every field of kilograms (decimal comma or dot).
                guard let typed = try PlannedSetFormatting.weightKg(trimmed) else { return nil }
                weightKg = typed
            } catch ValidationError.tooManyDecimals {
                throw ValidationError.tooManyDecimals
            } catch {
                throw ValidationError.invalidBodyWeight
            }
            try Validation.bodyWeight(weightKg)
            return weightKg
        case .height:
            guard let heightCm = PlannedSetFormatting.reps(trimmed) else { throw ValidationError.invalidHeight }
            try Validation.height(heightCm)
            return Double(heightCm)
        case .dailyCalorieGoal:
            guard let kcal = wholeNumber(trimmed) else { throw ValidationError.invalidCalorieGoal }
            try Validation.dailyCalorieGoal(kcal)
            return Double(kcal)
        }
    }

    /// The number a field of `metric` holds, read without checking its limits, for − and + to start
    /// from; `nil` when the field is empty or cannot be read.
    static func typedNumber(_ text: String, for metric: BodyMetric) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch metric {
        case .bodyWeight: return try? PlannedSetFormatting.weightKg(trimmed)
        case .height: return PlannedSetFormatting.reps(trimmed).map(Double.init)
        case .dailyCalorieGoal: return wholeNumber(trimmed).map(Double.init)
        }
    }

    /// A whole number typed with or without the dots of the thousands ("2300", "2.300"); `nil` for
    /// anything else, such as a dot out of place ("2.30").
    static func wholeNumber(_ text: String) -> Int? {
        if let plain = PlannedSetFormatting.reps(text) {
            return plain
        }
        let groups = text.split(separator: ".", omittingEmptySubsequences: false)
        guard groups.count > 1,
              let first = groups.first, (1...3).contains(first.count),
              groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return nil }
        return PlannedSetFormatting.reps(groups.joined())
    }

    // MARK: - Body weight records

    /// A body weight record of the editor's "ÚLTIMOS REGISTROS".
    struct WeightRecordRow: Equatable, Identifiable {
        let id: UUID
        /// "Ter, 14 out".
        let dateText: String
        /// "80 kg", "80,6 kg".
        let valueText: String
        /// The change from the record below it, with its sign: "−0,6", "+0,4", "0"; `nil` for the last
        /// (oldest) record of the list.
        let changeText: String?
    }

    /// The rows of `entries`, the newest first as they come. Each shows its change from the next
    /// (older) one; the oldest of the list shows none.
    static func weightRecordRows(_ entries: [BodyWeightEntry], now: Date, calendar: Calendar) -> [WeightRecordRow] {
        entries.indices.map { index in
            let entry = entries[index]
            let older = entries.indices.contains(index + 1) ? entries[index + 1] : nil
            return WeightRecordRow(
                id: entry.id,
                dateText: SessionFormatting.weekdayDateText(entry.measuredAt, now: now, calendar: calendar),
                valueText: weightText(entry.weightKg),
                changeText: older.map { signedNumber(entry.weightKg - $0.weightKg) }
            )
        }
    }

    /// A change with its sign and the typographic minus: "−0,6", "+1,25", "0". Rounded to hundredths,
    /// so the remainder of binary arithmetic never shows.
    static func signedNumber(_ value: Double) -> String {
        let hundredths = (value * 100).rounded()
        guard hundredths != 0 else { return "0" }
        let text = number(abs(hundredths) / 100)
        return hundredths < 0 ? "\u{2212}\(text)" : "+\(text)"
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
    /// A workout is planned for today in the weekly plan and was not finished today.
    case scheduled(workoutID: UUID, name: String)
    /// The workout planned for today was finished today; `duration` is that of its latest session.
    case scheduledCompleted(name: String, duration: TimeInterval?)
    /// No planned workout exists yet.
    case noWorkouts
    /// Workouts exist, but none is planned for today.
    case nothingPlanned

    /// The in-progress session comes first. Should the store hold more than one, it is the one
    /// "Continuar" opens: the most recently started, then the most recently created
    /// (`SessionService.activeSessionsDescriptor`).
    ///
    /// Then the workout planned for today, if it exists (`scheduled`, nil when the day is a rest day
    /// or its workout was deleted): finished today when a finished session of that workout started
    /// today in `calendar` (`finishedSessions` may hold any sessions; only those count), otherwise
    /// still to do. Without it, whether workouts exist.
    static func resolve(
        activeSessions: [Session],
        hasWorkouts: Bool,
        scheduled: Workout? = nil,
        finishedSessions: [Session] = [],
        now: Date = .now,
        calendar: Calendar = TrainingDay.calendar
    ) -> TodayWorkoutState {
        if let session = activeSessions.max(by: { ($0.startedAt, $0.createdAt) < ($1.startedAt, $1.createdAt) }) {
            return .inProgress(name: session.workoutNameSnapshot, startedAt: session.startedAt)
        }
        if let scheduled {
            let today = TrainingDay.key(for: now, calendar: calendar)
            let finishedToday = finishedSessions.filter { session in
                session.endedAt != nil
                    && session.workout?.id == scheduled.id
                    && TrainingDay.key(for: session.startedAt, calendar: calendar) == today
            }
            guard let latest = finishedToday.max(by: { ($0.startedAt, $0.createdAt) < ($1.startedAt, $1.createdAt) }) else {
                return .scheduled(workoutID: scheduled.id, name: scheduled.name)
            }
            return .scheduledCompleted(name: scheduled.name, duration: latest.duration)
        }
        return hasWorkouts ? .nothingPlanned : .noWorkouts
    }
}

/// An action of the "Treino de hoje" card.
enum TodayWorkoutAction: Hashable {
    /// Opens the session in progress.
    case continueSession
    /// Starts the workout planned for today.
    case startScheduledWorkout
    /// Chooses a planned workout and starts it.
    case chooseWorkout
    /// Starts a workout without a plan.
    case startFreeWorkout
}

extension TodayWorkoutState {
    /// The card's main action, a white button; `nil` once the planned workout was finished today,
    /// when both actions are secondary.
    var mainAction: TodayWorkoutAction? {
        if case .scheduledCompleted = self { return nil }
        return actions.first
    }

    /// The actions under the main one, as outlined buttons.
    var secondaryActions: [TodayWorkoutAction] {
        mainAction == nil ? actions : Array(actions.dropFirst())
    }

    /// The card's actions, the main one first. A session in progress can only be continued; the
    /// workout planned for today is started first, unless it was already finished today; choosing a
    /// workout needs at least one.
    var actions: [TodayWorkoutAction] {
        switch self {
        case .inProgress: [.continueSession]
        case .scheduled: [.startScheduledWorkout, .chooseWorkout, .startFreeWorkout]
        case .scheduledCompleted: [.chooseWorkout, .startFreeWorkout]
        case .noWorkouts: [.startFreeWorkout]
        case .nothingPlanned: [.chooseWorkout, .startFreeWorkout]
        }
    }
}

/// What the "Treino de hoje" block says in each state: the badge, the title, the line under it, the
/// muscle group chips and what VoiceOver reads for all of it.
struct TodayWorkoutContent: Equatable {
    /// "Programado", "Em andamento", "Concluído" or, on a rest day, "Livre"; none without workouts.
    let badge: String?
    let title: String
    let subtitle: String
    /// The muscle groups of the planned workout, shown as chips; empty in the other states.
    let chips: [String]
    let accessibilityText: String

    /// The content for `state`. `summary` ("4 exercícios · 12 séries") and `muscleGroups` describe the
    /// workout planned for today.
    init(
        state: TodayWorkoutState,
        summary: String = "",
        muscleGroups: [String] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        switch state {
        case .inProgress(let name, let startedAt):
            let title = name.isEmpty ? String(localized: "Treino livre") : name
            let started = HomeSummary.startedText(startedAt, now: now, calendar: calendar)
            badge = String(localized: "Em andamento")
            self.title = title
            subtitle = started
            chips = []
            accessibilityText = [String(localized: "Treino em andamento"), title, started].joined(separator: ", ")
        case .scheduled(_, let name):
            badge = String(localized: "Programado")
            title = name
            subtitle = summary
            chips = muscleGroups
            let groups = muscleGroups.joined(separator: " · ")
            accessibilityText = ([name, String(localized: "programado para hoje"), summary] + (groups.isEmpty ? [] : [groups]))
                .joined(separator: ", ")
        case .scheduledCompleted(let name, let duration):
            badge = String(localized: "Concluído")
            title = name
            subtitle = duration.map { String(localized: "Concluído hoje · \(SessionFormatting.compactDurationText($0))") }
                ?? String(localized: "Concluído hoje")
            chips = []
            let finished = String(localized: "\(name) concluído hoje")
            accessibilityText = duration.map { "\(finished), \(SessionFormatting.durationText($0))" } ?? finished
        case .noWorkouts:
            badge = nil
            title = String(localized: "Nenhum treino criado")
            subtitle = String(localized: "Crie um treino na aba Treinos ou comece um treino livre.")
            chips = []
            accessibilityText = "\(title). \(subtitle)"
        case .nothingPlanned:
            badge = String(localized: "Livre")
            title = String(localized: "Descanso hoje")
            subtitle = String(localized: "Nada programado para hoje. Quer treinar mesmo assim?")
            chips = []
            accessibilityText = "\(title). \(subtitle)"
        }
    }
}
