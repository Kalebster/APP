import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// "Concluir treino?": the sets done of all, the load lifted, the sets that will not be saved and the
/// duration up to the end chosen.
@MainActor
struct SessionFinishSummaryTests {
    private let container: ModelContainer
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    private func set(done: Bool, weight: Double? = nil, reps: Int? = nil, type: SetType = .working) -> SetLog {
        let log = SetLog(sortIndex: 0, weightKg: weight, reps: reps, setType: type)
        log.isCompleted = done
        container.mainContext.insert(log)
        return log
    }

    @Test("The boxes: the sets done of all, and the load of the working and failure sets done")
    func boxes() {
        let sets = [
            set(done: true, weight: 20, reps: 15, type: .warmup),
            set(done: true, weight: 60, reps: 10),
            set(done: true, weight: 50, reps: 12, type: .failure),
            set(done: false, weight: 60, reps: nil),
        ]
        let summary = SessionFinishSummary(sets: sets, startedAt: start, now: start.addingTimeInterval(42 * 60), suggestedEnd: nil)

        #expect(summary.doneSets == 3)
        #expect(summary.totalSets == 4)
        #expect(summary.notDoneSets == 1)
        #expect(summary.setsText == "3/4")
        #expect(summary.setsAccessibilityText == "3 de 4 séries feitas")
        #expect(summary.volumeKg == 1_200)
        #expect(SessionFormatting.kilogramsText(summary.volumeKg) == "1.200")
        #expect(SessionFormatting.volumeText(summary.volumeKg) == "1.200 kg levantados")
        #expect(summary.duration(endingAt: .now) == 42 * 60)
        // Without a session left open, the end is always now.
        #expect(summary.duration(endingAt: .lastCompletedSet) == 42 * 60)
    }

    @Test("What will not be saved: one set, several sets, or nothing when every set is done")
    func setsNotDone() {
        func summary(done: Int, notDone: Int) -> SessionFinishSummary {
            let sets = (0..<done).map { _ in set(done: true, reps: 10) } + (0..<notDone).map { _ in set(done: false) }
            return SessionFinishSummary(sets: sets, startedAt: start, now: start, suggestedEnd: nil)
        }
        #expect(summary(done: 2, notDone: 1).notDoneText == "A série não marcada não será salva.")
        #expect(summary(done: 1, notDone: 3).notDoneText == "As 3 séries não marcadas não serão salvas.")
        #expect(summary(done: 2, notDone: 0).notDoneText == nil)
        #expect(summary(done: 1, notDone: 0).setsAccessibilityText == "1 de 1 série feita")
        // Nothing done: the sheet says so instead.
        #expect(summary(done: 0, notDone: 2).doneSets == 0)
        #expect(summary(done: 0, notDone: 0).totalSets == 0)
    }

    @Test("A session left open: the duration follows the end chosen")
    func sessionLeftOpen() {
        let lastRecord = start.addingTimeInterval(3_600)
        let summary = SessionFinishSummary(
            sets: [set(done: true, reps: 10)],
            startedAt: start,
            now: start.addingTimeInterval(3 * 3_600),
            suggestedEnd: lastRecord
        )
        #expect(summary.duration(endingAt: .lastCompletedSet) == 3_600)
        #expect(summary.duration(endingAt: .now) == 3 * 3_600)
        #expect(SessionFormatting.compactDurationText(summary.duration(endingAt: .lastCompletedSet)) == "1 h")
    }

    @Test("The notice once saved: every set done, and the load lifted only when there is one")
    func savedNotice() {
        #expect(SessionFinishSummary.savedText(doneSets: 5, volumeKg: 2_640) == "Treino salvo · 5 séries · 2.640 kg")
        #expect(SessionFinishSummary.savedText(doneSets: 1, volumeKg: 0) == "Treino salvo · 1 série")
        // Rounded like the load lifted: less than half a kilogram is no load.
        #expect(SessionFinishSummary.savedText(doneSets: 2, volumeKg: 0.4) == "Treino salvo · 2 séries")
        #expect(SessionFinishSummary.savedText(doneSets: 1, volumeKg: 99.6) == "Treino salvo · 1 série · 100 kg")
    }

    @Test("The duration as VoiceOver reads it")
    func spokenDuration() {
        #expect(SessionFormatting.spokenDurationText(10) == "1 minuto")
        #expect(SessionFormatting.spokenDurationText(42 * 60) == "42 minutos")
        #expect(SessionFormatting.spokenDurationText(60 * 60) == "1 hora")
        #expect(SessionFormatting.spokenDurationText(61 * 60) == "1 hora e 1 minuto")
        #expect(SessionFormatting.spokenDurationText(125 * 60) == "2 horas e 5 minutos")
        #expect(SessionFormatting.spokenDurationText(-30) == "1 minuto")
    }
}
