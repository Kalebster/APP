import Foundation
import Testing
@testable import IronFlow

struct PlannedSetFormattingTests {
    @Test("Repetitions show a range, or a single number when minimum and maximum are equal")
    func repsText() {
        #expect(PlannedSetFormatting.repsText(min: 8, max: 12) == "8–12 reps")
        #expect(PlannedSetFormatting.repsText(min: 10, max: 10) == "10 reps")
        #expect(PlannedSetFormatting.repsText(min: 1, max: 1) == "1 rep")
    }

    @Test("Loads use the decimal comma and up to two decimals; no load shows Sem carga")
    func weightText() {
        #expect(PlannedSetFormatting.weightText(nil) == "Sem carga")
        #expect(PlannedSetFormatting.weightText(0) == "0 kg")
        #expect(PlannedSetFormatting.weightText(80) == "80 kg")
        #expect(PlannedSetFormatting.weightText(82.5) == "82,5 kg")
        #expect(PlannedSetFormatting.weightText(22.25) == "22,25 kg")
        #expect(PlannedSetFormatting.weightText(1_000) == "1.000 kg")
    }

    @Test("The editor shows the load without grouping, and nothing when there is no load")
    func weightFieldText() {
        #expect(PlannedSetFormatting.weightFieldText(nil) == "")
        #expect(PlannedSetFormatting.weightFieldText(20) == "20")
        #expect(PlannedSetFormatting.weightFieldText(82.5) == "82,5")
        #expect(PlannedSetFormatting.weightFieldText(1_000) == "1000")
    }

    @Test("Repetition fields accept only whole numbers")
    func repsParsing() {
        #expect(PlannedSetFormatting.reps("8") == 8)
        #expect(PlannedSetFormatting.reps(" 12 ") == 12)
        #expect(PlannedSetFormatting.reps("99999999999999999999") == Int.max)
        for invalid in ["", "  ", "8.5", "8,5", "-3", "abc", "1 2"] {
            #expect(PlannedSetFormatting.reps(invalid) == nil, "\(invalid)")
        }
    }

    @Test("The load accepts a decimal comma or dot; empty means no load")
    func weightParsing() throws {
        #expect(try PlannedSetFormatting.weightKg("") == nil)
        #expect(try PlannedSetFormatting.weightKg("  ") == nil)
        #expect(try PlannedSetFormatting.weightKg("82,5") == 82.5)
        #expect(try PlannedSetFormatting.weightKg("82.5") == 82.5)
        #expect(try PlannedSetFormatting.weightKg(" 82, ") == 82)
        #expect(try PlannedSetFormatting.weightKg("0") == 0)
        #expect(try PlannedSetFormatting.weightKg("1000") == 1_000)
        for invalid in ["abc", "1,2,3", "1.2,3", "-5", ",5", "8 2", "82kg"] {
            #expect(throws: ValidationError.invalidWeight) { try PlannedSetFormatting.weightKg(invalid) }
        }
        // The separator is only for decimals: a thousands separator is reported, never read as a smaller load.
        for grouped in ["1.000", "1,000", "1.500", "12,500"] {
            #expect(throws: PlannedSetInputError.thousandsSeparator) { try PlannedSetFormatting.weightKg(grouped) }
        }
        for tooPrecise in ["1,0000", "82.5055"] {
            #expect(throws: ValidationError.tooManyDecimals) { try PlannedSetFormatting.weightKg(tooPrecise) }
        }
    }

    @Test("Typed fields become checked values, or report the first problem")
    func values() throws {
        #expect(try PlannedSetFormatting.values(repsMin: "8", repsMax: "12", weight: "") == .reps(8, 12))
        #expect(try PlannedSetFormatting.values(repsMin: "6", repsMax: "6", weight: "82,5") == .reps(6, 6, kg: 82.5))
        #expect(throws: PlannedSetInputError.repsRequired) { try PlannedSetFormatting.values(repsMin: "", repsMax: "12", weight: "") }
        #expect(throws: PlannedSetInputError.repsRequired) { try PlannedSetFormatting.values(repsMin: "8", repsMax: "x", weight: "") }
        #expect(throws: ValidationError.repsMinGreaterThanMax) { try PlannedSetFormatting.values(repsMin: "12", repsMax: "8", weight: "") }
        #expect(throws: ValidationError.repsTooHigh) { try PlannedSetFormatting.values(repsMin: "8", repsMax: "101", weight: "") }
        #expect(throws: ValidationError.repsTooHigh) { try PlannedSetFormatting.values(repsMin: "8", repsMax: "99999999999999999999", weight: "") }
        #expect(throws: ValidationError.invalidRepsMin) { try PlannedSetFormatting.values(repsMin: "0", repsMax: "8", weight: "") }
        #expect(throws: ValidationError.invalidWeight) { try PlannedSetFormatting.values(repsMin: "8", repsMax: "12", weight: "abc") }
        #expect(throws: ValidationError.weightTooHigh) { try PlannedSetFormatting.values(repsMin: "8", repsMax: "12", weight: "1001") }
        #expect(try PlannedSetFormatting.values(repsMin: "8", repsMax: "12", weight: "1000") == .reps(8, 12, kg: 1_000))
        #expect(throws: PlannedSetInputError.thousandsSeparator) { try PlannedSetFormatting.values(repsMin: "8", repsMax: "12", weight: "1.000") }
        #expect(throws: PlannedSetInputError.thousandsSeparator) { try PlannedSetFormatting.values(repsMin: "8", repsMax: "12", weight: "1,000") }
    }
}
