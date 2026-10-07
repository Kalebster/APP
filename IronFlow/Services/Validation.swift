import Foundation

/// Input rules shared by the services. Pure functions: no store access.
enum Validation {
    static let maxNameLength = 60
    /// Highest repetition count of a planned set.
    static let maxPlannedReps = 100
    /// Highest load of a planned set, in kilograms.
    static let maxPlannedWeightKg: Double = 1_000

    /// Returns the name without leading and trailing whitespace, or throws.
    static func name(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.emptyName }
        guard trimmed.count <= maxNameLength else { throw ValidationError.nameTooLong }
        return trimmed
    }

    /// Key used only to compare exercise names (case- and diacritic-insensitive). Never stored.
    static func comparisonKey(forName name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// A load in kilograms: optional, finite, not negative, at most two decimal places.
    static func weight(_ weightKg: Double?) throws {
        guard let weightKg else { return }
        guard weightKg.isFinite else { throw ValidationError.invalidWeight }
        guard weightKg >= 0 else { throw ValidationError.negativeWeight }
        // Tolerance absorbs binary floating-point noise (e.g. 2.675 * 100 = 267.49999…).
        let hundredths = weightKg * 100
        guard hundredths.isFinite else { throw ValidationError.invalidWeight }
        guard abs(hundredths - hundredths.rounded()) < 1e-6 else { throw ValidationError.tooManyDecimals }
    }

    static let bodyWeightRangeKg: ClosedRange<Double> = 20...300
    static let heightRangeCm: ClosedRange<Int> = 100...250
    static let dailyCalorieGoalRangeKcal: ClosedRange<Int> = 800...8_000

    /// A body weight in kilograms: within `bodyWeightRangeKg`, at most two decimal places.
    static func bodyWeight(_ weightKg: Double) throws {
        guard weightKg.isFinite, bodyWeightRangeKg.contains(weightKg) else { throw ValidationError.invalidBodyWeight }
        do {
            try weight(weightKg)
        } catch {
            throw ValidationError.invalidBodyWeight
        }
    }

    /// A height in whole centimeters within `heightRangeCm`.
    static func height(_ heightCm: Int) throws {
        guard heightRangeCm.contains(heightCm) else { throw ValidationError.invalidHeight }
    }

    /// A daily calorie goal in whole kilocalories within `dailyCalorieGoalRangeKcal`.
    static func dailyCalorieGoal(_ kcal: Int) throws {
        guard dailyCalorieGoalRangeKcal.contains(kcal) else { throw ValidationError.invalidCalorieGoal }
    }

    /// Repetitions actually performed.
    static func performedReps(_ reps: Int) throws {
        guard reps > 0 else { throw ValidationError.invalidReps }
    }
}

/// Values of one planned set.
struct PlannedSetValues: Equatable, Sendable {
    var weightKg: Double?
    var repsMin: Int
    var repsMax: Int

    init(weightKg: Double?, repsMin: Int, repsMax: Int) {
        self.weightKg = weightKg
        self.repsMin = repsMin
        self.repsMax = repsMax
    }

    /// The values stored in a planned set.
    init(_ plannedSet: PlannedSet) {
        self.init(weightKg: plannedSet.weightKg, repsMin: plannedSet.repsMin, repsMax: plannedSet.repsMax)
    }

    /// Repetitions from 1 to `Validation.maxPlannedReps` with minimum ≤ maximum; an optional
    /// load up to `Validation.maxPlannedWeightKg` that follows the load rules.
    /// The limits apply only to planned sets; performed sets are checked by `Validation` alone.
    func validate() throws {
        guard repsMin > 0 else { throw ValidationError.invalidRepsMin }
        guard repsMax > 0 else { throw ValidationError.invalidRepsMax }
        guard repsMin <= Validation.maxPlannedReps, repsMax <= Validation.maxPlannedReps else {
            throw ValidationError.repsTooHigh
        }
        guard repsMin <= repsMax else { throw ValidationError.repsMinGreaterThanMax }
        try Validation.weight(weightKg)
        if let weightKg, weightKg > Validation.maxPlannedWeightKg {
            throw ValidationError.weightTooHigh
        }
    }
}
