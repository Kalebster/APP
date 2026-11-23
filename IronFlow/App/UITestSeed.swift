#if DEBUG
import Foundation
import SwiftData

/// Ready-made data for the interface tests, so a test that only needs the data to exist does not spend
/// its time creating it through the screens. A test hook: it exists in Debug builds only and acts only
/// when the app was launched with `-ui-testing` (an in-memory store) and `-ui-seed <items>`.
///
/// The data is created with the app's own services, the same code a person's taps reach. `<items>` is a
/// comma-separated list, percent-encoded by the tests so accented names ("Tríceps") arrive as written;
/// each item is:
/// - `workout:<name>` or `workout:<name>:<exercise>|<exercise>`: a workout with those exercises of the
///   built-in library, with the default planned sets;
/// - `plan-today:<workout>`: that workout planned for today's weekday;
/// - `plan:<workout>:<weekday>|<weekday>`: that workout planned for those weekdays, 1 = Monday to
///   7 = Sunday;
/// - `finished:<workout>:<count>`: that many finished sessions of the workout, each with its first set
///   done, started 2 hours apart (the latest 2 hours ago) and lasting 40 minutes;
/// - `session-detail:<workout>`: one finished session of the workout with two sets done (20 kg for 10
///   repetitions; no load for 12) and the third not done, as sessions finished before sets not done
///   stopped being saved;
/// - `open-session:<workout>`: a session of the workout left open: started 3 hours ago, its first set
///   done 2 hours ago (10 repetitions) and not finished;
/// - `finished-today:<workout>`: one finished session of the workout that started today, 55 minutes
///   ago (or at midnight, when that is earlier), with its first set done, finished now;
/// - `last-time:<workout>`: one finished session of the workout that started yesterday at this time,
///   with every set done: exercise 1 with 60 kg, 2 with 22, 3 with 18, 4 with 25 (and so on again),
///   10, 10, 9 and 8 repetitions for sets 1 to 4 (8 after that); it lasted 45 minutes;
/// - `custom-exercise:<name>:<group>`: an exercise of the user's own, in the muscle group with that
///   storage key ("chest", "back"...);
/// - `set-types:<workout>`: the planned sets of the workout's first exercise become those of the workout
///   editor's model: a warm-up of 40 kg for 12–15, a feeder of 50 kg for 5–6, two working sets of 60 kg
///   for 8–10 and a failure set of 55 kg for 8–12;
/// - `rest:<workout>:<seconds>`: every exercise of the workout rests that many seconds (0 is "Sem timer");
/// - `weights:<kg>@<days ago>|<kg>@<days ago>`: body weights measured that many days ago, at this time
///   of day ("81.2@14|80.6@7"), with a decimal point;
/// - `profile:<height cm>:<calorie goal kcal>`: the height and the daily calorie goal;
/// - `bmr:<sex>:<age>:<goal>`: the calculator's choices: the sex and goal by storage key ("male",
///   "lose"), and a date of birth on 1 January that gives that age in full years today;
/// - `prototype-history`: the finished sessions of the approved prototype's history ("Push", "Pull" and
///   "Pernas", 24 April to 15 October 2026, at 18:00), with the sets of its 15 exercises
///   (`UITestPrototypeHistory`), for the exercise screen with `-ui-today 2026-10-16`;
/// - `exercise-years:<exercise>:<years>`: that many years of finished sessions of one exercise, two a week
///   up to yesterday, each with a warm-up, three working sets and a failure set, the load growing slowly.
///
/// The two histories are written straight into the store, in one save, rather than through the session
/// service: the service saves at every set, and hundreds of sessions would take most of a test's time.
@MainActor
enum UITestSeed {
    /// A body weight of `weights`.
    struct WeightRecord: Equatable {
        let weightKg: Double
        let daysAgo: Int
    }

