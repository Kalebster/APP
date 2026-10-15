import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The history detail shows what a finished session recorded, and only that.
@MainActor
struct HistorySessionDetailTests {
    @Test("The detail shows what the session recorded: name, start, duration, exercises, targets, loads, repetitions and states")
    func recordedValues() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let graph = SampleGraph.insert(into: container.mainContext)
        try container.mainContext.save()

        let detail = HistorySessionDetail(graph.session)

        #expect(detail.name == "Push")
        #expect(detail.startedAt == SampleGraph.sessionStart)
        #expect(detail.duration == 3_600)
        #expect(detail.exercises.map(\.id) == [graph.benchPerformed.id, graph.curlPerformed.id])
        #expect(detail.exercises.map(\.name) == ["Supino Reto", "Rosca Direta"])
        #expect(detail.exercises.map(\.muscleGroup) == [.chest, .biceps])

        let bench = detail.exercises[0].sets
        #expect(bench.map(\.id) == [graph.completedSet.id, graph.notCompletedSet.id])
        #expect(bench.map(\.number) == [1, 2])
        #expect(bench.map(\.targetRepsMin) == [8, 6])
        #expect(bench.map(\.targetRepsMax) == [10, 8])
        #expect(bench.map(\.weightKg) == [20, nil])
        #expect(bench.map(\.reps) == [10, nil])
        #expect(bench.map(\.isCompleted) == [true, false])
        let curl = detail.exercises[1].sets
        #expect(curl.map(\.id) == [graph.curlSet.id])
        #expect(curl.map(\.weightKg) == [nil])
        #expect(curl.map(\.reps) == [12])
        #expect(curl.map(\.isCompleted) == [true])

        // What the rows show and what VoiceOver reads: what was not recorded is "—", or said in words.
        #expect(bench[0].valuesText == "Meta: 8–10 · Carga: 20 kg · Reps: 10")
        #expect(bench[0].accessibilityText == "Série 1, Meta: 8–10, Carga: 20 kg, 10 repetições, Concluída")
        #expect(bench[1].valuesText == "Meta: 6–8 · Carga: — · Reps: —")
        #expect(bench[1].accessibilityText == "Série 2, Meta: 6–8, Sem carga, Sem repetições, Não concluída")
        #expect(curl[0].valuesText == "Meta: 10–12 · Carga: — · Reps: 12")
        #expect(curl[0].accessibilityText == "Série 1, Meta: 10–12, Sem carga, 12 repetições, Concluída")
    }

    @Test("Renaming the workout and the exercise, archiving the exercise and deleting the workout change nothing in the detail")
    func independentOfPlanAndLibrary() throws {
        let harness = try ServiceTestHarness()
        let curl = try harness.exercises.createCustomExercise(name: "Rosca Direta", muscleGroup: .biceps)
        let workout = try harness.makeWorkout(name: "Braço", items: [(curl, [.reps(10, 12, kg: 12.5), .reps(8, 10, kg: 15)])])
        harness.clock.advance(by: 60)
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: 12.5, reps: 11)
        harness.clock.advance(by: 45 * 60)
        try harness.sessions.finishSession(session)
        let before = HistorySessionDetail(session)

        try harness.workouts.rename(workout, to: "Bíceps")
        try harness.exercises.updateCustomExercise(curl, name: "Rosca Martelo", muscleGroup: .forearms)
        try harness.exercises.archive(curl)
        try harness.workouts.delete(workout)

        // The plan and the library really changed.
        #expect(curl.name == "Rosca Martelo")
        #expect(curl.muscleGroup == .forearms)
        #expect(curl.isArchived)
        #expect(try count(Workout.self, in: harness.context) == 0)

        let stored = try #require(try fetchSession(id: session.id, in: harness.context))
        let after = HistorySessionDetail(stored)
        #expect(after == before)
        #expect(after.name == "Braço")
        #expect(after.duration == 45 * 60)
        #expect(after.exercises.map(\.name) == ["Rosca Direta"])
        #expect(after.exercises.map(\.muscleGroup) == [.biceps])
        let sets = try #require(after.exercises.first?.sets)
        #expect(sets.map(\.targetRepsMin) == [10, 8])
        #expect(sets.map(\.targetRepsMax) == [12, 10])
        #expect(sets.map(\.weightKg) == [12.5, 15])
        #expect(sets.map(\.reps) == [11, nil])
        #expect(sets.map(\.isCompleted) == [true, false])
    }

    @Test("Exercises and sets follow their recorded order, and sets are numbered from 1 in that order")
    func recordedOrder() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let session = Session(startedAt: SampleGraph.sessionStart, workoutNameSnapshot: "Costas")
        session.endedAt = SampleGraph.sessionEnd
        context.insert(session)
        // Stored in neither the recorded order nor its reverse, so the order of insertion explains nothing.
        for (sortIndex, name) in [(1, "Remada Curvada"), (2, "Pulldown"), (0, "Barra Fixa")] {
            let performed = SessionExercise(sortIndex: sortIndex, exerciseNameSnapshot: name, muscleGroupSnapshot: .back)
            context.insert(performed)
            performed.session = session
            for setIndex in [2, 0, 1] {
                let log = SetLog(sortIndex: setIndex, reps: setIndex + 1)
                context.insert(log)
                log.sessionExercise = performed
            }
        }
        try context.save()

        let detail = HistorySessionDetail(session)

        #expect(detail.exercises.map(\.name) == ["Barra Fixa", "Remada Curvada", "Pulldown"])
        for exercise in detail.exercises {
            #expect(exercise.sets.map(\.number) == [1, 2, 3])
            #expect(exercise.sets.map(\.reps) == [1, 2, 3])
        }
        // One repetition is read in the singular.
        #expect(detail.exercises[0].sets[0].accessibilityText == "Série 1, Sem meta, Sem carga, 1 repetição, Não concluída")
    }

    @Test("A session without a name is a Treino livre, and a session or exercise without records shows none")
    func emptyRecords() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let free = Session(startedAt: SampleGraph.sessionStart, workoutNameSnapshot: "")
        free.endedAt = SampleGraph.sessionEnd
        context.insert(free)
        let withoutSets = Session(startedAt: SampleGraph.sessionStart, workoutNameSnapshot: "Push")
        withoutSets.endedAt = SampleGraph.sessionEnd
        context.insert(withoutSets)
        let performed = SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Supino Reto", muscleGroupSnapshot: .chest)
        context.insert(performed)
        performed.session = withoutSets
        try context.save()

        let freeDetail = HistorySessionDetail(free)
        #expect(freeDetail.name == "Treino livre")
        #expect(freeDetail.exercises.isEmpty)

        let detail = HistorySessionDetail(withoutSets)
        #expect(detail.exercises.map(\.name) == ["Supino Reto"])
        #expect(detail.exercises.map(\.sets) == [[]])
    }
}
