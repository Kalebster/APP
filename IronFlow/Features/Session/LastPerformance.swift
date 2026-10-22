import Foundation

/// A set done the last time an exercise was performed: its load (`nil` without one) and repetitions.
struct PreviousSet: Equatable, Sendable {
    var weightKg: Double?
    var reps: Int
}

/// The values offered, in gray, in the empty fields of a set; checking the set records them.
struct SetSuggestion: Equatable, Sendable {
    var weightKg: Double?
    var reps: Int?

    static let empty = SetSuggestion(weightKg: nil, reps: nil)
}

/// "Última vez": what each exercise did the last time, set by set, and the values it suggests.
/// Pure logic: the sessions are read by `SessionService.lastPerformances(for:)`.
enum LastPerformance {
    /// The sets done the last time each exercise of `exerciseIDs` was performed, by exercise id.
    ///
    /// For each exercise, the most recently started session that is finished, is not
    /// `excludedSessionID`, and has at least one set of that exercise done (the exercise is matched by
    /// its relationship, so a deleted exercise has none). Its done sets are kept in set order: the
    /// first done set goes with set 1, and so on. Exercises never done are left out.
    static func previousSets(
        for exerciseIDs: Set<UUID>,
        in sessions: [Session],
        excluding excludedSessionID: UUID?
    ) -> [UUID: [PreviousSet]] {
        var found: [UUID: [PreviousSet]] = [:]
        guard !exerciseIDs.isEmpty else { return found }
        let newestFirst = sessions.sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt { return lhs.startedAt > rhs.startedAt }
            return lhs.createdAt > rhs.createdAt
        }
        for session in newestFirst where !session.isActive && session.id != excludedSessionID {
            for performed in session.exercises {
                guard let id = performed.exercise?.id, exerciseIDs.contains(id), found[id] == nil else { continue }
                let done = performed.orderedSetLogs.compactMap { log -> PreviousSet? in
                    guard log.isCompleted, let reps = log.reps else { return nil }
                    return PreviousSet(weightKg: log.weightKg, reps: reps)
                }
                if !done.isEmpty {
                    found[id] = done
                }
            }
            // Older sessions are read only while an exercise is still missing.
            if found.count == exerciseIDs.count {
                break
            }
        }
        return found
    }

    /// The "ÚLTIMA" column: "22 × 10", "22,5 × 8", only the repetitions without a load, "—" without one.
    static func text(of previous: PreviousSet?) -> String {
        guard let previous else { return "—" }
        guard let weightKg = previous.weightKg else { return previous.reps.formatted() }
        return "\(PlannedSetFormatting.weightFieldText(weightKg)) × \(previous.reps)"
    }

    /// What VoiceOver reads for the "ÚLTIMA" column.
    static func accessibilityText(of previous: PreviousSet?) -> String {
        guard let previous else { return String(localized: "Sem registro da última vez") }
        let reps = String(localized: "\(previous.reps) repetições")
        guard let weightKg = previous.weightKg else { return String(localized: "Última vez: \(reps)") }
        return String(localized: "Última vez: \(PlannedSetFormatting.weightText(weightKg)), \(reps)")
    }

    /// The suggestion for a set: its values the last time, when there is a set done in that position;
    /// otherwise the plan (the planned load, and the maximum of the target repetitions, or the minimum).
    static func suggestion(
        previous: PreviousSet?,
        targetWeightKg: Double?,
        targetRepsMin: Int?,
        targetRepsMax: Int?
    ) -> SetSuggestion {
        if let previous {
            return SetSuggestion(weightKg: previous.weightKg, reps: previous.reps)
        }
        return SetSuggestion(
            weightKg: targetWeightKg,
            reps: SessionFormatting.repsForCompletion(typed: nil, targetMin: targetRepsMin, targetMax: targetRepsMax)
        )
    }
}
