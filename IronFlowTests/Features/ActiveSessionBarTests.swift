import Foundation
import Testing
@testable import IronFlow

/// The "Treino em andamento" bar: the rest while it runs, otherwise the time and the sets done, and
/// what VoiceOver reads.
@MainActor
struct ActiveSessionBarTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func status(restEndsAt: Date?) -> ActiveSessionBar.Status {
        ActiveSessionBar.Status(name: "Push", startedAt: start, setsText: "3 de 15 séries", restEndsAt: restEndsAt)
    }

    @Test("Without a rest: the time since the start and the sets done")
    func withoutARest() {
        let now = start.addingTimeInterval(12 * 60 + 5)
        #expect(ActiveSessionBar.detailText(status(restEndsAt: nil), at: now) == "12:05 · 3 de 15 séries")
        #expect(ActiveSessionBar.accessibilityText(status(restEndsAt: nil), at: now)
            == "Treino em andamento, Push, 12:05, 3 de 15 séries. Abrir")
    }

    @Test("While a rest runs: the rest left")
    func whileResting() {
        let now = start.addingTimeInterval(600)
        let resting = status(restEndsAt: now.addingTimeInterval(83))
        #expect(ActiveSessionBar.detailText(resting, at: now) == "Descanso 1:23")
        #expect(ActiveSessionBar.accessibilityText(resting, at: now) == "Treino em andamento, Push, Descanso 1:23. Abrir")
    }

    @Test("A rest that ended while the session was minimized shows the time again")
    func restOver() {
        let now = start.addingTimeInterval(600)
        #expect(ActiveSessionBar.detailText(status(restEndsAt: now), at: now) == "10:00 · 3 de 15 séries")
        #expect(ActiveSessionBar.detailText(status(restEndsAt: now.addingTimeInterval(-30)), at: now) == "10:00 · 3 de 15 séries")
    }
}
