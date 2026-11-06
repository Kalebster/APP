import Foundation
import Testing
@testable import IronFlow

/// The rest between sets: the exercise's rest from the moment a set is checked, ±15 s, "Pular", never
/// below zero, and always counted from the moment it ends.
struct RestTimerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let session = UUID()

    @Test("A rest starts with its duration and counts down from the moment it ends")
    func startsAndCountsDown() {
        var timer = RestTimer()
        #expect(!timer.isRunning(for: session))
        #expect(timer.remaining(at: start) == 0)

        timer.start(for: session, duration: 90, at: start)
        #expect(timer.isRunning(for: session))
        #expect(!timer.isRunning(for: UUID()), "A rest belongs to its session only")
        #expect(timer.endsAt == start.addingTimeInterval(90))
        #expect(timer.remaining(at: start) == 90)
        #expect(timer.remaining(at: start.addingTimeInterval(6)) == 84)
        #expect(timer.fractionLeft(at: start.addingTimeInterval(45)) == 0.5)
        #expect(!timer.isOver(at: start.addingTimeInterval(89)))

        // In the background or minimized, the time left is still the end minus now.
        #expect(timer.remaining(at: start.addingTimeInterval(200)) == 0)
        #expect(timer.isOver(at: start.addingTimeInterval(90)))
    }

    @Test("Checking another set starts the rest over")
    func restarts() {
        var timer = RestTimer()
        timer.start(for: session, duration: 90, at: start)
        timer.start(for: session, duration: 90, at: start.addingTimeInterval(40))
        #expect(timer.remaining(at: start.addingTimeInterval(40)) == 90)
        #expect(timer.length == 90)
    }

    @Test("+15 and −15 change the time left, which never goes below zero")
    func addsAndTakesAway() {
        var timer = RestTimer()
        timer.start(for: session, duration: 90, at: start)
        let now = start.addingTimeInterval(10)

        timer.add(RestTimer.step, at: now)
        #expect(timer.remaining(at: now) == 95)
        timer.add(-RestTimer.step, at: now)
        timer.add(-RestTimer.step, at: now)
        #expect(timer.remaining(at: now) == 65)

        // With 5 s left, −15 ends the rest now instead of going below zero.
        let late = start.addingTimeInterval(70)
        #expect(timer.remaining(at: late) == 5)
        timer.add(-RestTimer.step, at: late)
        #expect(timer.remaining(at: late) == 0)
        #expect(timer.isOver(at: late))
        #expect(timer.endsAt == late)
    }

    @Test("Pular ends the rest; ±15 does nothing without a rest")
    func skips() {
        var timer = RestTimer()
        timer.add(RestTimer.step, at: start)
        #expect(timer.endsAt == nil)

        timer.start(for: session, duration: 90, at: start)
        timer.stop()
        #expect(!timer.isRunning(for: session))
        #expect(timer.endsAt == nil)
        #expect(timer.remaining(at: start) == 0)
        #expect(!timer.isOver(at: start.addingTimeInterval(200)))
    }

    @Test("A rest of another length starts with it, and the rest survives being kept and read again")
    func otherLengthsAndKept() throws {
        var timer = RestTimer()
        timer.start(for: session, duration: 45, at: start)
        #expect(timer.endsAt == start.addingTimeInterval(45))
        #expect(timer.length == 45)
        let read = try JSONDecoder().decode(RestTimer.self, from: JSONEncoder().encode(timer))
        #expect(read == timer)
    }

    @Test("The time left is shown rounded up to the second")
    func text() {
        #expect(SessionFormatting.restText(90) == "1:30")
        #expect(SessionFormatting.restText(84.2) == "1:25")
        #expect(SessionFormatting.restText(5) == "0:05")
        #expect(SessionFormatting.restText(0.3) == "0:01")
        #expect(SessionFormatting.restText(0) == "0:00")
        #expect(SessionFormatting.restText(-4) == "0:00")
    }
}
