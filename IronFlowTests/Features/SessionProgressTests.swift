import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The session in progress: the sets done, the current exercise and set, the load lifted, the targets
/// and the closed card of a finished exercise.
@MainActor
struct SessionProgressTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    /// A set kept in the in-memory store.
    private func set(
        done: Bool = false,
        weight: Double? = nil,
        reps: Int? = nil,
        min: Int? = nil,
        max: Int? = nil
    ) -> SetLog {
        let log = SetLog(sortIndex: 0, weightKg: weight, reps: reps, targetRepsMin: min, targetRepsMax: max)
        log.isCompleted = done
        container.mainContext.insert(log)
        return log
    }

    @Test("The sets done, the current exercise and its first set not done")
    func progress() {
        let first = [set(done: true), set(done: true)]
        let secondSets = [set(done: true), set(), set()]
        let third = [set(), set()]
        let progress = SessionProgress(sets: [first, secondSets, third])

        #expect(progress.completedSets == 3)
        #expect(progress.totalSets == 7)
        #expect(progress.exerciseCount == 3)
        #expect(progress.currentExerciseIndex == 1)
        #expect(progress.currentSetID == secondSets[1].id)
        #expect(progress.setsText == "3 de 7 séries")
        #expect(progress.exerciseText == "Exercício 2 de 3")
        #expect(abs(progress.fraction - 3.0 / 7.0) < 0.0001)
    }

    @Test("A set not done in an earlier exercise makes that exercise the current one")
    func currentIsTheFirstExerciseWithASetNotDone() {
        let first = [set(done: true), set()]
        let second = [set(), set()]
        let progress = SessionProgress(sets: [first, second])

        #expect(progress.currentExerciseIndex == 0)
        #expect(progress.currentSetID == first[1].id)
    }

    @Test("With every set done, the last exercise; without exercises, no exercise text")
    func everythingDoneAndNothingToDo() {
        let done = SessionProgress(sets: [[set(done: true)], [set(done: true), set(done: true)]])
        #expect(done.currentExerciseIndex == nil)
        #expect(done.currentSetID == nil)
        #expect(done.setsText == "3 de 3 séries")
        #expect(done.exerciseText == "Exercício 2 de 2")
        #expect(done.fraction == 1)

        let empty = SessionProgress(sets: [])
        #expect(empty.setsText == "0 de 0 séries")
        #expect(empty.exerciseText == nil)
        #expect(empty.fraction == 0)

        // An exercise without sets is never the current one.
        let noSets = SessionProgress(sets: [[], [set()]])
        #expect(noSets.currentExerciseIndex == 1)
        #expect(SessionProgress(sets: [[set()]]).setsText == "0 de 1 série")
    }

    @Test("The load lifted counts load × repetitions of the sets done that have a load")
    func volume() {
        let sets = [
            set(done: true, weight: 60, reps: 10),
            set(done: true, weight: 22.5, reps: 8),
            set(done: true, weight: nil, reps: 12),
            set(done: false, weight: 100, reps: 10),
        ]
        #expect(SessionProgress.volumeKg(of: sets) == 780)
        #expect(SessionProgress.volumeKg(of: []) == 0)
        #expect(SessionFormatting.volumeText(2_440) == "2.440 kg levantados")
        #expect(SessionFormatting.volumeText(780.4) == "780 kg levantados")
        #expect(SessionFormatting.volumeText(0) == "0 kg levantados")
    }

    @Test("An exercise is finished when it has sets and all are done")
    func finished() {
        #expect(SessionProgress.isFinished([set(done: true), set(done: true)]))
        #expect(!SessionProgress.isFinished([set(done: true), set()]))
        #expect(!SessionProgress.isFinished([]))
    }

    @Test("The targets go from the lowest minimum to the highest maximum")
    func targets() {
        #expect(SessionProgress.targetText(of: [set(min: 8, max: 12), set(min: 6, max: 10)]) == "meta 6–12 reps")
        #expect(SessionProgress.targetText(of: [set(min: 10, max: 10)]) == "meta 10 reps")
        #expect(SessionProgress.targetText(of: [set(max: 12)]) == "meta 12 reps")
        #expect(SessionProgress.targetText(of: [set(), set()]) == nil)
    }

    @Test("The closed card repeats the load only when it changes")
    func doneSummary() {
        let sets = [
            set(done: true, weight: 60, reps: 10),
            set(done: true, weight: 60, reps: 10),
            set(done: true, weight: 60, reps: 9),
            set(done: true, weight: 62.5, reps: 8),
        ]
        #expect(SessionProgress.doneSummary(of: sets) == "60 kg × 10 · 10 · 9 · 62,5 kg × 8")
        // Without a load, only the repetitions.
        #expect(SessionProgress.doneSummary(of: [set(done: true, reps: 12), set(done: true, reps: 10)]) == "12 · 10")
    }
}
