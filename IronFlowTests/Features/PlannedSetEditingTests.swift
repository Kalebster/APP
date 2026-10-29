import Foundation
import Testing
@testable import IronFlow

/// How a value typed in the workout editor becomes the values of its planned set.
struct PlannedSetEditingTests {
    private let stored = PlannedSetValues(weightKg: 60, repsMin: 8, repsMax: 12)

    private func outcome(_ kind: PlannedSetEditing.Kind, _ text: String) throws -> PlannedSetEditing.Outcome {
        try PlannedSetEditing.outcome(editing: kind, text: text, stored: stored)
    }

    @Test("The load is read with a decimal comma or dot, and an empty field removes it")
    func load() throws {
        #expect(try outcome(.weight, "82,5").values == PlannedSetValues(weightKg: 82.5, repsMin: 8, repsMax: 12))
        #expect(try outcome(.weight, " 82.25 ").values.weightKg == 82.25)
        #expect(try outcome(.weight, "1000").values.weightKg == 1_000)
        #expect(try outcome(.weight, "").values == PlannedSetValues(weightKg: nil, repsMin: 8, repsMax: 12))
        #expect(try outcome(.weight, "40").rangeWasAdjusted == false)
    }

    @Test("A load beyond the limits or unreadable is refused")
    func invalidLoad() {
        #expect(throws: ValidationError.weightTooHigh) { try outcome(.weight, "1000,5") }
        #expect(throws: ValidationError.tooManyDecimals) { try outcome(.weight, "1.000") }
        #expect(throws: ValidationError.tooManyDecimals) { try outcome(.weight, "12,500") }
        #expect(throws: ValidationError.tooManyDecimals) { try outcome(.weight, "2,5555") }
        #expect(throws: ValidationError.invalidWeight) { try outcome(.weight, "abc") }
        #expect(throws: ValidationError.invalidWeight) { try outcome(.weight, "-5") }
    }

    @Test("Repetitions inside the range change only the field typed")
    func repetitionsInsideTheRange() throws {
        let minimum = try outcome(.repsMin, "10")
        #expect(minimum.values == PlannedSetValues(weightKg: 60, repsMin: 10, repsMax: 12))
        #expect(minimum.rangeWasAdjusted == false)

        let maximum = try outcome(.repsMax, "15")
        #expect(maximum.values == PlannedSetValues(weightKg: 60, repsMin: 8, repsMax: 15))
        #expect(maximum.rangeWasAdjusted == false)

        // Equal to the other value is allowed.
        #expect(try outcome(.repsMin, "12").rangeWasAdjusted == false)
        #expect(try outcome(.repsMax, "8").rangeWasAdjusted == false)
    }

    @Test("A maximum below the minimum lowers the minimum to it, and a minimum above the maximum raises the maximum")
    func rangeIsAdjusted() throws {
        let maximum = try outcome(.repsMax, "6")
        #expect(maximum.values == PlannedSetValues(weightKg: 60, repsMin: 6, repsMax: 6))
        #expect(maximum.rangeWasAdjusted)

        let minimum = try outcome(.repsMin, "15")
        #expect(minimum.values == PlannedSetValues(weightKg: 60, repsMin: 15, repsMax: 15))
        #expect(minimum.rangeWasAdjusted)
    }

    @Test("An empty repetition field keeps the stored value")
    func emptyRepetitionsKeepTheStoredValue() throws {
        #expect(try outcome(.repsMin, "") == PlannedSetEditing.Outcome(values: stored, rangeWasAdjusted: false))
        #expect(try outcome(.repsMax, "  ") == PlannedSetEditing.Outcome(values: stored, rangeWasAdjusted: false))
    }

    @Test("Repetitions that are zero, above 100 or not a whole number are refused, for the field typed")
    func invalidRepetitions() {
        #expect(throws: ValidationError.invalidRepsMin) { try outcome(.repsMin, "0") }
        #expect(throws: ValidationError.invalidRepsMax) { try outcome(.repsMax, "0") }
        #expect(throws: ValidationError.repsTooHigh) { try outcome(.repsMin, "101") }
        #expect(throws: ValidationError.repsTooHigh) { try outcome(.repsMax, "101") }
        #expect(throws: PlannedSetInputError.repsRequired) { try outcome(.repsMin, "8,5") }
        #expect(throws: PlannedSetInputError.repsRequired) { try outcome(.repsMax, "doze") }
    }

    @Test("Each field shows the stored value as it is typed")
    func fieldTexts() {
        #expect(PlannedSetEditing.text(of: .weight, in: PlannedSetValues(weightKg: 82.5, repsMin: 8, repsMax: 12)) == "82,5")
        #expect(PlannedSetEditing.text(of: .weight, in: PlannedSetValues(weightKg: 1_000, repsMin: 8, repsMax: 12)) == "1000")
        #expect(PlannedSetEditing.text(of: .weight, in: PlannedSetValues(weightKg: nil, repsMin: 8, repsMax: 12)) == "")
        #expect(PlannedSetEditing.text(of: .repsMin, in: stored) == "8")
        #expect(PlannedSetEditing.text(of: .repsMax, in: stored) == "12")
    }

    @Test("The fields of a set know their set and kind")
    func fields() {
        let id = UUID()
        #expect([PlannedSetField.weight(id), .repsMin(id), .repsMax(id)].map(\.setID) == [id, id, id])
        #expect([PlannedSetField.weight(id), .repsMin(id), .repsMax(id)].map(\.kind) == [.weight, .repsMin, .repsMax])
    }
}
