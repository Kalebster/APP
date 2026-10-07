import Foundation

/// A problem with what was typed in the set editor.
enum PlannedSetInputError: Error, Equatable {
    /// A repetition field is empty or not a whole number.
    case repsRequired
    /// The load uses a thousands separator ("1.000"); a thousand kilograms is typed as "1000".
    case thousandsSeparator
}

/// How planned set values are shown, and how the values typed in the set editor are read.
/// Pure logic: no UI and no store access.
enum PlannedSetFormatting {
    /// The app is in Brazilian Portuguese only: decimal comma, dot for thousands.
    private static let locale = Locale(identifier: "pt_BR")

    /// "8–12 reps", or "10 reps" when the minimum equals the maximum.
    static func repsText(min: Int, max: Int) -> String {
        min == max ? String(localized: "\(min) reps") : String(localized: "\(min)–\(max) reps")
    }

    /// "82,5 kg", "1.000 kg", or "Sem carga" when no load is planned.
    static func weightText(_ weightKg: Double?) -> String {
        guard let weightKg else { return String(localized: "Sem carga") }
        return "\(weightKg.formatted(.number.precision(.fractionLength(0...2)).locale(locale))) kg"
    }

    /// The load as it is typed in the editor ("82,5", "1000"); empty when no load is planned.
    static func weightFieldText(_ weightKg: Double?) -> String {
        guard let weightKg else { return "" }
        return weightKg.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
    }

    /// Reads the typed fields into planned set values and checks them.
    ///
    /// Throws the first problem found: `PlannedSetInputError.repsRequired` for an empty or
    /// non-numeric repetition field, any error of `weightKg(_:)` for the load, or any error of
    /// `PlannedSetValues.validate()`.
    static func values(repsMin: String, repsMax: String, weight: String) throws -> PlannedSetValues {
        guard let min = reps(repsMin), let max = reps(repsMax) else { throw PlannedSetInputError.repsRequired }
        let load = try weightKg(weight)
        let values = PlannedSetValues(weightKg: load, repsMin: min, repsMax: max)
        try values.validate()
        return values
    }

    /// A whole number of repetitions, or `nil` when the text is empty or not a whole number.
    /// A number too large to store is read as `Int.max`, so it is reported as too high.
    static func reps(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(isDigit) else { return nil }
        return Int(trimmed) ?? Int.max
    }

    /// The typed load: `nil` when empty, otherwise digits with an optional decimal comma or dot
    /// ("82,5", "82.5", "82,"). The separator is only for decimals, so a grouped number is never
    /// read as a smaller load: exactly three digits after it ("1.000", "1,000") throw
    /// `PlannedSetInputError.thousandsSeparator`, more than three throw
    /// `ValidationError.tooManyDecimals`, and anything else unreadable throws `ValidationError.invalidWeight`.
    static func weightKg(_ text: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var number = ""
        var hasSeparator = false
        for character in trimmed {
            if isDigit(character) {
                number.append(character)
            } else if (character == "," || character == "."), !hasSeparator, !number.isEmpty {
                hasSeparator = true
                number.append(".")
            } else {
                throw ValidationError.invalidWeight
            }
        }
        if let separator = number.firstIndex(of: ".") {
            let decimals = number[number.index(after: separator)...].count
            if decimals == 3 {
                throw PlannedSetInputError.thousandsSeparator
            }
            if decimals > 3 {
                throw ValidationError.tooManyDecimals
            }
        }
        if number.hasSuffix(".") {
            number.removeLast()
        }
        guard let value = Double(number) else { throw ValidationError.invalidWeight }
        return value
    }

    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }
}