    enum Item: Equatable {
        case workout(name: String, exercises: [String])
        case planToday(workout: String)
        case plan(workout: String, weekdays: [Int])
        case finishedSessions(workout: String, count: Int)
        case sessionDetail(workout: String)
        case openSession(workout: String)
        case finishedToday(workout: String)
        case lastTime(workout: String)
        case customExercise(name: String, group: MuscleGroup)
        case setTypes(workout: String)
        case rest(workout: String, seconds: Int)
        case weights([WeightRecord])
        case profile(heightCm: Int, goalKcal: Int)
        case bmr(sex: BiologicalSex, age: Int, goal: WeightGoal)
        case prototypeHistory
        case exerciseYears(exercise: String, years: Int)
    }

    /// The planned sets of `set-types`, in order.
    static let setTypesSets: [(type: SetType, values: PlannedSetValues)] = [
        (.warmup, PlannedSetValues(weightKg: 40, repsMin: 12, repsMax: 15)),
        (.feeder, PlannedSetValues(weightKg: 50, repsMin: 5, repsMax: 6)),
        (.working, PlannedSetValues(weightKg: 60, repsMin: 8, repsMax: 10)),
        (.working, PlannedSetValues(weightKg: 60, repsMin: 8, repsMax: 10)),
        (.failure, PlannedSetValues(weightKg: 55, repsMin: 8, repsMax: 12)),
    ]

    /// The loads of `last-time`, by exercise, and its repetitions, by set.
    static let lastTimeLoads: [Double] = [60, 22, 18, 25]
    static let lastTimeReps = [10, 10, 9, 8]

    enum SeedError: Error, CustomStringConvertible {
        case unknownItem(String)
        case workoutNotFound(String)
        case exerciseNotFound(String)
        case workoutHasNoExercises(String)

        var description: String {
            switch self {
            case .unknownItem(let item): "unknown item '\(item)'"
            case .workoutNotFound(let name): "no workout named '\(name)'"
            case .exerciseNotFound(let name): "no exercise named '\(name)' in the library"
            case .workoutHasNoExercises(let name): "the workout '\(name)' has no exercises"
            }
        }
    }

    /// Creates what `-ui-seed` asks for, if the app was launched for interface tests. A failure stops the
    /// app with its reason, so a wrong item shows up at once and not as a confusing test failure.
    static func applyIfRequested(in container: ModelContainer, arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains("-ui-testing"),
              let flag = arguments.firstIndex(of: "-ui-seed"),
              arguments.indices.contains(flag + 1) else { return }
        let argument = arguments[flag + 1]
        guard let list = argument.removingPercentEncoding else {
            fatalError("UI test seed failed (-ui-seed \(argument)): invalid percent-encoding")
        }
        do {
            try apply(parse(list), in: container.mainContext)
        } catch {
            fatalError("UI test seed failed (-ui-seed \(list)): \(error)")
        }
    }

