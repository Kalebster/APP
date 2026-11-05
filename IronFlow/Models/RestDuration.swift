import Foundation

/// The rest between sets of an exercise, in whole seconds: what the planned exercise keeps and copies to
/// the session. 0 is "Sem timer": no rest starts after its sets. Pure logic.
enum RestDuration {
    /// The rest of every exercise until it is changed, and of an exercise added during a session.
    static let defaultSeconds = 90
    /// "Sem timer".
    static let noTimer = 0
    /// The longest rest that can be stored: 1 hour. The choices go up to 5 minutes.
    static let maximumSeconds = 3_600

    /// The choices of "Descanso entre séries", in order; "Sem timer" comes after them.
    static let choices = [30, 45, 60, 90, 120, 150, 180, 240, 300]

    /// Whether `seconds` can be stored.
    static func isValid(_ seconds: Int) -> Bool {
        (0...maximumSeconds).contains(seconds)
    }

    /// "1:30", "0:45", "5:00"; "Sem timer" for 0.
    static func text(_ seconds: Int) -> String {
        guard seconds > 0 else { return String(localized: "Sem timer") }
        return String(format: "%ld:%02ld", seconds / 60, seconds % 60)
    }

    /// What VoiceOver reads: "1 min 30 s", "45 s", "2 min"; "Sem timer" for 0.
    static func spokenText(_ seconds: Int) -> String {
        guard seconds > 0 else { return String(localized: "Sem timer") }
        let minutes = seconds / 60
        let rest = seconds % 60
        switch (minutes, rest) {
        case (0, _): return String(localized: "\(rest) s")
        case (_, 0): return String(localized: "\(minutes) min")
        default: return String(localized: "\(minutes) min \(rest) s")
        }
    }
}
