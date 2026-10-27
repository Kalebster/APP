import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// Stores written by every released schema version open with the current app and keep every value
/// and relationship. The stores are written by the models of their own version, whose fingerprints
/// are checked against the frozen ones first, so they are the stores those versions really wrote.
/// Every set of versions 1 to 4 becomes a working set: the type added by version 5. Every profile of
/// versions 2 to 5 gets the defaults of the choices added by version 6: no sex or date of birth, a
/// moderate activity level and the goal of keeping the weight.
@MainActor
struct MigrationTests {
    @Test("A version 1 store migrates to version 6, keeps every value and relationship, and its sets become working sets")
    func v1StoreMigrates() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        var history: [String] = []
        var ids: LegacyRecords.IDs?
        var plannedWorkoutID = UUID()

        do {
            let container = try makeStore(of: SchemaV1.self, at: storeURL)
            let context = container.mainContext
            ids = LegacyRecords.insert(into: context)
            try context.save()
            history = try legacyHistorySnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v1, "Not a version 1 store")
        let sessionID = try #require(ids?.session)

        do {
            let migrated = try ModelContainerFactory.makePersistent(at: storeURL)
            let context = migrated.mainContext

            #expect(try historySnapshot(context) == history)
            try expectEverySetIsAWorkingSet(in: context)
            #expect(try bodyDataSnapshot(context).isEmpty)
            #expect(try externalWorkoutDaySnapshot(context).isEmpty)
            #expect(try weeklyPlanSnapshot(context).isEmpty)
            try expectHistoricalMeaning(in: context, sessionID: sessionID)

            // The tables added by versions 2, 3 and 4 and the set type of version 5 work in the migrated store.
            let profile = ProfileService(context: context)
            try profile.recordWeight(80.5)
            try profile.setHeight(180)
            try markTrainedOutsideTheApp(in: context)
            plannedWorkoutID = try planWorkoutOnWednesday(in: context)
            try makeFirstPlannedSetAWarmUp(in: context)
            // The new type also updated the set and its workout: the store reopened must keep that too.
            history = try historySnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v6, "Store not migrated to version 6")

