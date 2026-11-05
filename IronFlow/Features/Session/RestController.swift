import Foundation
import Observation
import OSLog

private let restLogger = Logger(subsystem: "com.ironflow.app", category: "rest")

/// A rest that reached zero with the app on screen: the session screen shows "Pronto" and the other
/// screens show "Descanso acabou. Próxima: …", both with a light vibration. Each one is new.
struct RestEnd: Equatable, Sendable {
    let id = UUID()
    let sessionID: UUID
    /// "Próxima: Supino Reto com Barra · série 2 de 5"; `nil` when no set is left.
    let nextSet: String?
}

/// The rest of the session in progress and its end-of-rest notice. Kept by `RootView`, so the rest goes
/// on while the session screen is minimized.
///
/// The rest's end time is kept in the preferences (`UserDefaults`), so the time left is right when the
/// app opens again, even after it was closed. While a rest runs and the notice is on, one local
/// notification is scheduled for its end, with the next set; it is scheduled again when the rest or the
/// next set changes, and cancelled when the rest ends early or the session ends. With the app open, the
/// iPhone does not show it (`AppDelegate`): the app shows the end itself.
@MainActor
@Observable
final class RestController {
    /// What is kept in the preferences.
    private struct Stored: Codable {
        var timer: RestTimer
        var nextSet: String?
    }

    static let storageKey = "rest.current"
    /// How late the end may be noticed and still be shown and felt: a rest that ended while the app was
    /// away was already announced by the notification, so it just goes.
    static let lateness: TimeInterval = 2

    /// The rest; stopped when none runs.
    private(set) var timer: RestTimer
    /// The next set, for the notice; kept after the rest ends, for a "+15" on "Pronto".
    private(set) var nextSet: String?
    /// The iPhone's permission; `nil` until it is read.
    private(set) var authorization: RestAlertAuthorization?
    /// The last rest that ended with the app on screen.
    private(set) var lastEnd: RestEnd?
    /// Whether the app is on screen (active or inactive, not in the background). Kept by `RootView`, so
    /// the end of a rest reads the scene's phase of now, not of when the rest started.
    @ObservationIgnored var isOnScreen = true

    let settings: SessionSettings
    private let center: any RestAlertCenter
    private let store: UserDefaults
    private let now: @MainActor () -> Date

