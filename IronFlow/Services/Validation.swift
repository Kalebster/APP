import Foundation

/// Input rules shared by the services. Pure functions: no store access.
enum Validation {
    static let maxNameLength = 60

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

    func validate() throws {
        guard repsMin > 0 else { throw ValidationError.invalidRepsMin }
        guard repsMax > 0 else { throw ValidationError.invalidRepsMax }
        guard repsMin <= repsMax else { throw ValidationError.repsMinGreaterThanMax }
        try Validation.weight(weightKg)
    }
}