    static func parse(_ list: String) throws -> [Item] {
        try list.split(separator: ",").map { token -> Item in
            let parts = token.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            switch (parts[0], parts.count) {
            case ("workout", 2):
                return .workout(name: parts[1], exercises: [])
            case ("workout", 3):
                return .workout(name: parts[1], exercises: parts[2].split(separator: "|").map(String.init))
            case ("plan-today", 2):
                return .planToday(workout: parts[1])
            case ("plan", 3):
                let weekdays = parts[2].split(separator: "|").compactMap { Int($0) }
                guard !weekdays.isEmpty, weekdays.allSatisfy(TrainingDay.planWeekdays.contains) else {
                    throw SeedError.unknownItem(String(token))
                }
                return .plan(workout: parts[1], weekdays: weekdays)
            case ("finished", 3):
                guard let count = Int(parts[2]), count > 0 else { throw SeedError.unknownItem(String(token)) }
                return .finishedSessions(workout: parts[1], count: count)
            case ("session-detail", 2):
                return .sessionDetail(workout: parts[1])
            case ("open-session", 2):
                return .openSession(workout: parts[1])
            case ("finished-today", 2):
                return .finishedToday(workout: parts[1])
            case ("last-time", 2):
                return .lastTime(workout: parts[1])
            case ("custom-exercise", 3):
                guard let group = MuscleGroup(rawValue: parts[2]) else { throw SeedError.unknownItem(String(token)) }
                return .customExercise(name: parts[1], group: group)
            case ("set-types", 2):
                return .setTypes(workout: parts[1])
            case ("rest", 3):
                guard let seconds = Int(parts[2]), RestDuration.isValid(seconds) else { throw SeedError.unknownItem(String(token)) }
                return .rest(workout: parts[1], seconds: seconds)
            case ("weights", 2):
                let records = try parts[1].split(separator: "|").map { record -> WeightRecord in
                    let pair = record.split(separator: "@")
                    guard pair.count == 2, let weightKg = Double(pair[0]), let daysAgo = Int(pair[1]), daysAgo >= 0 else {
                        throw SeedError.unknownItem(String(token))
                    }
                    return WeightRecord(weightKg: weightKg, daysAgo: daysAgo)
                }
                guard !records.isEmpty else { throw SeedError.unknownItem(String(token)) }
                return .weights(records)
            case ("profile", 3):
                guard let heightCm = Int(parts[1]), let goalKcal = Int(parts[2]) else { throw SeedError.unknownItem(String(token)) }
                return .profile(heightCm: heightCm, goalKcal: goalKcal)
            case ("bmr", 4):
                guard let sex = BiologicalSex(rawValue: String(parts[1])),
                      let age = Int(parts[2]), age >= 0,
                      let goal = WeightGoal(rawValue: String(parts[3])) else { throw SeedError.unknownItem(String(token)) }
                return .bmr(sex: sex, age: age, goal: goal)
            case ("prototype-history", 1):
                return .prototypeHistory
            case ("exercise-years", 3):
                guard let years = Int(parts[2]), (1...5).contains(years) else { throw SeedError.unknownItem(String(token)) }
                return .exerciseYears(exercise: parts[1], years: years)
            default:
                throw SeedError.unknownItem(String(token))
            }
        }
    }

