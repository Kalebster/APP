import Foundation
import Testing
@testable import IronFlow

/// A stand-in for the iPhone's notifications: what was scheduled, without the iPhone.
@MainActor
final class FakeRestAlertCenter: RestAlertCenter {
    var status: RestAlertAuthorization
    var allows: Bool
    private(set) var scheduled: RestAlert?
    private(set) var questions = 0
    private(set) var schedules = 0
    private(set) var cancels = 0

    init(status: RestAlertAuthorization = .authorized, allows: Bool = true) {
        self.status = status
        self.allows = allows
    }

    func authorization() async -> RestAlertAuthorization { status }

    func requestAuthorization() async -> Bool {
        questions += 1
        status = allows ? .authorized : .denied
        return allows
    }

    func schedule(_ alert: RestAlert) {
        schedules += 1
        scheduled = alert
    }

    func cancel() {
        cancels += 1
        scheduled = nil
    }
}

/// When the rest starts and when it does not, its notice (scheduled, scheduled again, cancelled and
/// written again), the time left after the app opens again, and the preferences kept.
@MainActor
struct RestControllerTests {
    let clock = TestClock()
    let store: UserDefaults
    let center: FakeRestAlertCenter
    let session = UUID()
    let next = "Próxima: Supino Reto com Barra · série 2 de 5"

    init() throws {
        store = try #require(UserDefaults(suiteName: "rest-tests-\(UUID().uuidString)"))
        center = FakeRestAlertCenter()
    }

    private func makeController() async -> RestController {
        let controller = RestController(settings: SessionSettings(store: store), center: center, store: store, now: clock.now)
        await controller.refreshAuthorization()
        return controller
    }

    // MARK: - Starting

    @Test("Checking a set starts the exercise's rest and schedules its notice for the end, with the next set")
    func startsWithTheExerciseRest() async {
        let rest = await makeController()
        rest.start(for: session, seconds: 120, nextSet: next)
        #expect(rest.timer.isRunning(for: session))
        #expect(rest.timer.endsAt == clock.current.addingTimeInterval(120))
        #expect(center.scheduled == RestAlert(title: "Descanso acabou", body: next, date: clock.current.addingTimeInterval(120)))
    }

    @Test("A new set checked replaces the running rest and its notice")
    func replacesTheRunningRest() async {
        let rest = await makeController()
        rest.start(for: session, seconds: 90, nextSet: next)
        clock.advance(by: 30)
        rest.start(for: session, seconds: 60, nextSet: "Próxima: Supino Reto com Barra · série 3 de 5")
        #expect(rest.timer.endsAt == clock.current.addingTimeInterval(60))
        #expect(center.scheduled?.body == "Próxima: Supino Reto com Barra · série 3 de 5")
        #expect(center.scheduled?.date == clock.current.addingTimeInterval(60))
    }

    @Test("No rest with \"Sem timer\" or after the last set of the session, and the running one ends with its notice")
    func noRestWithoutTimerOrAfterTheLastSet() async {
        let rest = await makeController()
        rest.start(for: session, seconds: RestDuration.noTimer, nextSet: next)
        #expect(!rest.timer.isRunning(for: session))
        #expect(center.scheduled == nil)

        rest.start(for: session, seconds: 90, nextSet: next)
        rest.start(for: session, seconds: RestDuration.noTimer, nextSet: next)
        #expect(!rest.timer.isRunning(for: session), "Sem timer ends the running rest")
        #expect(center.scheduled == nil)

        rest.start(for: session, seconds: 90, nextSet: next)
        rest.start(for: session, seconds: 90, nextSet: nil)
        #expect(!rest.timer.isRunning(for: session), "Every set done ends the running rest")
        #expect(center.scheduled == nil)
    }

    // MARK: - −15, +15, Pular

