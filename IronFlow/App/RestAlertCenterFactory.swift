import Foundation

/// The end-of-rest notices the app uses: the iPhone's, or, when the app was launched for interface
/// tests, a stand-in that never reaches the iPhone's notifications.
enum RestAlertCenterFactory {
    @MainActor
    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> any RestAlertCenter {
        #if DEBUG
        if arguments.contains("-ui-testing") {
            return UITestRestAlertCenter(arguments: arguments)
        }
        #endif
        return SystemRestAlertCenter()
    }
}

#if DEBUG
/// A test hook: the iPhone's permission, simulated, for the interface tests. `-ui-notifications
/// notDetermined|authorized|denied` gives the permission (authorized when it is not given, so the
/// tests that do not ask about it never see "Avisar quando o descanso acabar?"), and
/// `-ui-notification-answer allow|deny` the answer to the question (allow when it is not given).
/// Nothing is scheduled for real.
@MainActor
final class UITestRestAlertCenter: RestAlertCenter {
    private var status: RestAlertAuthorization
    private let allows: Bool

    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        switch value(after: "-ui-notifications") {
        case "notDetermined": status = .notDetermined
        case "denied": status = .denied
        default: status = .authorized
        }
        allows = value(after: "-ui-notification-answer") != "deny"
    }

    func authorization() async -> RestAlertAuthorization {
        status
    }

    func requestAuthorization() async -> Bool {
        guard status == .notDetermined else { return status == .authorized }
        status = allows ? .authorized : .denied
        return allows
    }

    func schedule(_ alert: RestAlert) {}

    func cancel() {}
}
#endif