        // Closed and opened again: nothing was lost and the new data stays.
        let reopened = try ModelContainerFactory.makePersistent(at: storeURL)
        #expect(try historySnapshot(reopened.mainContext) == history)
        #expect(try ProfileService(context: reopened.mainContext).latestWeight()?.weightKg == 80.5)
        #expect(try ProfileService(context: reopened.mainContext).profile()?.heightCm == 180)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<ExternalWorkoutDay>()).map(\.day) == [Self.markedDay])
        try expectWednesdayPlan(in: reopened.mainContext, workoutID: plannedWorkoutID)
        try expectFirstPlannedSetIsAWarmUp(in: reopened.mainContext)
    }

    @Test("A version 2 store, with body data, migrates to version 6, keeps every value, and its sets become working sets")
    func v2StoreMigrates() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        var history: [String] = []
        var bodyData: [String] = []
        var ids: LegacyRecords.IDs?
        var plannedWorkoutID = UUID()

        do {
            let container = try makeStore(of: SchemaV2.self, at: storeURL)
            let context = container.mainContext
            ids = LegacyRecords.insert(into: context)
            context.insert(BodyWeightEntry(weightKg: 81.25, measuredAt: SampleGraph.sessionStart))
            context.insert(BodyWeightEntry(weightKg: 80.5, measuredAt: SampleGraph.sessionEnd))
            let profile = SchemaV2.UserProfile()
            profile.heightCm = 180
            context.insert(profile)
            try context.save()
            history = try legacyHistorySnapshot(context)
            bodyData = try legacyBodyDataSnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v2, "Not a version 2 store")
        let sessionID = try #require(ids?.session)

        do {
            let migrated = try ModelContainerFactory.makePersistent(at: storeURL)
            let context = migrated.mainContext
            #expect(try historySnapshot(context) == history)
            try expectEverySetIsAWorkingSet(in: context)
            #expect(try bodyDataSnapshot(context) == bodyData)
            try expectProfileChoicesAreTheDefaults(in: context)
            #expect(try externalWorkoutDaySnapshot(context).isEmpty)
            #expect(try weeklyPlanSnapshot(context).isEmpty)
            try expectHistoricalMeaning(in: context, sessionID: sessionID)
            #expect(try ProfileService(context: context).latestWeight()?.weightKg == 80.5)
            #expect(try ProfileService(context: context).profile()?.heightCm == 180)
            #expect(try ProfileService(context: context).profile()?.dailyCalorieGoalKcal == nil)

            // The tables added by versions 3 and 4 and the set type of version 5 work in the migrated store.
            try markTrainedOutsideTheApp(in: context)
            plannedWorkoutID = try planWorkoutOnWednesday(in: context)
            try makeFirstPlannedSetAWarmUp(in: context)
            // The new type also updated the set and its workout: the store reopened must keep that too.
            history = try historySnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v6, "Store not migrated to version 6")

        // Closed and opened again: nothing was lost and the new data stays.
        let reopened = try ModelContainerFactory.makePersistent(at: storeURL)
        #expect(try historySnapshot(reopened.mainContext) == history)
        #expect(try bodyDataSnapshot(reopened.mainContext) == bodyData)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<ExternalWorkoutDay>()).map(\.day) == [Self.markedDay])
        try expectWednesdayPlan(in: reopened.mainContext, workoutID: plannedWorkoutID)
        try expectFirstPlannedSetIsAWarmUp(in: reopened.mainContext)
    }

    @Test("A version 3 store, with body data and a day trained outside the app, migrates to version 6, keeps every value, and its sets become working sets")
    func v3StoreMigrates() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        var history: [String] = []
        var bodyData: [String] = []
        var markedDays: [String] = []
        var ids: LegacyRecords.IDs?
        var plannedWorkoutID = UUID()

        do {
            let container = try makeStore(of: SchemaV3.self, at: storeURL)
            let context = container.mainContext
            ids = LegacyRecords.insert(into: context)
            context.insert(BodyWeightEntry(weightKg: 80.5, measuredAt: SampleGraph.sessionEnd))
            let profile = SchemaV2.UserProfile()
            profile.heightCm = 180
            context.insert(profile)
            context.insert(ExternalWorkoutDay(day: Self.markedDay))
            try context.save()
            history = try legacyHistorySnapshot(context)
            bodyData = try legacyBodyDataSnapshot(context)
            markedDays = try externalWorkoutDaySnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v3, "Not a version 3 store")
        let sessionID = try #require(ids?.session)

        do {
            let migrated = try ModelContainerFactory.makePersistent(at: storeURL)
            let context = migrated.mainContext
            #expect(try historySnapshot(context) == history)
            try expectEverySetIsAWorkingSet(in: context)
            #expect(try bodyDataSnapshot(context) == bodyData)
            try expectProfileChoicesAreTheDefaults(in: context)
            #expect(try externalWorkoutDaySnapshot(context) == markedDays)
            #expect(try weeklyPlanSnapshot(context).isEmpty)
            try expectHistoricalMeaning(in: context, sessionID: sessionID)
            #expect(try ProfileService(context: context).profile()?.heightCm == 180)

            // The table added by version 4 and the set type of version 5 work in the migrated store.
            plannedWorkoutID = try planWorkoutOnWednesday(in: context)
            try makeFirstPlannedSetAWarmUp(in: context)
            // The new type also updated the set and its workout: the store reopened must keep that too.
            history = try historySnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v6, "Store not migrated to version 6")

        // Closed and opened again: nothing was lost and the new data stays.
        let reopened = try ModelContainerFactory.makePersistent(at: storeURL)
        #expect(try historySnapshot(reopened.mainContext) == history)
        #expect(try bodyDataSnapshot(reopened.mainContext) == bodyData)
        #expect(try externalWorkoutDaySnapshot(reopened.mainContext) == markedDays)
        try expectWednesdayPlan(in: reopened.mainContext, workoutID: plannedWorkoutID)
        try expectFirstPlannedSetIsAWarmUp(in: reopened.mainContext)
    }

    @Test("A version 4 store, with body data, a day trained outside the app and a weekly plan, migrates to version 6, keeps every value, and its sets become working sets")
    func v4StoreMigrates() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        var history: [String] = []
        var bodyData: [String] = []
        var markedDays: [String] = []
        var plan: [String] = []
        var ids: LegacyRecords.IDs?

        do {
            let container = try makeStore(of: SchemaV4.self, at: storeURL)
            let context = container.mainContext
            let written = LegacyRecords.insert(into: context)
            ids = written
            context.insert(BodyWeightEntry(weightKg: 80.5, measuredAt: SampleGraph.sessionEnd))
            let profile = SchemaV2.UserProfile()
            profile.heightCm = 180
            profile.dailyCalorieGoalKcal = 2_300
            context.insert(profile)
            context.insert(ExternalWorkoutDay(day: Self.markedDay))
            context.insert(WeeklyPlanDay(weekday: 3, workoutID: written.workout))
            try context.save()
            history = try legacyHistorySnapshot(context)
            bodyData = try legacyBodyDataSnapshot(context)
            markedDays = try externalWorkoutDaySnapshot(context)
            plan = try weeklyPlanSnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v4, "Not a version 4 store")
        let written = try #require(ids)

        do {
            let migrated = try ModelContainerFactory.makePersistent(at: storeURL)
            let context = migrated.mainContext
            #expect(try historySnapshot(context) == history)
            try expectEverySetIsAWorkingSet(in: context)
            #expect(try bodyDataSnapshot(context) == bodyData)
            try expectProfileChoicesAreTheDefaults(in: context)
            #expect(try externalWorkoutDaySnapshot(context) == markedDays)
            #expect(try weeklyPlanSnapshot(context) == plan)
            try expectHistoricalMeaning(in: context, sessionID: written.session)
            try expectWednesdayPlan(in: context, workoutID: written.workout)
            #expect(try ProfileService(context: context).profile()?.dailyCalorieGoalKcal == 2_300)

            // The set type of version 5 works in the migrated store.
            try makeFirstPlannedSetAWarmUp(in: context)
            // The new type also updated the set and its workout: the store reopened must keep that too.
            history = try historySnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v6, "Store not migrated to version 6")

        // Closed and opened again: nothing was lost and the new data stays.
        let reopened = try ModelContainerFactory.makePersistent(at: storeURL)
        #expect(try historySnapshot(reopened.mainContext) == history)
        #expect(try bodyDataSnapshot(reopened.mainContext) == bodyData)
        #expect(try externalWorkoutDaySnapshot(reopened.mainContext) == markedDays)
        #expect(try weeklyPlanSnapshot(reopened.mainContext) == plan)
        try expectFirstPlannedSetIsAWarmUp(in: reopened.mainContext)
    }

    @Test("A version 5 store, with every kind of record, migrates to version 6, keeps every value and set type, and its profile gets the calculator's defaults")
    func v5StoreMigrates() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        var history: [String] = []
        var setTypes: [String] = []
        var bodyData: [String] = []
        var choices: [String] = []
        var markedDays: [String] = []
        var plan: [String] = []
        var sessionID = UUID()

        do {
            // The main models of version 5 are still the app's, so `SampleGraph` writes them. Its profile
            // is the one of version 2.
            let container = try makeStore(of: SchemaV5.self, at: storeURL)
            let context = container.mainContext
            let graph = SampleGraph.insert(into: context)
            graph.completedSet.setType = .failure
            graph.notCompletedSet.setType = .warmup
            for planned in try context.fetch(FetchDescriptor<PlannedSet>()) where planned.weightKg == 20 {
                planned.setType = .warmup
            }
            context.insert(BodyWeightEntry(weightKg: 81.25, measuredAt: SampleGraph.sessionStart))
            context.insert(BodyWeightEntry(weightKg: 80.5, measuredAt: SampleGraph.sessionEnd))
            let profile = SchemaV2.UserProfile()
            profile.heightCm = 180
            profile.dailyCalorieGoalKcal = 2_300
            context.insert(profile)
            context.insert(ExternalWorkoutDay(day: Self.markedDay))
            context.insert(WeeklyPlanDay(weekday: 3, workoutID: graph.workout.id))
            try context.save()
            sessionID = graph.session.id
            history = try historySnapshot(context)
            setTypes = try allSetTypeKeys(context)
            bodyData = try legacyBodyDataSnapshot(context)
            markedDays = try externalWorkoutDaySnapshot(context)
            plan = try weeklyPlanSnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v5, "Not a version 5 store")
        #expect(setTypes == [
            "performed failure", "performed warmup", "performed working",
            "planned warmup", "planned working", "planned working",
        ])

        do {
            let migrated = try ModelContainerFactory.makePersistent(at: storeURL)
            let context = migrated.mainContext
            #expect(try historySnapshot(context) == history)
            #expect(try allSetTypeKeys(context) == setTypes)
            #expect(try bodyDataSnapshot(context) == bodyData)
            try expectProfileChoicesAreTheDefaults(in: context)
            #expect(try externalWorkoutDaySnapshot(context) == markedDays)
            #expect(try weeklyPlanSnapshot(context) == plan)
            let session = try #require(try fetchSession(id: sessionID, in: context))
            #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
            #expect(session.orderedExercises[0].orderedSetLogs.map(\.setType) == [.failure, .warmup])

            // The choices of version 6 work in the migrated store; a day beyond its month is its last.
            let service = ProfileService(context: context, now: { SampleGraph.sessionEnd })
            try service.setSex(.female)
            try service.setBirthDate(BirthDate(day: 31, month: 4, year: 1990))
            try service.setActivityLevel(.intense)
            try service.setWeightGoal(.lose)
            // The choices also updated the profile: the store reopened must keep that too.
            bodyData = try bodyDataSnapshot(context)
            choices = try profileChoicesSnapshot(context)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v6, "Store not migrated to version 6")

        // Closed and opened again: nothing was lost and the new choices stay.
        let reopened = try ModelContainerFactory.makePersistent(at: storeURL)
        let context = reopened.mainContext
        #expect(try historySnapshot(context) == history)
        #expect(try allSetTypeKeys(context) == setTypes)
        #expect(try bodyDataSnapshot(context) == bodyData)
        #expect(try profileChoicesSnapshot(context) == choices)
        #expect(try externalWorkoutDaySnapshot(context) == markedDays)
        #expect(try weeklyPlanSnapshot(context) == plan)
        let profile = try #require(try ProfileService(context: context).profile())
        #expect(profile.heightCm == 180)
        #expect(profile.dailyCalorieGoalKcal == 2_300)
        #expect(profile.sex == .female)
        #expect(profile.birthDate == BirthDate(day: 30, month: 4, year: 1990))
        #expect(profile.activityLevel == .intense)
        #expect(profile.weightGoal == .lose)
    }

    /// The stored type key of every set, each with its kind, sorted: the set types a version 5 store
    /// holds, compared before and after the migration.
    private func allSetTypeKeys(_ context: ModelContext) throws -> [String] {
        let keys = try storedSetTypeKeys(context)
        return (keys.planned.map { "planned \($0)" } + keys.performed.map { "performed \($0)" }).sorted()
    }

    /// Every profile has the defaults of the choices added by version 6, as the migration wrote them.
    private func expectProfileChoicesAreTheDefaults(in context: ModelContext) throws {
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        for profile in profiles {
            #expect(profile.sexRaw == nil)
            #expect([profile.birthDay, profile.birthMonth, profile.birthYear] == [nil, nil, nil])
            #expect(profile.activityLevelRaw == "moderate")
            #expect(profile.weightGoalRaw == "maintain")
        }
    }

    /// Every planned and performed set of `LegacyRecords` is stored as a working set: the migration wrote
    /// the type's default into each of them.
    private func expectEverySetIsAWorkingSet(in context: ModelContext) throws {
        let keys = try storedSetTypeKeys(context)
        #expect(keys.planned == Array(repeating: "working", count: LegacyRecords.plannedSetCount))
        #expect(keys.performed == Array(repeating: "working", count: LegacyRecords.setLogCount))
    }

    /// Makes the first planned set of the sample workout a warm-up through the service, as the editor does.
    private func makeFirstPlannedSetAWarmUp(in context: ModelContext) throws {
        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        let first = try #require(workout.orderedExercises.first?.orderedPlannedSets.first)
        try WorkoutService(context: context).setType(.warmup, of: first)
    }

    /// The first planned set of the sample workout is a warm-up and the others are still working sets.
    private func expectFirstPlannedSetIsAWarmUp(in context: ModelContext) throws {
        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        #expect(workout.orderedExercises.map { $0.orderedPlannedSets.map(\.setType) } == [[.warmup, .working], [.working]])
    }

    /// Plans the sample workout for Wednesday through the service, as the Workouts tab does. Returns
    /// the workout's id.
    private func planWorkoutOnWednesday(in context: ModelContext) throws -> UUID {
        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        try WeeklyPlanService(context: context).setWorkout(workout, for: 3)
        return workout.id
    }

    /// The store holds exactly the Wednesday plan of `planWorkoutOnWednesday(in:)`.
    private func expectWednesdayPlan(in context: ModelContext, workoutID: UUID) throws {
        let days = try context.fetch(FetchDescriptor<WeeklyPlanDay>())
        #expect(days.map(\.weekday) == [3])
        #expect(days.map(\.workoutID) == [workoutID])
    }

    /// The day `markTrainedOutsideTheApp(in:)` marks: the day `SampleGraph`'s session ended, in São Paulo.
    private static let markedDay = "2026-05-09"

    /// Marks a day as trained outside the app through the service, as the Home does.
    private func markTrainedOutsideTheApp(in context: ModelContext) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        let service = ExternalWorkoutService(context: context, now: { SampleGraph.sessionEnd }, calendar: calendar)
        let marking = try service.mark(SampleGraph.sessionEnd)
        #expect(marking.day == Self.markedDay)
    }

    /// The same values read through the app's relationships and services, as the screens read them.
    private func expectHistoricalMeaning(in context: ModelContext, sessionID: UUID) throws {
        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        #expect(workout.orderedExercises.map { $0.exercise?.name } == ["Supino Reto", "Rosca Direta"])
        #expect(workout.orderedExercises[0].orderedPlannedSets.map(\.weightKg) == [20, 22.25])
        #expect(workout.orderedExercises[1].orderedPlannedSets.map(\.weightKg) == [nil])

        // A finished session of the plan: snapshots, completed and not completed sets.
        let session = try #require(try fetchSession(id: sessionID, in: context))
        #expect(session.workout?.id == workout.id)
        #expect(session.endedAt == SampleGraph.sessionEnd)
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
        #expect(session.orderedExercises.map(\.muscleGroupSnapshot) == [.chest, .biceps])
        let logs = session.orderedExercises[0].orderedSetLogs
        #expect(logs.map(\.isCompleted) == [true, false])
        #expect(logs.map(\.reps) == [10, nil])
        #expect(logs.map(\.completedAt) == [SampleGraph.completedAt, nil])
        #expect(logs.map(\.targetWeightKg) == [20, 22.25])

        // A finished session whose workout and exercise were deleted stays readable.
        let orphan = try #require(try context.fetch(FetchDescriptor<Session>()).first { $0.startedAt == LegacyRecords.oldSessionStart })
        #expect(orphan.workout == nil)
        #expect(orphan.workoutNameSnapshot == "Treino Antigo")
        #expect(orphan.orderedExercises.map { $0.exercise == nil } == [true])
        #expect(orphan.orderedExercises.map(\.muscleGroupSnapshot) == [.back])
        #expect(orphan.orderedExercises[0].orderedSetLogs.map(\.reps) == [15])

        // The session in progress is still the one to continue; archived exercises stay archived.
        let active = try #require(try SessionService(context: context).activeSession())
        #expect(active.workout?.id == workout.id)
        #expect(active.orderedExercises[0].orderedSetLogs.map(\.isCompleted) == [false])
        let archived = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isArchived }))
        #expect(archived.map(\.name) == ["Remada Antiga"])
    }
}