    @Test("+15 and −15 schedule the notice again; Pular cancels it")
    func adjustsAndSkips() async {
        let rest = await makeController()
        rest.start(for: session, seconds: 90, nextSet: next)
        rest.add(15, for: session)
        #expect(center.scheduled?.date == clock.current.addingTimeInterval(105))
        rest.add(-15, for: session)
        rest.add(-15, for: session)
        #expect(center.scheduled?.date == clock.current.addingTimeInterval(75))
        rest.stop()
        #expect(!rest.timer.isRunning(for: session))
        #expect(center.scheduled == nil)
    }

    @Test("On \"Pronto\", +15 starts a rest of 15 s and −15 does nothing")
    func addsOnReady() async {
        let rest = await makeController()
        rest.start(for: session, seconds: 30, nextSet: next)
        clock.advance(by: 30)
        rest.endIfOver(isActive: true)
        #expect(rest.lastEnd?.sessionID == session)
        #expect(rest.lastEnd?.nextSet == next)

        rest.add(-15, for: session)
        #expect(!rest.timer.isRunning(for: session))
        rest.add(15, for: session)
        #expect(rest.timer.endsAt == clock.current.addingTimeInterval(15))
        #expect(center.scheduled?.body == next)
    }

    // MARK: - The end

    @Test("A rest that ends with the app on screen is shown; one that ended while the app was away just goes")
    func endsOnScreenOrSilently() async {
        let rest = await makeController()
        rest.start(for: session, seconds: 30, nextSet: next)
        clock.advance(by: 29)
        rest.endIfOver(isActive: true)
        #expect(rest.timer.isRunning(for: session), "Ended before its time")
        clock.advance(by: 1)
        rest.endIfOver(isActive: true)
        #expect(!rest.timer.isRunning(for: session))
        #expect(rest.lastEnd != nil)

        let shown = rest.lastEnd
        rest.start(for: session, seconds: 30, nextSet: next)
        clock.advance(by: 300)
        rest.endIfOver(isActive: true)
        #expect(!rest.timer.isRunning(for: session))
        #expect(rest.lastEnd == nil, "A late end is shown: \(String(describing: shown))")

        rest.start(for: session, seconds: 30, nextSet: next)
        clock.advance(by: 30)
        rest.endIfOver(isActive: false)
        #expect(rest.lastEnd == nil, "An end in the background is shown")
    }

    @Test("A finished or discarded session ends its rest and cancels the notice")
    func sessionEnds() async {
        let rest = await makeController()
        rest.start(for: session, seconds: 90, nextSet: next)
        rest.stopUnless(inProgress: [session])
        #expect(rest.timer.isRunning(for: session))
        rest.stopUnless(inProgress: [])
        #expect(!rest.timer.isRunning(for: session))
        #expect(center.scheduled == nil)
    }

    @Test("A change in the session during the rest writes the notice again, for the same end")
    func nextSetChanges() async {
        let rest = await makeController()
        rest.updateNextSet("Próxima: Remada · série 1 de 3", for: session)
        #expect(center.schedules == 0, "Scheduled without a rest")

        rest.start(for: session, seconds: 90, nextSet: next)
        let endsAt = rest.timer.endsAt
        rest.updateNextSet(next, for: session)
        #expect(center.schedules == 1, "Scheduled again with the same text")
        rest.updateNextSet("Próxima: Supino Reto com Barra · série 2 de 6", for: session)
        #expect(center.scheduled == RestAlert(title: "Descanso acabou", body: "Próxima: Supino Reto com Barra · série 2 de 6", date: endsAt!))
        rest.updateNextSet("Próxima: Rosca · série 1 de 3", for: UUID())
        #expect(center.scheduled?.body == "Próxima: Supino Reto com Barra · série 2 de 6", "Another session's change")
    }

    // MARK: - Opened again

