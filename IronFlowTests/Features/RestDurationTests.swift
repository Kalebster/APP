import Testing
@testable import IronFlow

struct RestDurationTests {
    @Test("The choices of the sheet, in order, and the texts shown and read")
    func texts() {
        #expect(RestDuration.choices == [30, 45, 60, 90, 120, 150, 180, 240, 300])
        #expect(RestDuration.choices.map(RestDuration.text) == ["0:30", "0:45", "1:00", "1:30", "2:00", "2:30", "3:00", "4:00", "5:00"])
        #expect(RestDuration.text(0) == "Sem timer")
        #expect(RestDuration.spokenText(90) == "1 min 30 s")
        #expect(RestDuration.spokenText(45) == "45 s")
        #expect(RestDuration.spokenText(120) == "2 min")
        #expect(RestDuration.spokenText(0) == "Sem timer")
    }

    @Test("Only 0 to 1 hour can be stored")
    func validity() {
        #expect(RestDuration.isValid(0))
        #expect(RestDuration.isValid(3_600))
        #expect(!RestDuration.isValid(-1))
        #expect(!RestDuration.isValid(3_601))
    }
}
