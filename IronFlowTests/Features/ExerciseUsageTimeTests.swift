import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// What the Exercícios tab reads each time it appears (`ExerciseLastDone.read` and
/// `LibraryRecords.hiddenKeys`), with a long history on disk: 3 years of 4 workouts a week. Not a limit, a
/// measure (achado 6 do /code-review da lista base): printed for the report.
@MainActor
struct ExerciseUsageTimeTests {
    /// 3 years of 4 finished sessions a week, each with 6 exercises of 4 sets, of 3 workouts in turn.
    private static func makeHistory(at url: URL) throws {
        let container = try ModelContainerFactory.makePersistent(at: url)
        let context = container.mainContext
        try ExerciseLibrarySeeder(context: context).seed()
        let exercises = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom }))
            .sorted { $0.name < $1.name }
        let workouts = (0..<3).map { workout in (0..<6).map { exercises[workout * 97 + $0 * 13] } }
        let calendar = TrainingDay.calendar
        let today = calendar.startOfDay(for: .now)
        let count = 3 * 52 * 4
        for index in 0..<count {
            let daysAgo = (count - index) * 7 / 4
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) else { continue }
            let session = Session(startedAt: start, workoutNameSnapshot: "Treino \(index % 3)")
            context.insert(session)
            session.endedAt = start.addingTimeInterval(3_600)
            for (position, exercise) in workouts[index % 3].enumerated() {
                let row = SessionExercise(sortIndex: position, exerciseNameSnapshot: exercise.name, muscleGroupSnapshot: exercise.muscleGroup)
                context.insert(row)
                row.session = session
                row.exercise = exercise
                for set in 0..<4 {
                    let log = SetLog(sortIndex: set, weightKg: 40, reps: 10, setType: .working)
                    context.insert(log)
                    log.sessionExercise = row
                    log.isCompleted = true
                    log.completedAt = start.addingTimeInterval(Double(position * 600 + set * 120))
                }
            }
        }
        try context.save()
    }

    @Test("The time the Exercícios tab takes to read when each exercise was last done and the hidden ones, with 3 years of 4 workouts a week, is printed")
    func tabReadTime() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let url = directory.appending(path: "IronFlow.store")
        try Self.makeHistory(at: url)

        let clock = ContinuousClock()
        var first: [Duration] = []
        var again: [Duration] = []
        for _ in 0..<5 {
            // The first time after the app opens: nothing of the history in memory yet.
            let container = try ModelContainerFactory.makePersistent(at: url)
            let context = container.mainContext
            let start = clock.now
            let lastDone = try ExerciseLastDone.read(in: context)
            _ = try LibraryRecords.hiddenKeys(in: context)
            first.append(start.duration(to: clock.now))
            #expect(lastDone.byKey.count == 18)

            // Coming back to the tab, with the same context.
            let next = clock.now
            _ = try ExerciseLastDone.read(in: context)
            _ = try LibraryRecords.hiddenKeys(in: context)
            again.append(next.duration(to: clock.now))
        }
        // The same as reading every finished session whole.
        let container = try ModelContainerFactory.makePersistent(at: url)
        let read = try ExerciseLastDone.read(in: container.mainContext)
        let sessions = try container.mainContext.fetch(SessionService.finishedSessionsDescriptor)
        #expect(read == ExerciseLastDone(sessions: sessions))

        let f = first.sorted()
        let a = again.sorted()
        print("MEDIÇÃO aba Exercícios, leitura do histórico (3 anos, 4 treinos por semana: 624 treinos, 3.744 exercícios feitos), 5 vezes: primeira vez mediana \(f[2]), mínimo \(f[0]), máximo \(f[4]); ao voltar à aba mediana \(a[2]), mínimo \(a[0]), máximo \(a[4])")
    }
}
