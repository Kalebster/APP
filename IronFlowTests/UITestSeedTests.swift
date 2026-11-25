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
        let items = try UITestSeed.parse("workout:Push:Crossover (Polia Alta)|Barra Fixa (Pegada Aberta),workout:Vazio,plan-today:Push,finished:Push:4,session-detail:Push,open-session:Push,plan:Push:1|3|7,finished-today:Push,last-time:Push,custom-exercise:Meu Supino:chest,set-types:Push,weights:81.2@14|80.6@7|80@2,profile:180:2300,bmr:male:30:lose")

        #expect(items == [
            .workout(name: "Push", exercises: ["Crossover (Polia Alta)", "Barra Fixa (Pegada Aberta)"]),
            .workout(name: "Vazio", exercises: []),
            .planToday(workout: "Push"),
            .finishedSessions(workout: "Push", count: 4),
            .sessionDetail(workout: "Push"),
            .openSession(workout: "Push"),
            .plan(workout: "Push", weekdays: [1, 3, 7]),
            .finishedToday(workout: "Push"),
            .lastTime(workout: "Push"),
            .customExercise(name: "Meu Supino", group: .chest),
            .setTypes(workout: "Push"),
            .weights([
                UITestSeed.WeightRecord(weightKg: 81.2, daysAgo: 14),
                UITestSeed.WeightRecord(weightKg: 80.6, daysAgo: 7),
                UITestSeed.WeightRecord(weightKg: 80, daysAgo: 2),
            ]),
            .profile(heightCm: 180, goalKcal: 2_300),
            .bmr(sex: .male, age: 30, goal: .lose),
        ])
    }

    @Test("An item it does not know, or one without what it needs, is refused")
    func refusesUnknownItems() {
        for list in ["unknown:1", "workout", "finished:Push", "finished:Push:0", "finished:Push:many", "plan-today", "open-session",
                     "plan:Push", "plan:Push:0", "plan:Push:8", "plan:Push:segunda", "finished-today", "last-time",
                     "custom-exercise:Meu Supino", "custom-exercise:Meu Supino:peito", "set-types", "set-types:Push:1",
                     "weights", "weights:", "weights:80", "weights:abc@1", "weights:80@-1", "profile:180", "profile:alto:2300",
                     "bmr:male:30", "bmr:homem:30:lose", "bmr:male:trinta:lose", "bmr:male:30:perder", "bmr:male:-1:lose"] {
            #expect(throws: UITestSeed.SeedError.self) { try UITestSeed.parse(list) }
        }
    }

    @Test("Body weights are recorded on their days, and the profile gets its height, goal and calculator's choices")
    func createsBodyData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("weights:81.2@14|80.6@7|80@0,profile:180:2300,bmr:female:30:gain"), in: context)

        let weights = try context.fetch(ProfileService.recentWeightsDescriptor)
        #expect(weights.map(\.weightKg) == [80, 80.6, 81.2])
        let profile = try #require(try ProfileService(context: context).profile())
        #expect(profile.heightCm == 180)
        #expect(profile.dailyCalorieGoalKcal == 2_300)
        #expect(profile.sex == .female)
        let thisYear = TrainingDay.calendar.component(.year, from: .now)
        #expect(profile.birthDate == BirthDate(day: 1, month: 1, year: thisYear - 30))
        #expect(BMRCalculator.age(of: profile.birthDate, on: .now, calendar: TrainingDay.calendar) == 30)
        #expect(profile.weightGoal == .gain)
        #expect(profile.activityLevel == .moderate)
    }

    @Test("A workout comes with its exercises in order, each with the default planned sets")
    func createsWorkouts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Crossover (Polia Alta)|Barra Fixa (Pegada Aberta),workout:Vazio"), in: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 2)
        let push = try #require(workouts.first { $0.name == "Push" })
        #expect(push.orderedExercises.compactMap { $0.exercise?.name } == ["Crossover (Polia Alta)", "Barra Fixa (Pegada Aberta)"])
        #expect(push.orderedExercises.map { $0.plannedSets.count } == [3, 3])
        let empty = try #require(workouts.first { $0.name == "Vazio" })
        #expect(empty.exercises.isEmpty)
    }

    @Test("A workout is planned for today's weekday, and finished sessions are dated in the past")
    func plansTodayAndFinishesSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa (Pegada Aberta),plan-today:Push,finished:Push:4"), in: context)

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

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa (Pegada Aberta),session-detail:Push"), in: context)

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

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa (Pegada Aberta),plan:Push:1|3|7,finished-today:Push"), in: context)

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

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Barra Fixa (Pegada Aberta),open-session:Push"), in: context)

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

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Crossover (Polia Alta)|Barra Fixa (Pegada Aberta),last-time:Push"), in: context)

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
            try UITestSeed.apply(try UITestSeed.parse("custom-exercise:Supino Reto (Barra):chest"), in: context)
        }
    }

    @Test("An exercise of the user's own gets its equipment, kind of machine and muscles, and is archived when asked")
    func createsAnOwnExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse(
            "own-exercise:Puxada na Máquina Articulada:back:machine:lever:lats:biceps|upperBack,own-exercise:Remada Livre:upperBack:other::upperBack::archived"
        ), in: context)

        let custom = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))
        let puxada = try #require(custom.first { $0.name == "Puxada na Máquina Articulada" })
        #expect(puxada.equipment == .machine)
        #expect(puxada.machineType == .lever)
        #expect(puxada.primaryMuscles == [.lats])
        #expect(puxada.secondaryMuscles == [.biceps, .upperBack])
        #expect(puxada.isArchived == false)
        let free = try #require(custom.first { $0.name == "Remada Livre" })
        #expect(free.equipment == nil)
        #expect(free.machineType == nil)
        #expect(free.secondaryMuscles.isEmpty)
        #expect(free.isArchived)
        for list in ["own-exercise:A:back:machine:lever:lats", "own-exercise:A:costas:machine::lats:", "own-exercise:A:back:trator::lats:",
                     "own-exercise:A:back:machine:hidraulica:lats:", "own-exercise:A:back:machine::pescoco:", "own-exercise:A:back:machine::lats::sim"] {
            #expect(throws: UITestSeed.SeedError.self) { try UITestSeed.parse(list) }
        }
    }

    @Test("The prototype's history with its exercise of the user's own: in the last 6 Pull, the others unchanged")
    func prototypeHistoryWithTheOwnExercise() throws {
        let without = UITestPrototypeHistory.sessions()
        let with = UITestPrototypeHistory.sessions(includingOwn: true)
        let own = UITestPrototypeHistory.ownExerciseName
        #expect(without.allSatisfy { session in !session.exercises.contains { $0.name == own } })
        let pulls = with.filter { $0.exercises.contains { $0.name == own } }
        #expect(pulls.count == 6)
        #expect(pulls.allSatisfy { $0.name == "Pull" })
        #expect(pulls.first?.day == DateComponents(year: 2026, month: 10, day: 12))
        // Its sets come last in the prototype's sequence: every other exercise keeps its sets.
        let others = with.map { session in session.exercises.filter { $0.name != own } }
        #expect(others == without.map(\.exercises))
        let last = try #require(pulls.first?.exercises.first { $0.name == own })
        #expect(last.sets.map(\.weightKg) == [50, 50, 50])
        #expect(last.sets.map(\.reps) == [12, 11, 10])

        let container = try makeContainer()
        let context = container.mainContext
        try UITestSeed.apply(try UITestSeed.parse("own-exercise:\(own):back:machine:lever:lats:biceps|upperBack,prototype-history-own"), in: context)
        let puxada = try #require(try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom })).first)
        #expect(try ExerciseHistoryLoader(context: context).history(of: puxada).entries.count == 6)
        // At the start of their days, as the prototype's.
        let starts = try context.fetch(FetchDescriptor<Session>()).map(\.startedAt)
        #expect(starts.allSatisfy { TrainingDay.calendar.startOfDay(for: $0) == $0 })
    }

    @Test("The first exercise gets the sets of the editor's model, with their types; the others keep the default ones")
    func setsTheSetTypes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try UITestSeed.apply(try UITestSeed.parse("workout:Push:Supino Reto (Barra)|Supino Inclinado (Halter),set-types:Push"), in: context)

        let push = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        let first = push.orderedExercises[0].orderedPlannedSets
        #expect(first.map(\.setType) == [.warmup, .feeder, .working, .working, .failure])
        #expect(first.map(\.weightKg) == [40, 50, 60, 60, 55])
        #expect(first.map(\.repsMin) == [12, 5, 8, 8, 8])
        #expect(first.map(\.repsMax) == [15, 6, 10, 10, 12])
        #expect(push.orderedExercises[1].orderedPlannedSets.map(\.setType) == [.working, .working, .working])

        // A workout without exercises has no sets to change.
        #expect(throws: UITestSeed.SeedError.self) {
            try UITestSeed.apply(try UITestSeed.parse("workout:Vazio,set-types:Vazio"), in: context)
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

    @Test("The prototype's history and the years of one exercise are read as items; a bad one is refused")
    func parsesTheHistories() throws {
        #expect(try UITestSeed.parse("prototype-history,exercise-years:Supino Reto (Barra):3") == [
            .prototypeHistory,
            .exerciseYears(exercise: "Supino Reto (Barra)", years: 3),
        ])
        for list in ["prototype-history:1", "exercise-years:Supino Reto (Barra)", "exercise-years:Supino Reto (Barra):0", "exercise-years:Supino:dez"] {
            #expect(throws: UITestSeed.SeedError.self) { try UITestSeed.parse(list) }
        }
    }

    @Test("The prototype's history has its sessions and sets, as its script makes them")
    func prototypeHistoryMatchesThePrototype() throws {
        let sessions = UITestPrototypeHistory.sessions()
        #expect(sessions.count == 74)
        #expect(sessions.filter { $0.name == "Push" }.count == 24)
        #expect(sessions.filter { $0.name == "Pull" }.count == 25)
        #expect(sessions.filter { $0.name == "Pernas" }.count == 25)
        #expect(sessions.first?.day == DateComponents(year: 2026, month: 10, day: 15))
        #expect(sessions.last?.day == DateComponents(year: 2026, month: 4, day: 24))
        #expect(sessions.last?.durationMinutes == 61)
        #expect(sessions.prefix(6).map(\.durationMinutes) == [55, 48, 62, 58, 48, 65])

        // The sets of an exercise in its sessions, the oldest first.
        func history(_ name: String) -> [(DateComponents, [String])] {
            sessions.reversed().compactMap { session in
                session.exercises.first { $0.name == name }.map { exercise in
                    (session.day, exercise.sets.map { "\($0.type.rawValue):\(PlannedSetFormatting.weightFieldText($0.weightKg))x\($0.reps)" })
                }
            }
        }
        let bench = history("Supino Reto (Barra)")
        #expect(bench.count == 24)
        #expect(bench.first?.0 == DateComponents(year: 2026, month: 4, day: 29))
        #expect(bench.first?.1 == ["warmup:40x15", "feeder:50x6", "working:50x9", "working:48x8", "failure:43x11"])
        #expect(bench[10].0 == DateComponents(year: 2026, month: 7, day: 9))
        #expect(bench[10].1 == ["warmup:40x15", "feeder:50x6", "working:56x9", "working:54x8", "failure:49x11"])
        #expect(bench.last?.1 == ["warmup:40x15", "feeder:50x6", "working:62x10", "working:60x9", "failure:55x12"])
        #expect(history("Flexão").first?.1 == ["working:0x11", "working:0x10", "working:0x10"])
        #expect(history("Flexão").last?.1 == ["working:0x24", "working:0x21", "working:0x19"])
        #expect(history("Tríceps Corda (Polia)")[4].1 == ["working:17,5x14", "working:17,5x13", "failure:12,5x16"])
        #expect(history("Barra Fixa (Graviton)").count == 25)
        #expect(history("Barra Fixa (Graviton)")[3].1 == ["working:40x7", "working:40x6", "working:40x5"])
        #expect(history("Barra Fixa (Graviton)").last?.1 == ["working:25x8", "working:25x7", "working:25x6"])
        #expect(history("Agachamento Livre (Barra)")[12].1 == ["warmup:40x10", "working:90x8", "working:90x7", "working:90x6"])
        #expect(history("Leg Press 45° (Máquina)").last?.1 == ["working:180x15", "working:180x14", "working:180x13"])
        #expect(history("Elevação Lateral (Halter)").map(\.0) == [DateComponents(year: 2026, month: 10, day: 9)])
    }

    @Test("The histories are finished sessions of library exercises, read by the exercise screen")
    func createsTheHistories() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try UITestSeed.apply([.prototypeHistory, .exerciseYears(exercise: "Rosca Direta (Halter)", years: 1)], in: context)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 74 + 104)
        #expect(sessions.allSatisfy { $0.endedAt != nil })
        let bench = try #require(try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Supino Reto (Barra)" })).first)
        let history = try ExerciseHistoryLoader(context: context).history(of: bench)
        #expect(history.entries.count == 24)
        #expect(history.bestSet.map { ExerciseHistoryFormatting.setText($0.set) } == "62 kg × 10")
        let curl = try #require(try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Rosca Direta (Halter)" })).first)
        let curlHistory = try ExerciseHistoryLoader(context: context).history(of: curl)
        #expect(curlHistory.entries.count == 104)
        #expect(curlHistory.entries.last.map { Calendar.current.isDateInToday($0.startedAt) } == false)
    }

    @Test("The exercise screen's today is now, unless an interface test gives a day with -ui-today")
    func exerciseScreenToday() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        #expect(ExerciseDetailToday.current(arguments: [], now: now) == now)
        #expect(ExerciseDetailToday.current(arguments: ["-ui-today", "2026-10-16"], now: now) == now)
        let day = ExerciseDetailToday.current(arguments: ["-ui-testing", "-ui-today", "2026-10-16"], now: now)
        let components = TrainingDay.calendar.dateComponents([.year, .month, .day, .hour], from: day)
        #expect(components == DateComponents(year: 2026, month: 10, day: 16, hour: 0))
        #expect(ExerciseDetailToday.current(arguments: ["-ui-testing", "-ui-today", "ontem"], now: now) == now)
    }

    @Test("The list arrives percent-encoded, so an accented exercise name is found as written")
    func decodesThePercentEncodedList() throws {
        let container = try makeContainer()
        let list = try #require("workout:Push:Tríceps Corda (Polia)|Barra Fixa (Pegada Aberta)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let isASCII = list.allSatisfy(\.isASCII)
        #expect(isASCII, "Encoded list: \(list)")

        UITestSeed.applyIfRequested(in: container, arguments: ["-ui-testing", "-ui-seed", list])

        let push = try #require(try container.mainContext.fetch(FetchDescriptor<Workout>()).first)
        #expect(push.orderedExercises.compactMap { $0.exercise?.name } == ["Tríceps Corda (Polia)", "Barra Fixa (Pegada Aberta)"])
    }
}
#endif