    static func apply(_ items: [Item], in context: ModelContext) throws {
        for item in items {
            switch item {
            case .workout(let name, let exercises):
                let service = WorkoutService(context: context)
                let workout = try service.createWorkout(name: name)
                if !exercises.isEmpty {
                    try service.addExercises(exercises.map { try findExercise(named: $0, in: context) }, to: workout)
                }
            case .planToday(let name):
                let workout = try findWorkout(named: name, in: context)
                let weekday = TrainingDay.planWeekday(of: .now, calendar: TrainingDay.calendar)
                try WeeklyPlanService(context: context).setWorkout(workout, for: weekday)
            case .plan(let name, let weekdays):
                let workout = try findWorkout(named: name, in: context)
                for weekday in weekdays {
                    try WeeklyPlanService(context: context).setWorkout(workout, for: weekday)
                }
            case .finishedSessions(let name, let count):
                let workout = try findWorkout(named: name, in: context)
                let now = Date.now
                for index in 0..<count {
                    let start = now.addingTimeInterval(-7_200 * Double(count - index))
                    try finishSession(of: workout, startedAt: start, in: context) { logs, service in
                        try service.completeSet(logs[0], weightKg: nil, reps: 10)
                    }
                }
            case .sessionDetail(let name):
                let workout = try findWorkout(named: name, in: context)
                let session = try finishSession(of: workout, startedAt: Date.now.addingTimeInterval(-7_200), in: context) { logs, service in
                    try service.completeSet(logs[0], weightKg: 20, reps: 10)
                    try service.completeSet(logs[1], weightKg: nil, reps: 12)
                }
                // Finishing no longer saves a set not done; sessions recorded before kept them, and the
                // history still shows them. The third set is that record, written as it was then.
                guard let performed = session.orderedExercises.first, let last = performed.orderedSetLogs.last else {
                    throw SeedError.workoutHasNoExercises(name)
                }
                let notDone = SetLog(
                    sortIndex: performed.setLogs.count,
                    targetWeightKg: last.targetWeightKg,
                    targetRepsMin: last.targetRepsMin,
                    targetRepsMax: last.targetRepsMax
                )
                context.insert(notDone)
                notDone.sessionExercise = performed
                try context.save()
            case .openSession(let name):
                let workout = try findWorkout(named: name, in: context)
                let start = Date.now.addingTimeInterval(-10_800)
                let clock = SeedClock(start)
                let service = SessionService(context: context, now: { clock.current })
                let session = try service.startSession(from: workout)
                clock.current = start.addingTimeInterval(3_600)
                // Starting needs exercises with planned sets, so the first set exists.
                try service.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: nil, reps: 10)
            case .finishedToday(let name):
                let workout = try findWorkout(named: name, in: context)
                let now = Date.now
                let start = max(TrainingDay.calendar.startOfDay(for: now), now.addingTimeInterval(-3_300))
                let clock = SeedClock(start)
                let service = SessionService(context: context, now: { clock.current })
                let session = try service.startSession(from: workout)
                try service.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: nil, reps: 10)
                clock.current = now
                try service.finishSession(session)
            case .lastTime(let name):
                let workout = try findWorkout(named: name, in: context)
                let start = Date.now.addingTimeInterval(-86_400)
                let clock = SeedClock(start)
                let service = SessionService(context: context, now: { clock.current })
                let session = try service.startSession(from: workout)
                for (exerciseIndex, performed) in session.orderedExercises.enumerated() {
                    let load = lastTimeLoads[exerciseIndex % lastTimeLoads.count]
                    for (setIndex, log) in performed.orderedSetLogs.enumerated() {
                        clock.current = clock.current.addingTimeInterval(120)
                        let reps = lastTimeReps[min(setIndex, lastTimeReps.count - 1)]
                        try service.completeSet(log, weightKg: load, reps: reps)
                    }
                }
                clock.current = start.addingTimeInterval(2_700)
                try service.finishSession(session)
            case .customExercise(let name, let group):
                try ExerciseService(context: context).createCustomExercise(name: name, muscleGroup: group)
            case .setTypes(let name):
                let workout = try findWorkout(named: name, in: context)
                guard let item = workout.orderedExercises.first else { throw SeedError.workoutHasNoExercises(name) }
                let service = WorkoutService(context: context)
                let existing = item.orderedPlannedSets
                for (index, planned) in setTypesSets.enumerated() {
                    let plannedSet = try index < existing.count
                        ? existing[index]
                        : service.addPlannedSet(to: item, values: planned.values)
                    try service.updatePlannedSet(plannedSet, values: planned.values)
                    try service.setType(planned.type, of: plannedSet)
                }
                for extra in existing.dropFirst(setTypesSets.count) {
                    try service.removePlannedSet(extra)
                }
            case .rest(let name, let seconds):
                let workout = try findWorkout(named: name, in: context)
                let service = WorkoutService(context: context)
                for item in workout.orderedExercises {
                    try service.setRestSeconds(seconds, of: item)
                }
            case .weights(let records):
                for record in records {
                    let measuredAt = TrainingDay.calendar.date(byAdding: .day, value: -record.daysAgo, to: .now) ?? .now
                    try ProfileService(context: context, now: { measuredAt }).recordWeight(record.weightKg)
                }
            case .profile(let heightCm, let goalKcal):
                let service = ProfileService(context: context)
                try service.setHeight(heightCm)
                try service.setDailyCalorieGoal(goalKcal)
            case .bmr(let sex, let age, let goal):
                let service = ProfileService(context: context)
                let year = TrainingDay.calendar.component(.year, from: .now) - age
                try service.setSex(sex)
                try service.setBirthDate(BirthDate(day: 1, month: 1, year: year))
                try service.setWeightGoal(goal)
            case .prototypeHistory:
                try insertPrototypeHistory(in: context)
            case .exerciseYears(let name, let years):
                try insertYears(years, of: name, in: context)
            }
        }
    }

    /// The prototype's sessions, at 18:00 of their days, finished after their duration.
    private static func insertPrototypeHistory(in context: ModelContext) throws {
        let calendar = TrainingDay.calendar
        var exercises: [String: Exercise] = [:]
        for session in UITestPrototypeHistory.sessions().reversed() {
            var components = session.day
            components.hour = 18
            guard let start = calendar.date(from: components) else { continue }
            var performed: [(Exercise, [(SetType, Double?, Int)])] = []
            for item in session.exercises {
                let exercise = try exercises[item.name] ?? findExercise(named: item.name, in: context)
                exercises[item.name] = exercise
                performed.append((exercise, item.sets.map { ($0.type, $0.weightKg > 0 ? $0.weightKg : nil, $0.reps) }))
            }
            insertFinishedSession(name: session.name, start: start, minutes: session.durationMinutes, performed: performed, in: context)
        }
        try context.save()
    }

    /// Two sessions a week of one exercise for `years` years, up to yesterday.
    private static func insertYears(_ years: Int, of name: String, in context: ModelContext) throws {
        let exercise = try findExercise(named: name, in: context)
        let calendar = TrainingDay.calendar
        let today = calendar.startOfDay(for: .now)
        let count = years * 52 * 2
        for index in 0..<count {
            // Every 3 or 4 days, the oldest first, at 18:00.
            let daysAgo = (count - index) * 7 / 2
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) else { continue }
            let load = 40 + Double(index / 8) * 2.5
            let sets: [(SetType, Double?, Int)] = [
                (.warmup, load / 2, 12), (.working, load, 10), (.working, load, 9), (.working, load, 8), (.failure, load - 5, 12),
            ]
            insertFinishedSession(name: "Push", start: start, minutes: 50, performed: [(exercise, sets)], in: context)
        }
        try context.save()
    }

    /// A finished session with its exercises and their sets, all done.
    private static func insertFinishedSession(
        name: String,
        start: Date,
        minutes: Int,
        performed: [(Exercise, [(SetType, Double?, Int)])],
        in context: ModelContext
    ) {
        let session = Session(startedAt: start, workoutNameSnapshot: name)
        context.insert(session)
        session.endedAt = start.addingTimeInterval(Double(minutes) * 60)
        for (position, item) in performed.enumerated() {
            let (exercise, sets) = item
            let row = SessionExercise(sortIndex: position, exerciseNameSnapshot: exercise.name, muscleGroupSnapshot: exercise.muscleGroup)
            context.insert(row)
            row.session = session
            row.exercise = exercise
            for (index, values) in sets.enumerated() {
                let log = SetLog(sortIndex: index, weightKg: values.1, reps: values.2, setType: values.0)
                context.insert(log)
                log.sessionExercise = row
                log.isCompleted = true
                log.completedAt = start.addingTimeInterval(Double(position * 600 + index * 120))
            }
        }
    }

    // MARK: - Private

    /// A time the session service reads, moved by hand so a session can be dated in the past.
    private final class SeedClock {
        var current: Date

        init(_ start: Date) {
            current = start
        }
    }

    /// Starts a session of `workout` at `start`, lets `complete` do the sets of its first exercise, and
    /// finishes it 40 minutes later.
    @discardableResult
    private static func finishSession(
        of workout: Workout,
        startedAt start: Date,
        in context: ModelContext,
        complete: ([SetLog], SessionService) throws -> Void
    ) throws -> Session {
        let clock = SeedClock(start)
        let service = SessionService(context: context, now: { clock.current })
        let session = try service.startSession(from: workout)
        let logs = session.orderedExercises.first?.orderedSetLogs ?? []
        try complete(logs, service)
        clock.current = start.addingTimeInterval(2_400)
        try service.finishSession(session)
        return session
    }

    private static func findWorkout(named name: String, in context: ModelContext) throws -> Workout {
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.name == name })
        guard let workout = try context.fetch(descriptor).first else { throw SeedError.workoutNotFound(name) }
        return workout
    }

    private static func findExercise(named name: String, in context: ModelContext) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        guard let exercise = try context.fetch(descriptor).first else { throw SeedError.exerciseNotFound(name) }
        return exercise
    }
}
#endif
