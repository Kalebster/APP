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
        let items = try UITestSeed.parse("workout:Push:Crossover na Polia Alta|Barra Fixa Pronada,workout:Vazio,plan-today:Push,finished:Push:4,session-detail:Push,open-session:Push,plan:Push:1|3|7,finished-today:Push,last-time:Push,custom-exercise:Meu Supino:chest")

        #expect(items == [
            .workout(name: "Push", exercises: ["Crossover na Polia Alta", "Barra Fixa Pronada"]),
            .workout(name: "Vazio", exercises: []),
            .planToday(workout: "Push"),
            .finishedSessions(workout: "Push", count: 4),
            .sessionDetail(workout: "Push"),
            .openSession(workout: "Push"),
            .plan(workout: "Push", weekdays: [1, 3, 7]),
            .finishedToday(workout: "Push"),
            .lastTime(workout: "Push"),
            .customExercise(name: "Meu Supino", group: .chest),
        ])
    }

    @Test("An item it does not know, or one without what it needs, is refused")
    func refusesUnknownItems() {
        for list in ["unknown:1", "workout", "finished:Push", "finished:Push:0", "finished:Push:many", "plan-today", "open-session",
                     "plan:Push", "plan:Push:0", "plan:Push:8", "plan:Push:segunda", "finished-today", "last-time",
                     "custom-exercise:Meu Supino", "custom-exercise:Meu Supino:peito"] {
            #expect(throws: UITestSeed.SeedError.self) { try UITestSeed.parse(list) }
        }
    }

    @Test("A workout comes with its exercises in order, each with the default planned sets")
    func createsWorkouts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Crossover na Polia Alta|Barra Fixa Pronada,workout:Vazio"), in: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 2)
        let push = try #require(workouts.first { $0.name == "Push" })
        #expect(push.orderedExercises.compactMap { $0.exercise?.name } == ["Crossover na Polia Alta", "Barra Fixa Pronada"])
        #expect(push.orderedExercises.map { $0.plannedSets.count } == [3, 3])
        let empty = try #require(workouts.first { $0.name == "Vazio" })
        #expect(empty.exercises.isEmpty)
    }

    @Test("A workout is planned for today's weekday, and finished sessions are dated in the past")
    func plansTodayAndFinishesSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa Pronada,plan-today:Push,finished:Push:4"), in: context)

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

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa Pronada,session-detail:Push"), in: context)

        let session = try #require(try context.fetch(FetchDescriptor<Session>()).first)
        #expect(session.endedAt != nil)
        let logs = try #require(session.orderedExercises.first).orderedSetLogs
        #expect(logs.count == 3)
        #expect(logs.map(\.isCompleted) == [true, true, false])
        #expect(logs.map(\.weightKg) == [20, nil, nil])
        #expect(logs.map(\.reps) == [10, 12, nil])
    }

    @Test("A workout is planned for the given weekdays, and a session of it is finished today")
    func plansWeekdaysAndFinishesToday() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let before = Date.now

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa Pronada,plan:Push:1|3|7,finished-today:Push"), in: context)

        let push = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        let plan = try context.fetch(FetchDescriptor<WeeklyPlanDay>())
        #expect(Set(plan.map(\.weekday)) == [1, 3, 7])
        #expect(plan.allSatisfy { $0.workoutID == push.id })

        let session = try #require(try context.fetch(FetchDescriptor<Session>()).first)
        let calendar = TrainingDay.calendar
        #expect(session.workout?.id == push.id)
        #expect(session.endedAt != nil)
        #expect(calendar.isDate(session.startedAt, inSameDayAs: before))
        // 55 minutes, or less just after midnight.
        #expect((session.duration ?? 0) <= 3_300 + 1)
        #expect(session.orderedExercises[0].orderedSetLogs[0].isCompleted)
    }

    @Test("The session left open started 3 hours ago, has its first set done 2 hours ago and is not finished")
    func leavesASessionOpen() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let before = Date.now

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa Pronada,open-session:Push"), in: context)

        let after = Date.now
        let service = SessionService(context: context)
        let session = try #require(try service.activeSession())
        #expect(session.workout?.name == "Push")
        // Dated from the moment the seed ran.
        #expect(session.startedAt >= before.addingTimeInterval(-10_800))
        #expect(session.startedAt <= after.addingTimeInterval(-10_800))
        let logs = session.orderedExercises.flatMap(\.orderedSetLogs)
        #expect(logs.map(\.isCompleted) == [true, false, false])
        #expect(logs.first?.reps == 10)
        #expect(logs.first?.completedAt == session.startedAt.addingTimeInterval(3_600))
        // Finishing it now offers the time of that set as the end.
        #expect(service.suggestedEnd(for: session) == logs.first?.completedAt)
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

    @Test("The last time is a session finished yesterday with every set done, the loads by exercise and the repetitions by set")
    func createsTheLastTime() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Crossover na Polia Alta|Barra Fixa Pronada,last-time:Push"), in: context)

        let session = try #require(try context.fetch(FetchDescriptor<Session>()).first)
        let ended = try #require(session.endedAt)
        #expect(session.startedAt < Date.now.addingTimeInterval(-86_000))
        // 45 minutes, within the rounding of the date arithmetic.
        #expect(abs(ended.timeIntervalSince(session.startedAt) - 2_700) < 0.001)
        let exercises = session.orderedExercises
        #expect(exercises.map { $0.orderedSetLogs.map(\.weightKg) } == [[60, 60, 60], [22, 22, 22]])
        #expect(exercises.map { $0.orderedSetLogs.map(\.reps) } == [[10, 10, 9], [10, 10, 9]])
        #expect(exercises.allSatisfy { $0.setLogs.allSatisfy(\.isCompleted) })
        // It is what "Última vez" shows for a new session of the workout.
        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        let current = try SessionService(context: context).startSession(from: workout)
        let last = try SessionService(context: context).lastPerformances(for: current)
        let firstExercise = try #require(exercises[0].exercise)
        #expect(last[firstExercise.id] == [
            PreviousSet(weightKg: 60, reps: 10),
            PreviousSet(weightKg: 60, reps: 10),
            PreviousSet(weightKg: 60, reps: 9),
        ])
    }

    @Test("A custom exercise is created active, in its group, by the exercise service")
    func createsACustomExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("custom-exercise:Meu Supino:chest"), in: context)

        let custom = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))
        #expect(custom.map(\.name) == ["Meu Supino"])
        #expect(custom.first?.muscleGroup == .chest)
        #expect(custom.first?.isArchived == false)
        #expect(custom.first?.libraryKey == nil)
        // A name already used by an exercise of the library is refused, as in the app.
        #expect(throws: ValidationError.duplicateExerciseName) {
            try UITestSeed.apply(try UITestSeed.parse("custom-exercise:Supino Reto com Barra:chest"), in: context)
        }
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

    @Test("The list arrives percent-encoded, so an accented exercise name is found as written")
    func decodesThePercentEncodedList() throws {
        let container = try makeContainer()
        let list = try #require("workout:Push:Tríceps na Polia com Corda|Barra Fixa Pronada".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let isASCII = list.allSatisfy(\.isASCII)
        #expect(isASCII, "Encoded list: \(list)")

        UITestSeed.applyIfRequested(in: container, arguments: ["-ui-testing", "-ui-seed", list])

        let push = try #require(try container.mainContext.fetch(FetchDescriptor<Workout>()).first)
        #expect(push.orderedExercises.compactMap { $0.exercise?.name } == ["Tríceps na Polia com Corda", "Barra Fixa Pronada"])
    }
}
#endif