    @Test("After the app is closed and opened again, the rest has the time really left; one already over does not come back")
    func survivesClosing() async {
        do {
            let rest = await makeController()
            rest.start(for: session, seconds: 90, nextSet: next)
        }
        clock.advance(by: 40)
        let reopened = await makeController()
        #expect(reopened.timer.isRunning(for: session))
        #expect(reopened.timer.remaining(at: clock.current) == 50)
        #expect(reopened.nextSet == next)

        clock.advance(by: 120)
        let late = await makeController()
        late.stopUnless(inProgress: [session])
        late.endIfOver(isActive: false)
        #expect(!late.timer.isRunning(for: session))
        #expect(late.lastEnd == nil)
        #expect(store.data(forKey: RestController.storageKey) == nil)
    }

    // MARK: - Permission and preferences

    @Test("Without permission, no notice is scheduled; the offer is shown once; allowing schedules the running rest's notice")
    func permissionAllowed() async {
        center.status = .notDetermined
        let rest = await makeController()
        #expect(rest.shouldOfferAlert)
        rest.start(for: session, seconds: 90, nextSet: next)
        #expect(center.scheduled == nil)

        rest.markOfferShown()
        #expect(!rest.shouldOfferAlert)
        #expect(await rest.requestAlert())
        #expect(rest.isAlertOn)
        #expect(center.scheduled?.body == next)
        #expect(center.questions == 1)
    }

    @Test("Refused at the question, the notice stays off and the option shows the iPhone's Settings")
    func permissionRefused() async {
        center.status = .notDetermined
        center.allows = false
        let rest = await makeController()
        rest.start(for: session, seconds: 90, nextSet: next)
        #expect(!(await rest.requestAlert()))
        #expect(rest.authorization == .denied)
        #expect(!rest.isAlertOn)
        #expect(!rest.shouldOfferAlert)
        #expect(center.scheduled == nil)
    }

    @Test("Turning the notice on before the question asks it; off cancels it; the choice is kept")
    func optionToggles() async {
        center.status = .notDetermined
        let rest = await makeController()
        await rest.setAlertWanted(true)
        #expect(center.questions == 1)
        #expect(rest.isAlertOn)

        rest.start(for: session, seconds: 90, nextSet: next)
        #expect(center.scheduled != nil)
        await rest.setAlertWanted(false)
        #expect(!rest.isAlertOn)
        #expect(center.scheduled == nil)
        rest.add(15, for: session)
        #expect(center.scheduled == nil, "Scheduled while turned off")

        let reopened = await makeController()
        #expect(!reopened.settings.restAlertWanted)
        #expect(reopened.settings.restAlertOffered)
    }

    @Test("The options are kept for the next sessions: the screen off until turned on, the notice on until turned off")
    func settingsAreKept() {
        let settings = SessionSettings(store: store)
        #expect(!settings.keepScreenOn)
        #expect(settings.restAlertWanted)
        #expect(!settings.restAlertOffered)
        settings.setKeepScreenOn(true)
        settings.setRestAlertWanted(false)
        settings.markRestAlertOffered()

        let read = SessionSettings(store: store)
        #expect(read.keepScreenOn)
        #expect(!read.restAlertWanted)
        #expect(read.restAlertOffered)
    }

    // MARK: - Texts

    @Test("The next set is the first not done, in the session's order")
    func nextSetText() {
        let names = ["Supino Reto com Barra", "Supino Inclinado com Halteres"]
        #expect(RestAlertText.nextSet(names: names, done: [[true, false, false, false, false], [false]]) == "Próxima: Supino Reto com Barra · série 2 de 5")
        #expect(RestAlertText.nextSet(names: names, done: [[true, true], [true, false, false]]) == "Próxima: Supino Inclinado com Halteres · série 2 de 3")
        #expect(RestAlertText.nextSet(names: names, done: [[true], [true]]) == nil)
        #expect(RestAlertText.notice(nextSet: "Próxima: Supino Reto com Barra · série 4 de 5") == "Descanso acabou. Próxima: Supino Reto com Barra · série 4 de 5")
        #expect(RestAlertText.notice(nextSet: nil) == "Descanso acabou")
    }
}
