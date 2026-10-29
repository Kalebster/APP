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

    /// A duration in the short form of the Treinos recent rows and today's finished workout: "55 min",
    /// "1 h", "1 h 02". Rounded to minutes and at least one, like `durationText`.
    static func compactDurationText(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((max(0, duration) / 60).rounded()))
        guard minutes >= 60 else { return String(localized: "\(minutes) min") }
        let hours = minutes / 60
        let rest = minutes % 60
        if rest == 0 {
            return String(localized: "\(hours) h")
        }
        return String(localized: "\(hours) h \(String(format: "%02ld", rest))")
    }

    /// "7 de outubro, 19:30"; the year is added for another year: "7 de outubro de 2025, 19:30".
    static func dateText(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let dayStyle = Date.FormatStyle.dateTime.day().month(.wide).locale(locale)
        let day = date.formatted(sameYear ? dayStyle : dayStyle.year())
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
        return "\(day), \(time)"
    }

    /// "30 set": the day and the abbreviated month without a period; the year is added for another
    /// year: "30 set 2025". The day, month and year are those of `calendar`.
    static func shortDateText(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let day = calendar.component(.day, from: date)
        let month = monthAbbreviation(calendar.component(.month, from: date))
        let year = calendar.component(.year, from: date)
        if year == calendar.component(.year, from: now) {
            return "\(day) \(month)"
        }
        return "\(day) \(month) \(year)"
    }

    /// "Qui, 15 out": the abbreviated weekday, the day and the abbreviated month; the year is added for
    /// another year: "Qui, 15 out 2025". The day, month and year are those of `calendar`.
    static func weekdayDateText(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let name = weekdayAbbreviations.indices.contains(weekday - 1) ? weekdayAbbreviations[weekday - 1] : ""
        return "\(name), \(shortDateText(date, now: now, calendar: calendar))"
    }

    /// "sexta-feira, 16 de outubro", in the time zone of `calendar`: what VoiceOver reads for a date.
    static func longDateText(_ date: Date, calendar: Calendar = .current) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide).locale(locale)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    /// The time of day with two digits for the hour and the minute, on a 24-hour clock: "00:42", "19:30".
    static func timeText(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02ld:%02ld", hour, minute)
    }

    /// The question asked when a session left open is finished, with the time of its last record
    /// and, when that was not today, the day: "ontem" or the date as `shortDateText` shows it.
    static func lastRecordQuestion(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = timeText(date, calendar: calendar)
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "Seu último registro foi às \(time). Usar esse horário como fim?")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Seu último registro foi ontem às \(time). Usar esse horário como fim?")
        }
        let day = shortDateText(date, now: now, calendar: calendar)
        return String(localized: "Seu último registro foi em \(day) às \(time). Usar esse horário como fim?")
    }

    /// What VoiceOver reads for a recent session, as one sentence: "Push, 4 de outubro, 19:30, 45 min".
    static func recentAccessibilityText(name: String, startedAt: Date, duration: TimeInterval?, now: Date = .now, calendar: Calendar = .current) -> String {
        var parts = [name, dateText(startedAt, now: now, calendar: calendar)]
        if let duration {
            parts.append(durationText(duration))
        }
        return parts.joined(separator: ", ")
    }

    /// A finished session's summary: "45 min · 2 exercícios · 6 séries". Only completed sets count,
    /// and an exercise counts when at least one of its sets was completed.
    static func summaryText(duration: TimeInterval?, exercises: Int, sets: Int) -> String {
        var parts: [String] = []
        if let duration {
            parts.append(durationText(duration))
        }
        // The catalog gives the singular and plural forms.
        parts.append(String(localized: "\(exercises) exercícios"))
        parts.append(String(localized: "\(sets) séries"))
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

    /// The values recorded when a set is checked: what is typed (or already stored), and the
    /// suggestion for a field left empty. The repetitions stay `nil` when there is neither, and the set
    /// cannot be checked.
    static func completionValues(typed: SetValues, suggestion: SetSuggestion) -> SetValues {
        SetValues(weightKg: typed.weightKg ?? suggestion.weightKg, reps: typed.reps ?? suggestion.reps)
    }

    /// The load lifted in the session, rounded to the kilogram: "2.440 kg levantados".
    static func volumeText(_ volumeKg: Double) -> String {
        String(localized: "\(kilogramsText(volumeKg)) kg levantados")
    }

    /// The load lifted as a number, rounded to the kilogram: "2.440".
    static func kilogramsText(_ volumeKg: Double) -> String {
        Int(max(0, volumeKg).rounded()).formatted(.number.grouping(.automatic).locale(locale))
    }

    /// A duration as VoiceOver reads it, rounded to minutes like `durationText`: "42 minutos",
    /// "1 hora", "1 hora e 5 minutos".
    static func spokenDurationText(_ duration: TimeInterval) -> String {
        func minutesText(_ count: Int) -> String {
            count == 1 ? String(localized: "1 minuto") : String(localized: "\(count) minutos")
        }
        let minutes = max(1, Int((max(0, duration) / 60).rounded()))
        guard minutes >= 60 else { return minutesText(minutes) }
        let hours = minutes / 60
        let hoursText = hours == 1 ? String(localized: "1 hora") : String(localized: "\(hours) horas")
        let rest = minutes % 60
        return rest == 0 ? hoursText : String(localized: "\(hoursText) e \(minutesText(rest))")
    }

    /// The rest time left, rounded up to the second: "1:30", "0:05", "0:00".
    static func restText(_ remaining: TimeInterval) -> String {
        let seconds = Int(max(0, remaining).rounded(.up))
        return String(format: "%ld:%02ld", seconds / 60, seconds % 60)
    }

    // MARK: - Private

    /// The abbreviated months in lowercase and without the period ("set"), January first. Read once:
    /// the names depend only on the fixed locale, never on the time zone, which comes from the
    /// calendar each caller passes.
    private static let monthAbbreviations: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.shortMonthSymbols.map { $0.replacingOccurrences(of: ".", with: "").lowercased(with: locale) }
    }()

    /// The abbreviated weekdays with a capital letter and without the period ("Qui"), Sunday first, as
    /// `Calendar` numbers them. Read once, like the months.
    private static let weekdayAbbreviations: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.shortWeekdaySymbols.map { symbol in
            let name = symbol.replacingOccurrences(of: ".", with: "")
            return name.prefix(1).uppercased(with: locale) + name.dropFirst()
        }
    }()

    /// The abbreviated month ("set"), from 1 for January.
    static func monthAbbreviation(_ month: Int) -> String {
        monthAbbreviations.indices.contains(month - 1) ? monthAbbreviations[month - 1] : ""
    }

    /// The whole name of `month` (1 = January), in lowercase: "maio", "outubro"; empty for no month.
    static func monthName(_ month: Int) -> String {
        monthNames.indices.contains(month - 1) ? monthNames[month - 1] : ""
    }

    private static let monthNames: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.standaloneMonthSymbols.map { $0.lowercased(with: locale) }
    }()
}
