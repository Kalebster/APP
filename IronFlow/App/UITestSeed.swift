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
///   repetitions; no load for 12) and the third not done;
/// - `open-session:<workout>`: a session of the workout left open: started 3 hours ago, its first set
///   done 2 hours ago (10 repetitions) and not finished;
/// - `finished-today:<workout>`: one finished session of the workout that started today, 55 minutes
///   ago (or at midnight, when that is earlier), with its first set done, finished now.
@MainActor
enum UITestSeed {
    enum Item: Equatable {
        case workout(name: String, exercises: [String])
        case planToday(workout: String)
        case plan(workout: String, weekdays: [Int])
        case finishedSessions(workout: String, count: Int)
        case sessionDetail(workout: String)
        case openSession(workout: String)
        case finishedToday(workout: String)
    }

    enum SeedError: Error, CustomStringConvertible {
        case unknownItem(String)
        case workoutNotFound(String)
        case exerciseNotFound(String)

        var description: String {
            switch self {
            case .unknownItem(let item): "unknown item '\(item)'"
            case .workoutNotFound(let name): "no workout named '\(name)'"
            case .exerciseNotFound(let name): "no exercise named '\(name)' in the library"
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
                try finishSession(of: workout, startedAt: Date.now.addingTimeInterval(-7_200), in: context) { logs, service in
                    try service.completeSet(logs[0], weightKg: 20, reps: 10)
                    try service.completeSet(logs[1], weightKg: nil, reps: 12)
                }
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
    private static func finishSession(
        of workout: Workout,
        startedAt start: Date,
        in context: ModelContext,
        complete: ([SetLog], SessionService) throws -> Void
    ) throws {
        let clock = SeedClock(start)
        let service = SessionService(context: context, now: { clock.current })
        let session = try service.startSession(from: workout)
        let logs = session.orderedExercises.first?.orderedSetLogs ?? []
        try complete(logs, service)
        clock.current = start.addingTimeInterval(2_400)
        try service.finishSession(session)
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