    init(
        settings: SessionSettings,
        center: any RestAlertCenter,
        store: UserDefaults,
        now: @escaping @MainActor () -> Date = { Date.now }
    ) {
        self.settings = settings
        self.center = center
        self.store = store
        self.now = now
        if let data = store.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            timer = stored.timer
            nextSet = stored.nextSet
        } else {
            timer = RestTimer()
        }
    }

    /// Whether the end-of-rest notice is on: wanted, and allowed by the iPhone.
    var isAlertOn: Bool {
        settings.restAlertWanted && authorization == .authorized
    }

    /// Whether "Avisar quando o descanso acabar?" should be shown now: the question was never asked and
    /// the sheet was never shown.
    var shouldOfferAlert: Bool {
        authorization == .notDetermined && !settings.restAlertOffered
    }

    // MARK: - The rest

    /// A set was checked: starts the exercise's rest, in place of one already running. Without a rest
    /// ("Sem timer", 0) or without a set left, no rest starts and the one running ends.
    func start(for sessionID: UUID, seconds: Int, nextSet: String?) {
        guard seconds > 0, let nextSet else {
            stop()
            return
        }
        timer.start(for: sessionID, duration: TimeInterval(seconds), at: now())
        self.nextSet = nextSet
        lastEnd = nil
        changed()
    }

    /// "+15" and "−15". On "Pronto", when the rest already ended, "+15" starts a rest of 15 s and
    /// "−15" does nothing.
    func add(_ seconds: TimeInterval, for sessionID: UUID) {
        let time = now()
        if timer.isRunning(for: sessionID), !timer.isOver(at: time) {
            timer.add(seconds, at: time)
        } else if seconds > 0 {
            timer.start(for: sessionID, duration: seconds, at: time)
        } else {
            return
        }
        changed()
    }

    /// "Pular", and the end of the session: the rest ends and its notice is cancelled.
    func stop() {
        guard timer.endsAt != nil || nextSet != nil else { return }
        timer.stop()
        nextSet = nil
        changed()
    }

    /// The session changed during the rest (a set or an exercise added or removed): the notice is
    /// written again with the next set.
    /// Also after the rest ended ("Pronto"), so a "+15" then has the right next set.
    func updateNextSet(_ text: String?, for sessionID: UUID) {
        guard text != nextSet, timer.sessionID == nil || timer.sessionID == sessionID else { return }
        nextSet = text
        if timer.isRunning(for: sessionID) {
            changed()
        }
    }

    /// Ends the rest once its end has come. Shown and felt only when the app is on screen and the end
    /// is just now (`lateness`); a rest that ended while the app was away just goes.
    func endIfOver(isActive: Bool) {
        let time = now()
        guard let endsAt = timer.endsAt, let sessionID = timer.sessionID, endsAt <= time else { return }
        timer.stop()
        save()
        if isActive, time.timeIntervalSince(endsAt) < Self.lateness {
            lastEnd = RestEnd(sessionID: sessionID, nextSet: nextSet)
        }
    }

    /// Ends the rest of a session that is no longer in progress (finished, discarded or gone).
    func stopUnless(inProgress sessionIDs: [UUID]) {
        if let sessionID = timer.sessionID, !sessionIDs.contains(sessionID) {
            stop()
        }
    }

    // MARK: - The notice

    /// Reads the iPhone's permission again (at launch and on coming back from the Settings).
    func refreshAuthorization() async {
        let status = await center.authorization()
        guard status != authorization else { return }
        authorization = status
        scheduleAlert()
    }

    /// The sheet "Avisar quando o descanso acabar?" was shown: it never shows again.
    func markOfferShown() {
        settings.markRestAlertOffered()
    }

    /// Asks the iPhone's question ("Ativar aviso", or turning the option on before it was asked).
    /// Returns whether the person allowed it; allowed, the running rest gets its notice.
    @discardableResult
    func requestAlert() async -> Bool {
        settings.markRestAlertOffered()
        let granted = await center.requestAuthorization()
        if granted {
            authorization = .authorized
            settings.setRestAlertWanted(true)
        } else {
            let status = await center.authorization()
            // Refused at the question: never asked again.
            authorization = status == .notDetermined ? .denied : status
        }
        scheduleAlert()
        return granted
    }

    /// "Aviso do fim do descanso" turned on or off. On, before the question was asked, it asks it.
    func setAlertWanted(_ wanted: Bool) async {
        if authorization == nil {
            await refreshAuthorization()
        }
        if wanted, authorization == .notDetermined {
            await requestAlert()
            return
        }
        settings.setRestAlertWanted(wanted)
        scheduleAlert()
    }

    // MARK: - Private

    private func changed() {
        save()
        scheduleAlert()
    }

    /// Schedules the notice for the running rest, or cancels it when there is none to give.
    private func scheduleAlert() {
        // Until the permission is read, the notice already scheduled (before the app was closed) stays.
        guard authorization != nil else { return }
        guard isAlertOn, let endsAt = timer.endsAt, endsAt > now(), let nextSet else {
            center.cancel()
            return
        }
        center.schedule(RestAlert(title: RestAlertText.title, body: nextSet, date: endsAt))
    }

    private func save() {
        guard timer.endsAt != nil else {
            store.removeObject(forKey: Self.storageKey)
            return
        }
        do {
            store.set(try JSONEncoder().encode(Stored(timer: timer, nextSet: nextSet)), forKey: Self.storageKey)
        } catch {
            restLogger.error("The rest could not be kept: \(String(describing: error), privacy: .public)")
        }
    }
}
