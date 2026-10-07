import Foundation

/// What is typed in a set row of the session: load and repetitions, as text.
struct SetDraft: Equatable, Sendable {
    var weight: String
    var reps: String
}

/// The values read from a `SetDraft`.
struct SetValues: Equatable, Sendable {
    var weightKg: Double?
    var reps: Int?
}

/// How sessions are shown, and how the values typed during a session are read.
/// Pure logic: no UI and no store access.
enum SessionFormatting {
    /// The app is in Brazilian Portuguese only: decimal comma, 24-hour clock.
    private static let locale = Locale(identifier: "pt_BR")

    /// The session's name; a session without a planned workout is a "Treino livre".
    static func name(_ workoutNameSnapshot: String) -> String {
        workoutNameSnapshot.isEmpty ? String(localized: "Treino livre") : workoutNameSnapshot
    }

    /// Time since the start: "04:09", or "1:02:03" from one hour on.
    static func elapsedText(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let hours = seconds / 3_600
        let minutes = seconds % 3_600 / 60
        let rest = seconds % 60
        if hours > 0 {
            return String(format: "%ld:%02ld:%02ld", hours, minutes, rest)
        }
        return String(format: "%02ld:%02ld", minutes, rest)
    }

    /// A finished session's duration, rounded to minutes and at least one: "45 min", "1 h", "1 h 05 min".
    static func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((max(0, duration) / 60).rounded()))
        guard minutes >= 60 else { return String(localized: "\(minutes) min") }
        let hours = minutes / 60
        let rest = minutes % 60
        if rest == 0 {
            return String(localized: "\(hours) h")
        }
        return String(localized: "\(hours) h \(String(format: "%02ld", rest)) min")
    }

    /// "7 de outubro, 19:30"; the year is added for another year: "7 de outubro de 2025, 19:30".
    static func dateText(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let dayStyle = Date.FormatStyle.dateTime.day().month(.wide).locale(locale)
        let day = date.formatted(sameYear ? dayStyle : dayStyle.year())
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().locale(locale))
        return "\(day), \(time)"
    }

    /// A finished session's summary: "45 min · 2 exercícios · 6 séries". Only completed sets count,
    /// and an exercise counts when at least one of its sets was completed.
    static func summaryText(duration: TimeInterval?, exercises: Int, sets: Int) -> String {
        var parts: [String] = []
        if let duration {
            parts.append(durationText(duration))
        }
        parts.append(exercises == 1 ? String(localized: "1 exercício") : String(localized: "\(exercises) exercícios"))
        parts.append(sets == 1 ? String(localized: "1 série") : String(localized: "\(sets) séries"))
        return parts.joined(separator: " · ")
    }

    /// The target repetitions of a set: "8–12", "10", or `nil` when the set has no target.
    static func targetText(min: Int?, max: Int?) -> String? {
        switch (min, max) {
        case let (min?, max?): min == max ? "\(max)" : "\(min)–\(max)"
        case let (min?, nil): "\(min)"
        case let (nil, max?): "\(max)"
        case (nil, nil): nil
        }
    }

    /// The stored values of a set, as they are typed.
    static func draft(weightKg: Double?, reps: Int?) -> SetDraft {
        SetDraft(weight: PlannedSetFormatting.weightFieldText(weightKg), reps: reps.map { String($0) } ?? "")
    }

    /// Reads a draft. Empty fields have no value. The load and the repetitions are read like the
    /// planned ones (decimal comma or dot; whole repetitions); range rules are checked by the service.
    /// Repetitions that are not a whole number, or too large to store, throw
    /// `PlannedSetInputError.repsRequired`.
    static func values(of draft: SetDraft) throws -> SetValues {
        let weightKg = try PlannedSetFormatting.weightKg(draft.weight)
        guard !draft.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SetValues(weightKg: weightKg, reps: nil)
        }
        guard let reps = PlannedSetFormatting.reps(draft.reps), reps != Int.max else {
            throw PlannedSetInputError.repsRequired
        }
        return SetValues(weightKg: weightKg, reps: reps)
    }

    /// The repetitions recorded when a set is checked: the typed ones, or else the target
    /// (the maximum of a range). `nil` when there is neither.
    static func repsForCompletion(typed: Int?, targetMin: Int?, targetMax: Int?) -> Int? {
        typed ?? targetMax ?? targetMin
    }
}
