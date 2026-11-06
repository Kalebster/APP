import Foundation
import Observation

/// The options of "Opções do treino", kept for the next sessions, and whether the app already offered
/// the end-of-rest notice. Interface preferences in `UserDefaults` (`AppPreferences`), never in the store.
@MainActor
@Observable
final class SessionSettings {
    private enum Key {
        static let keepScreenOn = "session.keepScreenOn"
        static let restAlertWanted = "session.restAlertWanted"
        static let restAlertOffered = "session.restAlertOffered"
    }

    private let store: UserDefaults

    /// "Manter a tela ligada": off until turned on.
    private(set) var keepScreenOn: Bool
    /// Whether the person wants the end-of-rest notice ("Aviso do fim do descanso"): on until turned off.
    /// The notice also needs the iPhone's permission.
    private(set) var restAlertWanted: Bool
    /// Whether "Avisar quando o descanso acabar?" was already shown: it is shown once, never again.
    private(set) var restAlertOffered: Bool

    init(store: UserDefaults) {
        self.store = store
        keepScreenOn = store.bool(forKey: Key.keepScreenOn)
        restAlertWanted = store.object(forKey: Key.restAlertWanted) as? Bool ?? true
        restAlertOffered = store.bool(forKey: Key.restAlertOffered)
    }

    func setKeepScreenOn(_ value: Bool) {
        keepScreenOn = value
        store.set(value, forKey: Key.keepScreenOn)
    }

    func setRestAlertWanted(_ value: Bool) {
        restAlertWanted = value
        store.set(value, forKey: Key.restAlertWanted)
    }

    func markRestAlertOffered() {
        restAlertOffered = true
        store.set(true, forKey: Key.restAlertOffered)
    }
}
