#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The ready-made data the interface tests ask for with `-ui-seed`: what each item creates, and that
/// the hook does nothing unless the app was launched for interface tests.
@MainActor
struct UITestSeedTests {
    /// An in-memory store with the built-in exercise library, like the one the app opens for UI tests.
    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainerFactory.makeInMemory()
        try ExerciseLibrarySeeder(context: container.mainContext).seed()
        return container
    }

    @Test("A list of items is read in order, with the exercises of a workout split by |")
    func parsesItems() throws {
        let items = try UITestSeed.parse("workout:Push:Crossover na Polia|Barra Fixa,workout:Vazio,plan-today:Push,finished:Push:4,session-detail:Push")

        #expect(items == [
            .workout(name: "Push", exercises: ["Crossover na Polia", "Barra Fixa"]),
            .workout(name: "Vazio", exercises: []),
            .planToday(workout: "Push"),
            .finishedSessions(workout: "Push", count: 4),
            .sessionDetail(workout: "Push"),
        ])
    }

    @Test("An item it does not know, or one without what it needs, is refused")
    func refusesUnknownItems() {
        for list in ["unknown:1", "workout", "finished:Push", "finished:Push:0", "finished:Push:many", "plan-today"] {
            #expect(throws: UITestSeed.SeedError.self) { try UITestSeed.parse(list) }
        }
    }

    @Test("A workout comes with its exercises in order, each with the default planned sets")
    func createsWorkouts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Crossover na Polia|Barra Fixa,workout:Vazio"), in: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 2)
        let push = try #require(workouts.first { $0.name == "Push" })
        #expect(push.orderedExercises.compactMap { $0.exercise?.name } == ["Crossover na Polia", "Barra Fixa"])
        #expect(push.orderedExercises.map { $0.plannedSets.count } == [3, 3])
        let empty = try #require(workouts.first { $0.name == "Vazio" })
        #expect(empty.exercises.isEmpty)
    }

    @Test("A workout is planned for today's weekday, and finished sessions are dated in the past")
    func plansTodayAndFinishesSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa,plan-today:Push,finished:Push:4"), in: context)

        let push = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        let plan = try context.fetch(FetchDescriptor<WeeklyPlanDay>())
        #expect(plan.count == 1)
        #expect(plan.first?.workoutID == push.id)
        #expect(plan.first?.weekday == TrainingDay.planWeekday(of: .now, calendar: TrainingDay.calendar))

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 4)
        #expect(sessions.allSatisfy { $0.endedAt != nil && $0.startedAt < .now })
        // 40 minutes, within the rounding of the date arithmetic.
        #expect(sessions.allSatisfy { abs(($0.duration ?? 0) - 2_400) < 0.001 })
        #expect(sessions.allSatisfy { $0.workout?.id == push.id })
        // The recent sessions are the latest three, the most recent first.
        let recent = try context.fetch(SessionService.recentSessionsDescriptor)
        #expect(recent.count == 3)
        #expect(recent == recent.sorted { $0.startedAt > $1.startedAt })
        #expect(recent.first?.startedAt == sessions.map(\.startedAt).max())
    }

    @Test("The session for the history detail has two sets done with their values and one not done")
    func createsTheSessionForTheDetail() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa,session-detail:Push"), in: context)

        let session = try #require(try context.fetch(FetchDescriptor<Session>()).first)
        #expect(session.endedAt != nil)
        let logs = try #require(session.orderedExercises.first).orderedSetLogs
        #expect(logs.count == 3)
        #expect(logs.map(\.isCompleted) == [true, true, false])
        #expect(logs.map(\.weightKg) == [20, nil, nil])
        #expect(logs.map(\.reps) == [10, 12, nil])
    }

    @Test("A workout or an exercise that does not exist is an error, and nothing else is created")
    func failsOnMissingData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        #expect(throws: UITestSeed.SeedError.self) {
            try UITestSeed.apply(try UITestSeed.parse("plan-today:Inexistente"), in: context)
        }
        #expect(throws: UITestSeed.SeedError.self) {
            try UITestSeed.apply(try UITestSeed.parse("workout:Push:Exercício que não existe"), in: context)
        }
        #expect(try context.fetch(FetchDescriptor<WeeklyPlanDay>()).isEmpty)
    }

    @Test("The hook acts only with -ui-testing and -ui-seed together")
    func actsOnlyForInterfaceTests() throws {
        let container = try makeContainer()
        let context = container.mainContext

        UITestSeed.applyIfRequested(in: container, arguments: ["-ui-seed", "workout:Push"])
        #expect(try context.fetch(FetchDescriptor<Workout>()).isEmpty, "-ui-seed alone created data")

        UITestSeed.applyIfRequested(in: container, arguments: ["-ui-testing"])
        #expect(try context.fetch(FetchDescriptor<Workout>()).isEmpty, "-ui-testing alone created data")

        UITestSeed.applyIfRequested(in: container, arguments: ["-ui-testing", "-ui-seed", "workout:Push"])
        #expect(try context.fetch(FetchDescriptor<Workout>()).map(\.name) == ["Push"])
    }
}
#endif
