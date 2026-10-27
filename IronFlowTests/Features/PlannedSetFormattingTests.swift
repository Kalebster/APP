import Foundation
import Testing
@testable import IronFlow

struct PlannedSetFormattingTests {
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
        // At most two decimals: "12,5" and "12.5" are 12,5 kg, and a text with three or more decimals
        // or a thousands separator is reported, never read as another number.
        #expect(try PlannedSetFormatting.weightKg("12,5") == 12.5)
        #expect(try PlannedSetFormatting.weightKg("12.5") == 12.5)
        #expect(try PlannedSetFormatting.weightKg("12,50") == 12.5)
        #expect(try PlannedSetFormatting.weightKg("12,25") == 12.25)
        for tooPrecise in ["12,500", "12.500", "1.000", "1,000", "1.500", "1,0000", "82.5055", "0,125"] {
            #expect(throws: ValidationError.tooManyDecimals) { try PlannedSetFormatting.weightKg(tooPrecise) }
        }
        for grouped in ["1.000,5", "1,000.5", "1.000.000"] {
            #expect(throws: ValidationError.invalidWeight) { try PlannedSetFormatting.weightKg(grouped) }
        }
    }
}
