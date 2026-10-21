import Foundation

/// The rest between sets: it starts when a set is checked and counts down from 1 min 30 s.
///
/// It keeps the moment the rest ends, not a count: the time left is always that moment minus now, so
/// it stays right while the app is in the background or the session is minimized. Kept in memory only
/// (never in the store); a rest belongs to one session and never carries over to another.
/// Pure logic: every change takes the current time.
struct RestTimer: Equatable, Sendable {
    /// How long a rest lasts when it starts.
    static let duration: TimeInterval = 90
    /// What "−15" and "+15" take away and add.
    static let step: TimeInterval = 15

    /// When the rest ends; `nil` when no rest is running.
    private(set) var endsAt: Date?
    /// How long the rest lasts in all, with the seconds added or taken away: the ring's full turn.
    private(set) var length: TimeInterval = 0
    /// The session the rest belongs to.
    private(set) var sessionID: UUID?

    /// Whether a rest of `session` is running (it may be over, until `stop()`).
    func isRunning(for sessionID: UUID) -> Bool {
        endsAt != nil && self.sessionID == sessionID
    }

    /// The time left, never below zero; zero when no rest is running.
    func remaining(at now: Date) -> TimeInterval {
        guard let endsAt else { return 0 }
        return max(0, endsAt.timeIntervalSince(now))
    }

    /// Whether the running rest has reached zero.
    func isOver(at now: Date) -> Bool {
        guard let endsAt else { return false }
        return endsAt <= now
    }

    /// The part of the rest still to go, from 1 to 0, for the ring.
    func fractionLeft(at now: Date) -> Double {
        guard length > 0 else { return 0 }
        return min(1, remaining(at: now) / length)
    }

    /// Starts a rest of `duration` for `sessionID`; a rest already running starts over.
    mutating func start(for sessionID: UUID, at now: Date) {
        endsAt = now.addingTimeInterval(Self.duration)
        length = Self.duration
        self.sessionID = sessionID
    }

    /// Adds (or takes away, when negative) seconds to the running rest. The time left never goes below
    /// zero: taking away more than is left ends the rest now.
    mutating func add(_ seconds: TimeInterval, at now: Date) {
        guard let endsAt else { return }
        let left = max(0, endsAt.timeIntervalSince(now))
        let newLeft = max(0, left + seconds)
        self.endsAt = now.addingTimeInterval(newLeft)
        length = max(newLeft, length + (newLeft - left))
    }

    /// Ends the rest ("Pular", or when it reaches zero).
    mutating func stop() {
        endsAt = nil
        length = 0
        sessionID = nil
    }
}
