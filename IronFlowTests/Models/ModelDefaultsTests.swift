import Foundation
import SwiftData
import Testing
@testable import IronFlow

@MainActor
struct ModelDefaultsTests {
    @Test("New exercise has a unique id, equal timestamps and safe defaults")
    func exerciseDefaults() {
        let first = Exercise(name: "Supino Reto", muscleGroup: .chest, isCustom: false)
        let second = Exercise(name: "Supino Reto", muscleGroup: .chest, isCustom: false)

        #expect(first.id != second.id)
        #expect(first.createdAt == first.updatedAt)
        #expect(first.isArchived == false)
        #expect(first.libraryKey == nil)
        #expect(first.muscleGroup == .chest)
        #expect(first.muscleGroupRaw == "chest")
        #expect(first.workoutExercises.isEmpty)
        #expect(first.sessionExercises.isEmpty)
    }

    @Test("Muscle group is read and written through its storage key")
    func exerciseMuscleGroupStorage() {
        let exercise = Exercise(name: "Agachamento", muscleGroup: .quadriceps, isCustom: true)
        exercise.muscleGroup = .glutes
        #expect(exercise.muscleGroupRaw == "glutes")

        exercise.muscleGroupRaw = "unknown-future-group"
        #expect(exercise.muscleGroup == .other)
    }

    @Test("Every model gets its own id and equal creation and update timestamps")
    func idsAndTimestamps() {
        let models: [(id: UUID, createdAt: Date, updatedAt: Date)] = [
            { let m = Workout(name: "Push"); return (m.id, m.createdAt, m.updatedAt) }(),
            { let m = WorkoutExercise(sortIndex: 0); return (m.id, m.createdAt, m.updatedAt) }(),
            { let m = PlannedSet(sortIndex: 0, weightKg: nil, repsMin: 8, repsMax: 10); return (m.id, m.createdAt, m.updatedAt) }(),
            { let m = Session(startedAt: .now, workoutNameSnapshot: "Push"); return (m.id, m.createdAt, m.updatedAt) }(),
            { let m = SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Supino", muscleGroupSnapshot: .chest); return (m.id, m.createdAt, m.updatedAt) }(),
            { let m = SetLog(sortIndex: 0); return (m.id, m.createdAt, m.updatedAt) }(),
        ]

        #expect(Set(models.map(\.id)).count == models.count)
        for model in models {
            #expect(model.createdAt == model.updatedAt)
        }
    }

    @Test("A new set log is not completed and has no values")
    func setLogDefaults() {
        let log = SetLog(sortIndex: 0)

        #expect(log.isCompleted == false)
        #expect(log.completedAt == nil)
        #expect(log.weightKg == nil)
        #expect(log.reps == nil)
        #expect(log.targetWeightKg == nil)
        #expect(log.targetRepsMin == nil)
        #expect(log.targetRepsMax == nil)
    }

    @Test("Session is active until it has an end, then its duration is end minus start")
    func sessionActiveAndDuration() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let session = Session(startedAt: start, workoutNameSnapshot: "Push")

        #expect(session.isActive)
        #expect(session.duration == nil)

        session.endedAt = start.addingTimeInterval(2_745)
        #expect(session.isActive == false)
        #expect(session.duration == 2_745)
    }

    @Test("Planned set keeps an empty load empty and a decimal load exact")
    func plannedSetLoadIsPreserved() throws {
        var emptyID = UUID()
        var decimalID = UUID()

        try roundTripThroughDisk { context in
            let empty = PlannedSet(sortIndex: 0, weightKg: nil, repsMin: 8, repsMax: 10)
            let decimal = PlannedSet(sortIndex: 1, weightKg: 22.25, repsMin: 6, repsMax: 8)
            context.insert(empty)
            context.insert(decimal)
            emptyID = empty.id
            decimalID = decimal.id
        } read: { context in
            let sets = try context.fetch(FetchDescriptor<PlannedSet>())
            let empty = try #require(sets.first { $0.id == emptyID })
            let decimal = try #require(sets.first { $0.id == decimalID })
            #expect(empty.weightKg == nil)
            #expect(empty.repsMin == 8)
            #expect(empty.repsMax == 10)
            #expect(decimal.weightKg == 22.25)
            #expect(decimal.repsMin == 6)
            #expect(decimal.repsMax == 8)
        }
    }

    /// Documents SwiftData's behavior for the unique `id`: a second insert with the
    /// same id replaces the first instead of creating a duplicate.
    @Test("Two inserts with the same id store a single record")
    func uniqueIDDoesNotDuplicate() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let original = Exercise(name: "Supino Reto", muscleGroup: .chest, isCustom: false)
        let duplicate = Exercise(name: "Supino Inclinado", muscleGroup: .chest, isCustom: false)
        duplicate.id = original.id

        context.insert(original)
        try context.save()
        context.insert(duplicate)
        try context.save()

        #expect(try count(Exercise.self, in: context) == 1)
    }
}
