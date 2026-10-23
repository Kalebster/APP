import Foundation

/// A field of a planned set row in the workout editor, so its value is saved when it loses focus.
enum PlannedSetField: Hashable {
    case weight(UUID)
    case repsMin(UUID)
    case repsMax(UUID)

    /// The planned set the field belongs to.
    var setID: UUID {
        switch self {
        case .weight(let id), .repsMin(let id), .repsMax(let id): id
        }
    }

    var kind: PlannedSetEditing.Kind {
        switch self {
        case .weight: .weight
        case .repsMin: .repsMin
        case .repsMax: .repsMax
        }
    }
}

/// How a value typed in one field of the workout editor becomes the values of its planned set.
/// Pure logic: no UI and no store access.
enum PlannedSetEditing {
    /// The field that was edited.
    enum Kind: Equatable, Sendable {
        case weight
        case repsMin
        case repsMax
    }

    /// The set's values once the field is left.
    struct Outcome: Equatable {
        let values: PlannedSetValues
        /// The other repetition value was made equal to the typed one, because the maximum would
        /// otherwise be less than the minimum.
        let rangeWasAdjusted: Bool
    }

    /// The values of the set after the field `kind` was left with `text`, starting from the `stored` ones.
    ///
    /// - The load is optional: an empty field removes it. It is read like in the rest of the app
    ///   (decimal comma or dot, at most two decimals, up to `Validation.maxPlannedWeightKg`).
    /// - An empty repetition field keeps the stored value. A minimum above the maximum raises the
    ///   maximum to it, and a maximum below the minimum lowers the minimum to it (`rangeWasAdjusted`).
    ///
    /// Throws the first problem found: `PlannedSetInputError.repsRequired` for repetitions that are not
    /// a whole number, any error of `PlannedSetFormatting.weightKg(_:)`, or any error of
    /// `PlannedSetValues.validate()`.
    static func outcome(editing kind: Kind, text: String, stored: PlannedSetValues) throws -> Outcome {
        var values = stored
        var adjusted = false
        switch kind {
        case .weight:
            values.weightKg = try PlannedSetFormatting.weightKg(text)
        case .repsMin, .repsMax:
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return Outcome(values: stored, rangeWasAdjusted: false)
            }
            guard let reps = PlannedSetFormatting.reps(text) else { throw PlannedSetInputError.repsRequired }
            // Checked before the other value follows it, so the problem is reported for the field typed.
            guard reps > 0 else { throw kind == .repsMin ? ValidationError.invalidRepsMin : ValidationError.invalidRepsMax }
            if kind == .repsMin {
                values.repsMin = reps
                if reps > values.repsMax {
                    values.repsMax = reps
                    adjusted = true
                }
            } else {
                values.repsMax = reps
                if reps < values.repsMin {
                    values.repsMin = reps
                    adjusted = true
                }
            }
        }
        try values.validate()
        return Outcome(values: values, rangeWasAdjusted: adjusted)
    }

    /// The text a field shows for the stored values: the load as it is typed ("82,5", empty without one)
    /// or the repetitions.
    static func text(of kind: Kind, in values: PlannedSetValues) -> String {
        switch kind {
        case .weight: PlannedSetFormatting.weightFieldText(values.weightKg)
        case .repsMin: String(values.repsMin)
        case .repsMax: String(values.repsMax)
        }
    }
}
