import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// Reading the history of one exercise from the store.
@MainActor
struct ExerciseHistoryLoaderTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    private func exercise(_ name: String, key: String?, group: MuscleGroup = .chest) -> Exercise {
        let exercise = Exercise(name: name, muscleGroup: group, isCustom: key == nil, libraryKey: key)
        context.insert(exercise)
        return exercise
    }

    /// A session with the given exercises and their sets (load, repetitions, type, done), finished unless
    /// `finished` is false.
    @discardableResult
    private func session(
        _ name: String,
        at start: Date,
        finished: Bool = true,
        _ performed: [(Exercise, [(Double?, Int?, SetType, Bool)])]
    ) -> Session {
        let session = Session(startedAt: start, workoutNameSnapshot: name)
        context.insert(session)
        if finished {
            session.endedAt = start.addingTimeInterval(3_600)
        }
        for (index, item) in performed.enumerated() {
            let (exercise, sets) = item
            let row = SessionExercise(sortIndex: index, exerciseNameSnapshot: exercise.name, muscleGroupSnapshot: exercise.muscleGroup)
            context.insert(row)
            row.session = session
            row.exercise = exercise
            for (position, values) in sets.enumerated() {
                let log = SetLog(sortIndex: position, weightKg: values.0, reps: values.1, setType: values.2)
                context.insert(log)
                log.sessionExercise = row
                log.isCompleted = values.3
            }
        }
        return session
    }

    @Test("Only the finished sessions with the exercise, with its sets done numbered in order; the session in progress never counts")
    func readsOnlyTheExercise() throws {
        let bench = exercise("Supino Reto (Barra)", key: "bench-press-barbell")
        let curl = exercise("Rosca Direta (Barra)", key: "barbell-curl", group: .biceps)
        let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let first = session("Push", at: base, [
            (bench, [(40, 15, .warmup, true), (60, 10, .working, true), (62, nil, .working, false)]),
            (curl, [(30, 10, .working, true)]),
        ])
        let second = session("", at: base.addingTimeInterval(86_400 * 3), [(bench, [(62, 8, .failure, true)])])
        session("Push", at: base.addingTimeInterval(86_400 * 5), finished: false, [(bench, [(70, 5, .working, true)])])
        // Only warm-ups of the exercise: left out (approved rule).
        session("Push", at: base.addingTimeInterval(86_400 * 6), [(bench, [(40, 15, .warmup, true)])])
        try context.save()

        let history = try ExerciseHistoryLoader(context: context).history(of: bench)
        #expect(history.entries.map(\.id) == [first.id, second.id])
        #expect(history.entries[0].workoutName == "Push")
        #expect(history.entries[1].workoutName == "Treino livre")
        #expect(history.entries[0].sets.map(\.number) == [1, 2])
        #expect(history.entries[0].sets.map(\.type) == [.warmup, .working])
        #expect(history.entries[0].sets.map(\.weightKg) == [40, 60])
        #expect(history.kind == .load)

        let curlHistory = try ExerciseHistoryLoader(context: context).history(of: curl)
        #expect(curlHistory.entries.map(\.id) == [first.id])
        #expect(try ExerciseHistoryLoader(context: context).session(id: second.id)?.id == second.id)
    }

    @Test("A Graviton exercise is read as assisted; an exercise never done has no history")
    func assistedAndNeverDone() throws {
        let assisted = exercise("Barra Fixa (Graviton)", key: "assisted-pull-up", group: .back)
        let never = exercise("Cadeira Flexora (Máquina)", key: "seated-leg-curl", group: .hamstrings)
        session("Pull", at: .now.addingTimeInterval(-86_400), [(assisted, [(25, 8, .working, true)])])
        try context.save()
        #expect(try ExerciseHistoryLoader(context: context).history(of: assisted).kind == .assisted)
        #expect(try ExerciseHistoryLoader(context: context).history(of: never).isEmpty)
    }

    @Test("An exercise of the user's own on a Graviton is read as assisted: less kg is the best set")
    func customGraviton() throws {
        let custom = exercise("Minha Barra Graviton", key: nil, group: .back)
        custom.equipment = .machine
        custom.machineType = .graviton
        session("Pull", at: .now.addingTimeInterval(-2 * 86_400), [(custom, [(30, 8, .working, true)])])
        session("Pull", at: .now.addingTimeInterval(-86_400), [(custom, [(20, 8, .working, true)])])
        try context.save()
        let history = try ExerciseHistoryLoader(context: context).history(of: custom)
        #expect(history.kind == .assisted)
        #expect(history.bestSet?.set.weightKg == 20)

        custom.machineType = .lever
        #expect(try ExerciseHistoryLoader(context: context).history(of: custom).kind == .load)
    }

    @Test("Three years of one exercise, two sessions a week, are read and charted quickly")
    func threeYears() throws {
        let bench = exercise("Supino Reto (Barra)", key: "bench-press-barbell")
        let other = exercise("Rosca Direta (Barra)", key: "barbell-curl", group: .biceps)
        let now = Date.now
        let sessions = 3 * 52 * 2
        for index in 0..<sessions {
            let start = now.addingTimeInterval(-Double(sessions - index) * 3.5 * 86_400)
            let load = 40 + Double(index / 10)
            session("Push", at: start, [
                (bench, [(load - 20, 12, .warmup, true), (load, 10, .working, true), (load, 9, .working, true), (load - 5, 12, .failure, true)]),
                (other, [(20, 10, .working, true)]),
            ])
        }
        try context.save()

        let clock = ContinuousClock()
        var history: ExerciseHistory?
        let reading = try clock.measure {
            history = try ExerciseHistoryLoader(context: context).history(of: bench)
        }
        let loaded = try #require(history)
        #expect(loaded.entries.count == sessions)
        var charts: [ExerciseChart] = []
        let charting = clock.measure {
            for period in ExercisePeriod.allCases {
                for metric in loaded.metrics {
                    charts.append(loaded.chart(metric: metric, period: period, today: now, calendar: TrainingDay.calendar))
                }
            }
        }
        #expect(charts.last?.points.count == sessions)
        // Generous limits for a slow CI machine; the times are in the test's log.
        print("Exercise history, 3 years (\(sessions) sessions): read in \(reading), 6 charts in \(charting)")
        #expect(reading < .seconds(2), "Reading took \(reading)")
        #expect(charting < .milliseconds(500), "Charting took \(charting)")
    }
}
