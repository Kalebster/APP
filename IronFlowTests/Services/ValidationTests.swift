import Foundation
import Testing
@testable import IronFlow

struct ValidationTests {
    @Test("Names are trimmed, must not be empty and have at most 60 characters")
    func names() throws {
        #expect(try Validation.name("  Supino Reto \n") == "Supino Reto")
        #expect(throws: ValidationError.emptyName) { try Validation.name("") }
        #expect(throws: ValidationError.emptyName) { try Validation.name("   \n ") }
        #expect(try Validation.name(String(repeating: "a", count: 60)).count == 60)
        #expect(throws: ValidationError.nameTooLong) { try Validation.name(String(repeating: "a", count: 61)) }
    }

    @Test("Name comparison ignores case and diacritics")
    func nameComparisonKey() {
        #expect(Validation.comparisonKey(forName: "Elevação Pélvica") == Validation.comparisonKey(forName: "elevacao pelvica"))
        #expect(Validation.comparisonKey(forName: "Supino") != Validation.comparisonKey(forName: "Supino Reto"))
    }

    @Test("Repetitions must be greater than zero")
    func plannedReps() {
        #expect(throws: ValidationError.invalidRepsMin) { try PlannedSetValues.reps(0, 10).validate() }
        #expect(throws: ValidationError.invalidRepsMin) { try PlannedSetValues.reps(-1, 10).validate() }
        #expect(throws: ValidationError.invalidRepsMax) { try PlannedSetValues.reps(1, 0).validate() }
        #expect(throws: ValidationError.invalidRepsMax) { try PlannedSetValues.reps(1, -3).validate() }
    }

    @Test("Minimum repetitions cannot exceed the maximum; equal values are accepted")
    func repsRange() throws {
        #expect(throws: ValidationError.repsMinGreaterThanMax) { try PlannedSetValues.reps(12, 8).validate() }
        try PlannedSetValues.reps(10, 10).validate()
    }

    @Test("Planned repetitions go up to 100")
    func plannedRepsLimit() throws {
        try PlannedSetValues.reps(100, 100).validate()
        try PlannedSetValues.reps(1, 100).validate()
        #expect(throws: ValidationError.repsTooHigh) { try PlannedSetValues.reps(8, 101).validate() }
        #expect(throws: ValidationError.repsTooHigh) { try PlannedSetValues.reps(101, 101).validate() }
        #expect(throws: ValidationError.repsTooHigh) { try PlannedSetValues.reps(101, 12).validate() }
    }

    @Test("Planned load goes up to 1.000 kg and keeps the other load rules")
    func plannedWeightLimit() throws {
        try PlannedSetValues.reps(8, 12, kg: 1_000).validate()
        try PlannedSetValues.reps(8, 12, kg: 999.99).validate()
        #expect(throws: ValidationError.weightTooHigh) { try PlannedSetValues.reps(8, 12, kg: 1_000.01).validate() }
        #expect(throws: ValidationError.weightTooHigh) { try PlannedSetValues.reps(8, 12, kg: 5_000).validate() }
        #expect(throws: ValidationError.tooManyDecimals) { try PlannedSetValues.reps(8, 12, kg: 1_000.005).validate() }
        #expect(throws: ValidationError.negativeWeight) { try PlannedSetValues.reps(8, 12, kg: -1).validate() }
    }

    @Test("The planned set limits do not apply to performed values")
    func performedValuesHaveNoPlannedLimits() throws {
        try Validation.weight(1_500)
        try Validation.performedReps(150)
    }

    @Test("Load is optional and cannot be negative")
    func weightSign() throws {
        try Validation.weight(nil)
        try Validation.weight(0)
        #expect(throws: ValidationError.negativeWeight) { try Validation.weight(-0.5) }
    }

    @Test("Load accepts at most two decimal places")
    func weightDecimals() throws {
        for value in [22.25, 22.5, 100, 1.25, 0.01] {
            try Validation.weight(value)
        }
        #expect(throws: ValidationError.tooManyDecimals) { try Validation.weight(22.255) }
        #expect(throws: ValidationError.tooManyDecimals) { try Validation.weight(0.001) }
        #expect(throws: ValidationError.tooManyDecimals) { try Validation.weight(2.675) }
    }

    @Test("Values with binary floating-point noise are not rejected")
    func weightFloatingPointNoise() throws {
        for value in [0.1, 0.2, 0.3, 0.1 + 0.2, 1.13, 1.15, 2.67, 4.35, 1_000.07] {
            try Validation.weight(value)
        }
    }

    @Test("Load must be a finite number")
    func weightFinite() {
        #expect(throws: ValidationError.invalidWeight) { try Validation.weight(.infinity) }
        #expect(throws: ValidationError.invalidWeight) { try Validation.weight(.nan) }
        // Finite, but too large to check its decimal places.
        #expect(throws: ValidationError.invalidWeight) { try Validation.weight(1e307) }
    }

    @Test("Performed repetitions must be greater than zero")
    func performedReps() throws {
        try Validation.performedReps(1)
        #expect(throws: ValidationError.invalidReps) { try Validation.performedReps(0) }
        #expect(throws: ValidationError.invalidReps) { try Validation.performedReps(-2) }
    }
}
