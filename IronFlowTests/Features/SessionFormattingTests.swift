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
}
