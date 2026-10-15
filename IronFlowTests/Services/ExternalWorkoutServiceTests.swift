import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// Marking and unmarking the days trained outside the app.
@MainActor
struct ExternalWorkoutServiceTests {
    let harness: ServiceTestHarness
    let calendar: Calendar
    let service: ExternalWorkoutService

    init() throws {
        harness = try ServiceTestHarness()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        self.calendar = calendar
        service = ExternalWorkoutService(context: harness.context, now: harness.clock.now, calendar: calendar)
    }

    /// The day `offset` days from the clock's day, at `hour`.
    private func day(_ offset: Int, at hour: Int = 12) throws -> Date {
        let start = calendar.startOfDay(for: harness.clock.current)
        let day = try #require(calendar.date(byAdding: .day, value: offset, to: start))
        return try #require(calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day))
    }

    private func storedDays() throws -> [String] {
        try harness.context.fetch(FetchDescriptor<ExternalWorkoutDay>()).map(\.day).sorted()
    }

    @Test("Marking stores the day as its calendar date, with the time of the change")
    func markToday() throws {
        let marking = try service.mark(harness.clock.current)

        let today = TrainingDay.key(for: harness.clock.current, calendar: calendar)
        #expect(marking.day == today)
        #expect(marking.createdAt == harness.clock.current)
        #expect(marking.updatedAt == harness.clock.current)
        #expect(try storedDays() == [today])
    }

    @Test("Unmarking removes only that day's marking; a day without one is left as it is")
    func unmark() throws {
        let yesterday = try day(-1)
        try service.mark(yesterday)
        try service.mark(harness.clock.current)

        try service.unmark(harness.clock.current)
        #expect(try storedDays() == [TrainingDay.key(for: yesterday, calendar: calendar)])

        try service.unmark(harness.clock.current)
        #expect(try storedDays() == [TrainingDay.key(for: yesterday, calendar: calendar)])
    }

    @Test("A day that has not come yet cannot be marked")
    func futureDayRejected() throws {
        let tomorrow = try day(1, at: 0)

        #expect(throws: ExternalWorkoutError.futureDay) { try service.mark(tomorrow) }
        #expect(try storedDays().isEmpty)
        #expect(harness.context.hasChanges == false)
    }

    @Test("A day already marked is not marked again, at any time of that day")
    func duplicateRejected() throws {
        try service.mark(day(-1, at: 0))

        #expect(throws: ExternalWorkoutError.alreadyMarked) { try service.mark(day(-1, at: 23)) }
        #expect(try storedDays() == [TrainingDay.key(for: day(-1), calendar: calendar)])
        #expect(harness.context.hasChanges == false)
    }

    @Test("A marked day stays marked after the store is closed and opened again")
    func markingSurvivesReopening() throws {
        let clock = harness.clock
        var marked = ""
        try roundTripThroughDisk(
            write: { context in
                let service = ExternalWorkoutService(context: context, now: clock.now, calendar: calendar)
                marked = try service.mark(clock.current).day
            },
            read: { context in
                let stored = try context.fetch(FetchDescriptor<ExternalWorkoutDay>())
                #expect(stored.map(\.day) == [marked])
                #expect(stored.map(\.createdAt) == [clock.current])
            }
        )
        #expect(marked == TrainingDay.key(for: clock.current, calendar: calendar))
    }
}
