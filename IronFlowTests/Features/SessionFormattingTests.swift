import Foundation
import Testing
@testable import IronFlow

struct SessionFormattingTests {
    @Test("A session without a planned workout is a free workout")
    func names() {
        #expect(SessionFormatting.name("Push") == "Push")
        #expect(SessionFormatting.name("") == "Treino livre")
    }

    @Test("Elapsed time: minutes and seconds, then hours")
    func elapsed() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        #expect(SessionFormatting.elapsedText(from: start, to: start) == "00:00")
        #expect(SessionFormatting.elapsedText(from: start, to: start.addingTimeInterval(249)) == "04:09")
        #expect(SessionFormatting.elapsedText(from: start, to: start.addingTimeInterval(3_723)) == "1:02:03")
        // A clock set back never shows negative time.
        #expect(SessionFormatting.elapsedText(from: start, to: start.addingTimeInterval(-30)) == "00:00")
    }

    @Test("Duration: whole minutes, at least one, then hours")
    func duration() {
        #expect(SessionFormatting.durationText(10) == "1 min")
        #expect(SessionFormatting.durationText(45 * 60) == "45 min")
        #expect(SessionFormatting.durationText(60 * 60) == "1 h")
        #expect(SessionFormatting.durationText(65 * 60) == "1 h 05 min")
    }

    @Test("Date and time in Brazilian Portuguese, with the year only for another year")
    func date() throws {
        let calendar = Calendar.current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 19, minute: 30)))
        let sameYear = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let nextYear = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 2)))
        #expect(SessionFormatting.dateText(date, now: sameYear, calendar: calendar) == "4 de outubro, 19:30")
        #expect(SessionFormatting.dateText(date, now: nextYear, calendar: calendar) == "4 de outubro de 2026, 19:30")
        let early = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 7, minute: 5)))
        #expect(SessionFormatting.dateText(early, now: sameYear, calendar: calendar) == "4 de outubro, 07:05")
    }

    /// A Gregorian calendar in São Paulo, so the day and the time do not depend on where the tests run.
    private func saoPauloCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar
    }

    @Test("The short date is the day and the abbreviated month without a period, with the year only for another year")
    func shortDate() throws {
        let calendar = try saoPauloCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 0, minute: 42)))
        let singleDigit = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 9)))
        let lastYear = try #require(calendar.date(from: DateComponents(year: 2025, month: 9, day: 30, hour: 18)))

        #expect(SessionFormatting.shortDateText(date, now: now, calendar: calendar) == "30 set")
        #expect(SessionFormatting.shortDateText(singleDigit, now: now, calendar: calendar) == "5 out")
        #expect(SessionFormatting.shortDateText(lastYear, now: now, calendar: calendar) == "30 set 2025")
        // The year is the one of the calendar: the first minute of the new year is already the new year.
        let newYear = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 0, minute: 1)))
        #expect(SessionFormatting.shortDateText(newYear, now: now, calendar: calendar) == "1 jan 2027")
    }

    @Test("All twelve months are abbreviated in Portuguese, in lowercase and without a period")
    func monthAbbreviations() throws {
        let calendar = try saoPauloCalendar()
        let names = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
        for (index, name) in names.enumerated() {
            let date = try #require(calendar.date(from: DateComponents(year: 2026, month: index + 1, day: 15, hour: 12)))
            #expect(SessionFormatting.shortDateText(date, now: date, calendar: calendar) == "15 \(name)")
        }
    }

    @Test("The time of day has two digits for the hour and the minute")
    func timeOfDay() throws {
        let calendar = try saoPauloCalendar()
        func time(_ hour: Int, _ minute: Int) throws -> String {
            let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour, minute: minute)))
            return SessionFormatting.timeText(date, calendar: calendar)
        }
        #expect(try time(0, 42) == "00:42")
        #expect(try time(7, 5) == "07:05")
        #expect(try time(19, 30) == "19:30")
        #expect(try time(23, 59) == "23:59")
    }

    @Test("The day and the time are those of the calendar's time zone")
    func timeZone() throws {
        let saoPaulo = try saoPauloCalendar()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        // 23:50 on September 30th in São Paulo is 02:50 on October 1st in UTC.
        let date = try #require(saoPaulo.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 50)))
        let now = try #require(saoPaulo.date(from: DateComponents(year: 2026, month: 10, day: 20)))

        #expect(SessionFormatting.shortDateText(date, now: now, calendar: saoPaulo) == "30 set")
        #expect(SessionFormatting.timeText(date, calendar: saoPaulo) == "23:50")
        #expect(SessionFormatting.shortDateText(date, now: now, calendar: utc) == "1 out")
        #expect(SessionFormatting.timeText(date, calendar: utc) == "02:50")
    }

    @Test("A recent session's day: the abbreviated weekday with a capital letter, the day and the month; the year only for another year")
    func weekdayDate() throws {
        let calendar = try saoPauloCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19)))
        // Monday the 12th to Sunday the 18th of October 2026.
        let names = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
        for (offset, name) in names.enumerated() {
            let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12 + offset, hour: 19, minute: 30)))
            #expect(SessionFormatting.weekdayDateText(date, now: now, calendar: calendar) == "\(name), \(12 + offset) out")
        }
        let lastYear = try #require(calendar.date(from: DateComponents(year: 2025, month: 10, day: 15, hour: 8)))
        #expect(SessionFormatting.weekdayDateText(lastYear, now: now, calendar: calendar) == "Qua, 15 out 2025")
        // The day is the one of the calendar's time zone: 23:50 in São Paulo is already Friday in UTC.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        let late = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 23, minute: 50)))
        #expect(SessionFormatting.weekdayDateText(late, now: now, calendar: calendar) == "Qui, 15 out")
        #expect(SessionFormatting.weekdayDateText(late, now: now, calendar: utc) == "Sex, 16 out")
        #expect(SessionFormatting.longDateText(late, calendar: calendar) == "quinta-feira, 15 de outubro")
    }

    @Test("The short duration: minutes, then hours with two-digit minutes and no unit after them")
    func compactDuration() {
        #expect(SessionFormatting.compactDurationText(0) == "1 min")
        #expect(SessionFormatting.compactDurationText(55 * 60) == "55 min")
        #expect(SessionFormatting.compactDurationText(59 * 60 + 40) == "1 h")
        #expect(SessionFormatting.compactDurationText(60 * 60) == "1 h")
        #expect(SessionFormatting.compactDurationText(62 * 60) == "1 h 02")
        #expect(SessionFormatting.compactDurationText(135 * 60) == "2 h 15")
        // The long form, in the history, keeps the unit.
        #expect(SessionFormatting.durationText(62 * 60) == "1 h 02 min")
    }

    @Test("The question about a session left open names the day only when the last record was not today")
    func lastRecordQuestion() throws {
        let calendar = try saoPauloCalendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 8, minute: 15)))
        func record(day: Int, hour: Int, minute: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
        }

        // The same day, a few minutes after midnight included.
        #expect(SessionFormatting.lastRecordQuestion(try record(day: 19, hour: 6, minute: 5), now: now, calendar: calendar)
            == "Seu último registro foi às 06:05. Usar esse horário como fim?")
        #expect(SessionFormatting.lastRecordQuestion(try record(day: 19, hour: 0, minute: 1), now: now, calendar: calendar)
            == "Seu último registro foi às 00:01. Usar esse horário como fim?")
        // The day before, up to its last minute.
        #expect(SessionFormatting.lastRecordQuestion(try record(day: 18, hour: 20, minute: 0), now: now, calendar: calendar)
            == "Seu último registro foi ontem às 20:00. Usar esse horário como fim?")
        #expect(SessionFormatting.lastRecordQuestion(try record(day: 18, hour: 23, minute: 59), now: now, calendar: calendar)
            == "Seu último registro foi ontem às 23:59. Usar esse horário como fim?")
        // Earlier: the date as the short date shows it.
        #expect(SessionFormatting.lastRecordQuestion(try record(day: 17, hour: 20, minute: 0), now: now, calendar: calendar)
            == "Seu último registro foi em 17 out às 20:00. Usar esse horário como fim?")
    }

    @Test("The day of the question is that of the calendar's time zone")
    func lastRecordQuestionTimeZone() throws {
        let saoPaulo = try saoPauloCalendar()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        // 22:30 on the 18th in São Paulo is 01:30 on the 19th in UTC; now is 08:15 on the 19th in São Paulo.
        let record = try #require(saoPaulo.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 22, minute: 30)))
        let now = try #require(saoPaulo.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 8, minute: 15)))

        #expect(SessionFormatting.lastRecordQuestion(record, now: now, calendar: saoPaulo)
            == "Seu último registro foi ontem às 22:30. Usar esse horário como fim?")
        #expect(SessionFormatting.lastRecordQuestion(record, now: now, calendar: utc)
            == "Seu último registro foi às 01:30. Usar esse horário como fim?")
    }

    @Test("VoiceOver reads a recent session as one sentence: name, date, time and duration")
    func recentAccessibility() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 19, minute: 30)))

        #expect(SessionFormatting.recentAccessibilityText(name: "Push", startedAt: date, duration: 45 * 60, now: now, calendar: calendar)
            == "Push, 4 de outubro, 19:30, 45 min")
        #expect(SessionFormatting.recentAccessibilityText(name: "Treino livre", startedAt: date, duration: nil, now: now, calendar: calendar)
            == "Treino livre, 4 de outubro, 19:30")
    }

    @Test("Summary counts completed work, with singular forms")
    func summary() {
        #expect(SessionFormatting.summaryText(duration: 45 * 60, exercises: 2, sets: 6) == "45 min · 2 exercícios · 6 séries")
        #expect(SessionFormatting.summaryText(duration: 60, exercises: 1, sets: 1) == "1 min · 1 exercício · 1 série")
        #expect(SessionFormatting.summaryText(duration: nil, exercises: 2, sets: 3) == "2 exercícios · 3 séries")
    }

    @Test("Targets: a range, a single value, or none")
    func targets() {
        #expect(SessionFormatting.targetText(min: 8, max: 12) == "8–12")
        #expect(SessionFormatting.targetText(min: 10, max: 10) == "10")
        #expect(SessionFormatting.targetText(min: nil, max: 12) == "12")
        #expect(SessionFormatting.targetText(min: nil, max: nil) == nil)
    }

    @Test("Stored values are shown as they are typed")
    func drafts() {
        #expect(SessionFormatting.draft(weightKg: 82.5, reps: 10) == SetDraft(weight: "82,5", reps: "10"))
        #expect(SessionFormatting.draft(weightKg: nil, reps: nil) == SetDraft(weight: "", reps: ""))
    }

    @Test("Typed values are read; empty fields have no value")
    func values() throws {
        #expect(try SessionFormatting.values(of: SetDraft(weight: "82,5", reps: "10")) == SetValues(weightKg: 82.5, reps: 10))
        #expect(try SessionFormatting.values(of: SetDraft(weight: " 20.5 ", reps: " 8 ")) == SetValues(weightKg: 20.5, reps: 8))
        #expect(try SessionFormatting.values(of: SetDraft(weight: "", reps: "")) == SetValues(weightKg: nil, reps: nil))
        // Performed sets have no planned-set limits; range rules belong to the service.
        #expect(try SessionFormatting.values(of: SetDraft(weight: "1500", reps: "150")) == SetValues(weightKg: 1_500, reps: 150))
    }

    @Test("Unreadable values are rejected with the matching error")
    func invalidValues() {
        #expect(throws: PlannedSetInputError.repsRequired) { try SessionFormatting.values(of: SetDraft(weight: "", reps: "1,5")) }
        #expect(throws: PlannedSetInputError.repsRequired) { try SessionFormatting.values(of: SetDraft(weight: "", reps: "abc")) }
        #expect(throws: PlannedSetInputError.repsRequired) { try SessionFormatting.values(of: SetDraft(weight: "", reps: "99999999999999999999")) }
        #expect(throws: ValidationError.invalidWeight) { try SessionFormatting.values(of: SetDraft(weight: "abc", reps: "")) }
        #expect(throws: PlannedSetInputError.thousandsSeparator) { try SessionFormatting.values(of: SetDraft(weight: "1.000", reps: "")) }
    }

    @Test("Checking a set with empty repetitions takes the target (the maximum of a range)")
    func repsForCompletion() {
        #expect(SessionFormatting.repsForCompletion(typed: 9, targetMin: 8, targetMax: 12) == 9)
        #expect(SessionFormatting.repsForCompletion(typed: nil, targetMin: 8, targetMax: 12) == 12)
        #expect(SessionFormatting.repsForCompletion(typed: nil, targetMin: 8, targetMax: nil) == 8)
        #expect(SessionFormatting.repsForCompletion(typed: nil, targetMin: nil, targetMax: nil) == nil)
    }

    @Test("Checking a set with an empty field records the suggestion in gray; what is typed wins")
    func completionWithSuggestion() {
        let suggestion = SetSuggestion(weightKg: 22, reps: 10)
        // Nothing typed: both suggested values.
        #expect(SessionFormatting.completionValues(typed: SetValues(weightKg: nil, reps: nil), suggestion: suggestion)
            == SetValues(weightKg: 22, reps: 10))
        // Only the load typed: the typed load and the suggested repetitions.
        #expect(SessionFormatting.completionValues(typed: SetValues(weightKg: 25, reps: nil), suggestion: suggestion)
            == SetValues(weightKg: 25, reps: 10))
        // Only the repetitions typed.
        #expect(SessionFormatting.completionValues(typed: SetValues(weightKg: nil, reps: 8), suggestion: suggestion)
            == SetValues(weightKg: 22, reps: 8))
        // Without a suggestion, as before: no load, and no repetitions (the set cannot be checked).
        #expect(SessionFormatting.completionValues(typed: SetValues(weightKg: nil, reps: nil), suggestion: .empty)
            == SetValues(weightKg: nil, reps: nil))
    }

    @Test("The suggestion comes from the same set the last time, or else from the plan")
    func suggestion() {
        let previous = PreviousSet(weightKg: 22, reps: 10)
        #expect(LastPerformance.suggestion(previous: previous, targetWeightKg: 20, targetRepsMin: 8, targetRepsMax: 12)
            == SetSuggestion(weightKg: 22, reps: 10))
        // Done without a load the last time: no load is suggested, even with a planned one.
        #expect(LastPerformance.suggestion(previous: PreviousSet(weightKg: nil, reps: 12), targetWeightKg: 20, targetRepsMin: 8, targetRepsMax: 12)
            == SetSuggestion(weightKg: nil, reps: 12))
        // No last time for that set: the planned load and the maximum of the targets (or the minimum).
        #expect(LastPerformance.suggestion(previous: nil, targetWeightKg: 20, targetRepsMin: 8, targetRepsMax: 12)
            == SetSuggestion(weightKg: 20, reps: 12))
        #expect(LastPerformance.suggestion(previous: nil, targetWeightKg: nil, targetRepsMin: 8, targetRepsMax: nil)
            == SetSuggestion(weightKg: nil, reps: 8))
        #expect(LastPerformance.suggestion(previous: nil, targetWeightKg: nil, targetRepsMin: nil, targetRepsMax: nil) == .empty)
    }

    @Test("The \"ÚLTIMA\" column: load × repetitions, only the repetitions without a load, a dash without data")
    func previousSetText() {
        #expect(LastPerformance.text(of: PreviousSet(weightKg: 22, reps: 10)) == "22 × 10")
        #expect(LastPerformance.text(of: PreviousSet(weightKg: 22.5, reps: 8)) == "22,5 × 8")
        #expect(LastPerformance.text(of: PreviousSet(weightKg: nil, reps: 12)) == "12")
        #expect(LastPerformance.text(of: nil) == "—")
        #expect(LastPerformance.accessibilityText(of: PreviousSet(weightKg: 22.5, reps: 8)) == "Última vez: 22,5 kg, 8 repetições")
        #expect(LastPerformance.accessibilityText(of: PreviousSet(weightKg: nil, reps: 1)) == "Última vez: 1 repetição")
        #expect(LastPerformance.accessibilityText(of: nil) == "Sem registro da última vez")
    }
}
