import Foundation
import OSLog
import UserNotifications

private let restAlertLogger = Logger(subsystem: "com.ironflow.app", category: "rest-alert")

/// Whether the iPhone lets the app send the end-of-rest notice.
enum RestAlertAuthorization: Equatable, Sendable {
    /// The question was never asked.
    case notDetermined
    case authorized
    /// Refused, at the question or later in the iPhone's Settings.
    case denied
}

/// The notice at the end of a rest: "Descanso acabou", "Próxima: Supino Reto com Barra · série 2 de 5".
struct RestAlert: Equatable, Sendable {
    let title: String
    let body: String
    /// When the rest ends.
    let date: Date
}

/// Where the end-of-rest notice is scheduled: the iPhone's notifications, or a stand-in in the tests.
/// There is only ever one notice: scheduling one replaces the one before.
@MainActor
protocol RestAlertCenter: AnyObject {
    func authorization() async -> RestAlertAuthorization
    /// Asks the iPhone's own question; returns whether the person allowed it.
    func requestAuthorization() async -> Bool
    func schedule(_ alert: RestAlert)
    func cancel()
}

/// The iPhone's local notifications, with the default sound.
@MainActor
final class SystemRestAlertCenter: RestAlertCenter {
    /// The notice's only identifier, so a new one replaces the one before.
    static let identifier = "rest-end"

    func authorization() async -> RestAlertAuthorization {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<UNAuthorizationStatus, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .authorized
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            restAlertLogger.error("Notification authorization failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    func schedule(_ alert: RestAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, alert.date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                restAlertLogger.error("Rest notice not scheduled: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}

/// The texts of the end of a rest. Pure logic.
enum RestAlertText {
    /// The notice's title, and what VoiceOver announces.
    static var title: String {
        String(localized: "Descanso acabou")
    }

    /// "Próxima: Supino Reto com Barra · série 2 de 5": the first set not done, in the session's order
    /// (`SessionProgress`). `nil` when every set is done. `sets` holds whether each set of each exercise
    /// is done, both in session order, as `names`.
    static func nextSet(names: [String], done sets: [[Bool]]) -> String? {
        for (index, exercise) in sets.enumerated() {
            if let set = exercise.firstIndex(of: false), names.indices.contains(index) {
                return String(localized: "Próxima: \(names[index]) · série \(set + 1) de \(exercise.count)")
            }
        }
        return nil
    }

    /// The notice at the top of another screen: "Descanso acabou. Próxima: … · série 4 de 5".
    static func notice(nextSet: String?) -> String {
        guard let nextSet else { return title }
        return String(localized: "Descanso acabou. \(nextSet)")
    }
}
