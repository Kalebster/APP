import Foundation
import SwiftData
import Testing
@testable import IronFlow

@MainActor
struct SessionServiceTests {
    let harness: ServiceTestHarness
    let bench: Exercise
    let curl: Exercise
    let workout: Workout

    init() throws {
        harness = try ServiceTestHarness()
        bench = try harness.insertSystemExercise(name: "Supino Reto", muscleGroup: .chest, libraryKey: "bench-press")
        curl = try harness.exercises.createCustomExercise(name: "Rosca Direta", muscleGroup: .biceps)
        workout = try harness.makeWorkout(name: "Push", items: [
            (bench, [.reps(8, 10, kg: 20), .reps(6, 8, kg: 22.25)]),
            (curl, [.reps(10, 12)]),
        ])
        harness.clock.advance(by: 60)
    }

    private func firstLog(of session: Session) -> SetLog {
        session.orderedExercises[0].orderedSetLogs[0]
    }

    // MARK: - Start

    @Test("No session is active at first")
    func noActiveSession() throws {
        #expect(try harness.sessions.activeSession() == nil)
    }

    @Test("Starting creates the session with start time, workout name and link")
    func startCreatesSession() throws {
        let session = try harness.sessions.startSession(from: workout)

        #expect(session.startedAt == harness.clock.current)
        #expect(session.createdAt == harness.clock.current)
        #expect(session.endedAt == nil)
        #expect(session.isActive)
        #expect(session.workoutNameSnapshot == "Push")
        #expect(session.workout?.id == workout.id)
        #expect(try harness.sessions.activeSession()?.id == session.id)
    }

    @Test("Starting copies exercise names and muscle groups in plan order")
    func startCopiesExercises() throws {
        let session = try harness.sessions.startSession(from: workout)

        let performed = session.orderedExercises
        #expect(performed.map(\.sortIndex) == [0, 1])
        #expect(performed.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
        #expect(performed.map(\.muscleGroupSnapshot) == [.chest, .biceps])
        #expect(performed.map { $0.exercise?.id } == [bench.id, curl.id])
    }

    @Test("Starting copies targets in order and leaves the load and reps empty: the planned load is a target, offered as a suggestion")
    func startCopiesTargets() throws {
        let session = try harness.sessions.startSession(from: workout)

        let benchLogs = session.orderedExercises[0].orderedSetLogs
        #expect(benchLogs.map(\.sortIndex) == [0, 1])
        #expect(benchLogs.map(\.targetWeightKg) == [20, 22.25])
        #expect(benchLogs.map(\.targetRepsMin) == [8, 6])
        #expect(benchLogs.map(\.targetRepsMax) == [10, 8])
        #expect(benchLogs.map(\.weightKg) == [nil, nil])

        let allLogs = session.orderedExercises.flatMap(\.orderedSetLogs)
        #expect(allLogs.count == 3)
        #expect(allLogs.allSatisfy { $0.weightKg == nil && $0.reps == nil && !$0.isCompleted && $0.completedAt == nil })
    }

    @Test("An archived exercise in the workout is included in the session")
    func startIncludesArchivedExercise() throws {
        try harness.exercises.archive(curl)

        let session = try harness.sessions.startSession(from: workout)
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
    }

    @Test("Later changes to the workout and exercises do not change the session")
    func sessionIsIndependentFromPlan() throws {
        let session = try harness.sessions.startSession(from: workout)

        try harness.workouts.rename(workout, to: "Push B")
        try harness.workouts.updatePlannedSet(workout.orderedExercises[0].orderedPlannedSets[0], values: .reps(3, 5, kg: 50))
        try harness.exercises.updateCustomExercise(curl, name: "Rosca Martelo", muscleGroup: .forearms)
        try harness.workouts.removeExercise(workout.orderedExercises[1])
        try harness.workouts.delete(workout)

        #expect(session.workoutNameSnapshot == "Push")
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
        #expect(session.orderedExercises.map(\.muscleGroupSnapshot) == [.chest, .biceps])
        let firstTarget = firstLog(of: session)
        #expect(firstTarget.targetWeightKg == 20)
        #expect(firstTarget.targetRepsMin == 8)
        #expect(firstTarget.targetRepsMax == 10)
        #expect(try count(SetLog.self, in: harness.context) == 3)
    }

    @Test("Only one session can be active")
    func singleActiveSession() throws {
        try harness.sessions.startSession(from: workout)
        let before = try storeCounts(in: harness.context)

        #expect(throws: SessionError.activeSessionExists) { try harness.sessions.startSession(from: workout) }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)
    }

    @Test("A workout without exercises cannot be started")
    func startEmptyWorkout() throws {
        let empty = try harness.workouts.createWorkout(name: "Vazio")

        #expect(throws: WorkoutError.workoutHasNoExercises) { try harness.sessions.startSession(from: empty) }
        #expect(try count(Session.self, in: harness.context) == 0)
    }

    @Test("A workout item without exercise or planned sets cannot be started")
    func startInconsistentWorkout() throws {
        // Such items cannot be produced through the services; they are built directly.
        let broken = try harness.workouts.createWorkout(name: "Inconsistente")
        let orphan = WorkoutExercise(sortIndex: 0)
        harness.context.insert(orphan)
        orphan.workout = broken
        let planned = PlannedSet(sortIndex: 0, weightKg: nil, repsMin: 8, repsMax: 10)
        harness.context.insert(planned)
        planned.workoutExercise = orphan
        try harness.context.save()

        #expect(throws: WorkoutError.exerciseMissing) { try harness.sessions.startSession(from: broken) }

        orphan.exercise = bench
        harness.context.delete(planned)
        try harness.context.save()
        #expect(throws: WorkoutError.plannedSetsMissing) { try harness.sessions.startSession(from: broken) }
        #expect(try count(Session.self, in: harness.context) == 0)
    }

    @Test("Two active sessions in the store are reported, not hidden")
    func multipleActiveSessionsReported() throws {
        for name in ["A", "B"] {
            harness.context.insert(Session(startedAt: .now, workoutNameSnapshot: name))
        }
        try harness.context.save()

        #expect(throws: SessionError.multipleActiveSessions) { try harness.sessions.activeSession() }
    }

    @Test("The active session is found again after the store is closed and reopened")
    func activeSessionSurvivesReopening() throws {
        var sessionID = UUID()

        try roundTripThroughDisk { context in
            let services = ServiceTestHarness(container: context.container)
            let exercise = try services.exercises.createCustomExercise(name: "Supino", muscleGroup: .chest)
            let workout = try services.makeWorkout(name: "Push", items: [(exercise, [.reps(8, 10), .reps(8, 10)])])
            let session = try services.sessions.startSession(from: workout)
            try services.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: 30, reps: 9)
            sessionID = session.id
        } read: { context in
            let active = try #require(try SessionService(context: context).activeSession())
            #expect(active.id == sessionID)
            let logs = active.orderedExercises[0].orderedSetLogs
            #expect(logs.map(\.isCompleted) == [true, false])
            #expect(logs[0].reps == 9)
            #expect(logs[0].weightKg == 30)
        }
    }

    // MARK: - Sets

    @Test("Completing a set records the values and the completion time")
    func completeSet() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)
        harness.clock.advance(by: 90)

        try harness.sessions.completeSet(log, weightKg: 22.5, reps: 9)

        #expect(log.isCompleted)
        #expect(log.completedAt == harness.clock.current)
        #expect(log.weightKg == 22.5)
        #expect(log.reps == 9)
        #expect(log.updatedAt == harness.clock.current)
        #expect(session.updatedAt == harness.clock.current)
    }

    @Test("Completing without valid repetitions fails and leaves the set unchanged")
    func completeSetRequiresReps() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)

        #expect(throws: SessionError.repsRequired) { try harness.sessions.completeSet(log, weightKg: 20, reps: nil) }
        #expect(throws: ValidationError.invalidReps) { try harness.sessions.completeSet(log, weightKg: 20, reps: 0) }
        #expect(throws: ValidationError.negativeWeight) { try harness.sessions.completeSet(log, weightKg: -5, reps: 8) }
        #expect(log.isCompleted == false)
        #expect(log.completedAt == nil)
        #expect(log.reps == nil)
        #expect(log.weightKg == nil)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Uncompleting clears completion but keeps the entered values")
    func uncompleteSet() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)
        try harness.sessions.completeSet(log, weightKg: 20, reps: 10)
        harness.clock.advance(by: 30)

        try harness.sessions.uncompleteSet(log)

        #expect(log.isCompleted == false)
        #expect(log.completedAt == nil)
        #expect(log.reps == 10)
        #expect(log.weightKg == 20)
        #expect(log.updatedAt == harness.clock.current)
    }

    @Test("Completing an already completed set updates values and keeps the first completion time")
    func recompleteKeepsCompletionTime() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)
        try harness.sessions.completeSet(log, weightKg: 20, reps: 10)
        let completedAt = log.completedAt
        harness.clock.advance(by: 30)

        try harness.sessions.completeSet(log, weightKg: 20, reps: 11)
        #expect(log.reps == 11)
        #expect(log.completedAt == completedAt)
    }

    @Test("Editing values keeps the completion state; a completed set keeps its repetitions")
    func updateSetValues() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)

        try harness.sessions.updateSetValues(log, weightKg: 25, reps: nil)
        #expect(log.weightKg == 25)
        #expect(log.isCompleted == false)

        try harness.sessions.completeSet(log, weightKg: 25, reps: 8)
        try harness.sessions.updateSetValues(log, weightKg: 27.5, reps: 7)
        #expect(log.isCompleted)
        #expect(log.completedAt != nil)
        #expect(log.reps == 7)

        #expect(throws: SessionError.repsRequired) { try harness.sessions.updateSetValues(log, weightKg: 27.5, reps: nil) }
        #expect(throws: ValidationError.tooManyDecimals) { try harness.sessions.updateSetValues(log, weightKg: 27.555, reps: 7) }
        #expect(log.weightKg == 27.5)
        #expect(log.reps == 7)
        #expect(harness.context.hasChanges == false)
    }

    @Test("A set done without a load counts nothing in the load lifted; a load typed later is recorded, counted, and the set stays done")
    func loadTypedOnASetDoneWithoutOne() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)

        try harness.sessions.completeSet(log, weightKg: nil, reps: 10)
        let before = SessionProgress.volumeKg(of: session.orderedExercises.flatMap(\.orderedSetLogs))
        #expect(log.weightKg == nil)
        #expect(before == 0)

        try harness.sessions.updateSetValues(log, weightKg: 50, reps: 10)
        let after = SessionProgress.volumeKg(of: session.orderedExercises.flatMap(\.orderedSetLogs))
        #expect(log.isCompleted)
        #expect(log.weightKg == 50)
        #expect(log.reps == 10)
        #expect(after == 500)
    }

    @Test("Recorded values go up to 1.000 kg and 100 repetitions, when editing and when completing")
    func recordedValuesAtTheLimit() throws {
        let session = try harness.sessions.startSession(from: workout)
        let logs = session.orderedExercises[0].orderedSetLogs

        try harness.sessions.updateSetValues(logs[0], weightKg: 1_000, reps: 100)
        #expect(logs[0].weightKg == 1_000)
        #expect(logs[0].reps == 100)
        #expect(logs[0].isCompleted == false)

        try harness.sessions.completeSet(logs[1], weightKg: 1_000, reps: 100)
        #expect(logs[1].isCompleted)
        #expect(logs[1].weightKg == 1_000)
        #expect(logs[1].reps == 100)
    }

    @Test("Values above 1.000 kg or 100 repetitions are refused when editing and when completing, and nothing is saved")
    func recordedValuesAboveTheLimit() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)
        let untouchedAt = harness.clock.current

        // Not completed yet.
        harness.clock.advance(by: 60)
        #expect(throws: ValidationError.weightTooHigh) { try harness.sessions.updateSetValues(log, weightKg: 1_000.01, reps: 10) }
        #expect(throws: ValidationError.weightTooHigh) { try harness.sessions.updateSetValues(log, weightKg: 5_000, reps: nil) }
        #expect(throws: ValidationError.repsTooHigh) { try harness.sessions.updateSetValues(log, weightKg: 20, reps: 101) }
        #expect(throws: ValidationError.weightTooHigh) { try harness.sessions.completeSet(log, weightKg: 1_000.01, reps: 10) }
        #expect(throws: ValidationError.repsTooHigh) { try harness.sessions.completeSet(log, weightKg: 20, reps: 101) }
        #expect(log.weightKg == nil)
        #expect(log.reps == nil)
        #expect(log.isCompleted == false)
        #expect(log.completedAt == nil)
        #expect(log.updatedAt == untouchedAt)
        #expect(session.updatedAt == untouchedAt)
        #expect(harness.context.hasChanges == false)

        // Already completed: the values it has stay.
        try harness.sessions.completeSet(log, weightKg: 22.5, reps: 9)
        let completedAt = log.completedAt
        let updatedAt = log.updatedAt
        harness.clock.advance(by: 60)
        #expect(throws: ValidationError.weightTooHigh) { try harness.sessions.updateSetValues(log, weightKg: 1_000.01, reps: 9) }
        #expect(throws: ValidationError.repsTooHigh) { try harness.sessions.updateSetValues(log, weightKg: 22.5, reps: 101) }
        #expect(throws: ValidationError.repsTooHigh) { try harness.sessions.completeSet(log, weightKg: 22.5, reps: 1_000_000) }
        #expect(log.isCompleted)
        #expect(log.completedAt == completedAt)
        #expect(log.weightKg == 22.5)
        #expect(log.reps == 9)
        #expect(log.updatedAt == updatedAt)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Values stored before the limits existed are kept: only what is saved from now on is checked")
    func valuesStoredBeforeTheLimitsAreKept() throws {
        let session = try harness.sessions.startSession(from: workout)
        let logs = session.orderedExercises[0].orderedSetLogs
        // Written directly, as an earlier version of the app could have stored it.
        logs[0].weightKg = 1_500
        logs[0].reps = 150
        logs[0].isCompleted = true
        logs[0].completedAt = harness.clock.current
        try harness.context.save()

        try harness.sessions.completeSet(logs[1], weightKg: 20, reps: 8)
        try harness.sessions.finishSession(session)

        #expect(session.isActive == false)
        #expect(logs[0].weightKg == 1_500)
        #expect(logs[0].reps == 150)
        #expect(logs[0].isCompleted)
    }

    @Test("Sets of a finished session cannot be changed")
    func finishedSessionIsReadOnly() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)
        try harness.sessions.completeSet(log, weightKg: 20, reps: 10)
        try harness.sessions.finishSession(session)
        let other = session.orderedExercises[1].orderedSetLogs[0]

        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.uncompleteSet(log) }
        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.updateSetValues(log, weightKg: 30, reps: 5) }
        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.completeSet(other, weightKg: nil, reps: 12) }
        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.finishSession(session) }
        #expect(log.isCompleted)
        #expect(log.reps == 10)
        #expect(other.isCompleted == false)
    }

    // MARK: - Set types

    @Test("Starting copies the type of every planned set")
    func startCopiesSetTypes() throws {
        let planned = workout.orderedExercises[0].orderedPlannedSets
        try harness.workouts.setType(.warmup, of: planned[0])
        try harness.workouts.setType(.failure, of: planned[1])
        try harness.workouts.setType(.feeder, of: workout.orderedExercises[1].orderedPlannedSets[0])

        let session = try harness.sessions.startSession(from: workout)

        #expect(session.orderedExercises.map { $0.orderedSetLogs.map(\.setType) } == [[.warmup, .failure], [.feeder]])
        // Changing the plan afterwards does not change the session.
        try harness.workouts.setType(.working, of: planned[0])
        #expect(firstLog(of: session).setType == .warmup)
    }

    @Test("Sets added during the session are working sets, whatever the type of the set before")
    func addedSetsAreWorkingSets() throws {
        try harness.workouts.setType(.warmup, of: workout.orderedExercises[0].orderedPlannedSets[1])
        let session = try harness.sessions.startSession(from: workout)
        let performed = session.orderedExercises[0]

        let added = try harness.sessions.addSetCopyingLast(to: performed)
        #expect(performed.orderedSetLogs.map(\.setType) == [.working, .warmup, .working])
        #expect(added.targetWeightKg == 22.25)

        let row = try harness.exercises.createCustomExercise(name: "Remada", muscleGroup: .back)
        let newExercise = try #require(try harness.sessions.addExercises([row], to: session).first)
        #expect(newExercise.orderedSetLogs.map(\.setType) == [.working])
    }

    @Test("The type of a set changes during the session, done or not, and only in the session")
    func changeSetTypeDuringTheSession() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)
        try harness.sessions.completeSet(log, weightKg: 40, reps: 15)
        harness.clock.advance(by: 20)

        try harness.sessions.setType(.warmup, of: log)

        #expect(log.setType == .warmup)
        #expect(log.isCompleted)
        #expect(log.updatedAt == harness.clock.current)
        #expect(session.updatedAt == harness.clock.current)
        #expect(harness.context.hasChanges == false)
        #expect(workout.orderedExercises[0].orderedPlannedSets[0].setType == .working)
        // A warm-up done no longer counts in the load lifted.
        #expect(SessionProgress.volumeKg(of: session.orderedExercises.flatMap(\.orderedSetLogs)) == 0)
    }

    @Test("The type of a set of a finished session cannot be changed")
    func finishedSessionKeepsSetTypes() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)
        try harness.sessions.completeSet(log, weightKg: 20, reps: 10)
        try harness.sessions.finishSession(session)

        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.setType(.failure, of: log) }
        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.setType(.working, of: log) }
        #expect(log.setType == .working)
    }

    // MARK: - Recent sessions

    @Test("Recent sessions are the latest three finished ones, the most recently started first; none in progress")
    func recentSessions() throws {
        let base = harness.clock.current
        for offset in 0..<5 {
            let start = base.addingTimeInterval(Double(offset) * 3_600)
            let session = Session(startedAt: start, workoutNameSnapshot: "Treino \(offset)")
            session.endedAt = start.addingTimeInterval(1_800)
            harness.context.insert(session)
        }
        // The most recent of all is still in progress, so it is not a recent session.
        harness.context.insert(Session(startedAt: base.addingTimeInterval(10 * 3_600), workoutNameSnapshot: "Em andamento"))
        try harness.context.save()

        let recent = try harness.context.fetch(SessionService.recentSessionsDescriptor)

        #expect(SessionService.recentSessionsLimit == 3)
        #expect(recent.map(\.workoutNameSnapshot) == ["Treino 4", "Treino 3", "Treino 2"])
    }

    @Test("Sessions that started at the same moment are ordered by when they were created; none is a no-op")
    func recentSessionsTieAndEmpty() throws {
        #expect(try harness.context.fetch(SessionService.recentSessionsDescriptor).isEmpty)

        let start = harness.clock.current
        for (name, createdOffset) in [("Antiga", 0.0), ("Nova", 60.0)] {
            let session = Session(startedAt: start, workoutNameSnapshot: name)
            session.createdAt = start.addingTimeInterval(createdOffset)
            session.endedAt = start.addingTimeInterval(1_800)
            harness.context.insert(session)
        }
        try harness.context.save()

        let recent = try harness.context.fetch(SessionService.recentSessionsDescriptor)

        #expect(recent.map(\.workoutNameSnapshot) == ["Nova", "Antiga"])
    }

    // MARK: - Finish

    @Test("Finishing sets the end time, so the session is no longer active")
    func finishSession() throws {
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: session), weightKg: 20, reps: 10)
        harness.clock.advance(by: 2_700)

        try harness.sessions.finishSession(session)

        #expect(session.endedAt == harness.clock.current)
        #expect(session.duration == 2_700)
        #expect(session.isActive == false)
        #expect(session.updatedAt == harness.clock.current)
        #expect(try harness.sessions.activeSession() == nil)
    }

    @Test("Finishing keeps the sets that were not completed")
    func finishKeepsIncompleteSets() throws {
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: session), weightKg: 20, reps: 10)

        try harness.sessions.finishSession(session)

        #expect(try count(SetLog.self, in: harness.context) == 3)
        let states = session.orderedExercises.flatMap(\.orderedSetLogs).map { ($0.isCompleted, $0.completedAt == nil) }
        #expect(states.map(\.0) == [true, false, false])
        #expect(states.map(\.1) == [false, true, true])
    }

    @Test("A session without any completed set cannot be finished and stays intact")
    func finishWithoutCompletedSets() throws {
        let session = try harness.sessions.startSession(from: workout)
        let log = firstLog(of: session)
        try harness.sessions.updateSetValues(log, weightKg: 20, reps: 10)
        let before = try storeCounts(in: harness.context)

        #expect(throws: SessionError.noCompletedSets) { try harness.sessions.finishSession(session) }
        #expect(session.isActive)
        #expect(session.endedAt == nil)
        #expect(try storeCounts(in: harness.context) == before)
        #expect(try harness.sessions.activeSession()?.id == session.id)

        // A set completed and then uncompleted does not count either.
        try harness.sessions.completeSet(log, weightKg: 20, reps: 10)
        try harness.sessions.uncompleteSet(log)
        #expect(throws: SessionError.noCompletedSets) { try harness.sessions.finishSession(session) }
        #expect(session.isActive)
    }

    // MARK: - Session left open

    @Test("Up to an hour after the last completed set, finishing offers no other end")
    func noSuggestedEndWithinAnHour() throws {
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: session), weightKg: 20, reps: 10)

        harness.clock.advance(by: 59 * 60)
        #expect(harness.sessions.suggestedEnd(for: session) == nil)
        // Exactly one hour is not more than one hour.
        harness.clock.advance(by: 60)
        #expect(harness.sessions.suggestedEnd(for: session) == nil)
    }

    @Test("More than an hour after the last completed set, finishing offers the time of that set")
    func suggestedEndAfterAnHour() throws {
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: session), weightKg: 20, reps: 10)
        let completion = harness.clock.current

        harness.clock.advance(by: 61 * 60)

        #expect(SessionService.forgottenSessionThreshold == 3_600)
        #expect(harness.sessions.suggestedEnd(for: session) == completion)
        // Asking changes nothing: the session is still in progress.
        #expect(session.isActive)
    }

    @Test("Ending at the last record gives the session the duration up to that set, in the history and the recent sessions too")
    func finishAtTheLastRecord() throws {
        let session = try harness.sessions.startSession(from: workout)
        harness.clock.advance(by: 2_700)
        try harness.sessions.completeSet(firstLog(of: session), weightKg: 20, reps: 10)
        let completion = harness.clock.current
        harness.clock.advance(by: 61 * 60)

        try harness.sessions.finishSession(session, endingAt: .lastCompletedSet)

        #expect(session.endedAt == completion)
        #expect(session.duration == 2_700)
        #expect(session.isActive == false)
        #expect(session.updatedAt == harness.clock.current)
        #expect(HistorySessionDetail(session).duration == 2_700)
        #expect(try harness.context.fetch(SessionService.recentSessionsDescriptor).first?.duration == 2_700)
    }

    @Test("Ending now records the moment it is finished, even for a session left open")
    func finishNowAfterAnHour() throws {
        let session = try harness.sessions.startSession(from: workout)
        let start = harness.clock.current
        try harness.sessions.completeSet(firstLog(of: session), weightKg: 20, reps: 10)
        harness.clock.advance(by: 61 * 60)

        try harness.sessions.finishSession(session, endingAt: .now)

        #expect(session.endedAt == harness.clock.current)
        #expect(session.duration == harness.clock.current.timeIntervalSince(start))
    }

    @Test("The last record is the latest completed set, wherever it is; an unchecked set does not count")
    func lastRecordIsTheLatestCompletedSet() throws {
        let session = try harness.sessions.startSession(from: workout)
        let logs = session.orderedExercises.flatMap(\.orderedSetLogs)
        // The set of the second exercise is done before the second set of the first exercise.
        harness.clock.advance(by: 600)
        try harness.sessions.completeSet(logs[2], weightKg: nil, reps: 12)
        harness.clock.advance(by: 600)
        try harness.sessions.completeSet(logs[1], weightKg: 22, reps: 6)
        let latest = harness.clock.current
        // The first set is done later and then unchecked.
        harness.clock.advance(by: 600)
        try harness.sessions.completeSet(logs[0], weightKg: 20, reps: 10)
        try harness.sessions.uncompleteSet(logs[0])
        harness.clock.advance(by: 2 * 3_600)

        #expect(harness.sessions.suggestedEnd(for: session) == latest)
        try harness.sessions.finishSession(session, endingAt: .lastCompletedSet)
        #expect(session.endedAt == latest)
    }

    @Test("The end stays between the start and now, even with the device clock set back")
    func endStaysBetweenStartAndNow() throws {
        // The clock goes back to between the start and the last record: the session ends now.
        let first = try harness.sessions.startSession(from: workout)
        let firstStart = harness.clock.current
        harness.clock.advance(by: 600)
        try harness.sessions.completeSet(firstLog(of: first), weightKg: 20, reps: 10)
        harness.clock.advance(by: -300)
        #expect(harness.sessions.suggestedEnd(for: first) == nil)
        try harness.sessions.finishSession(first, endingAt: .lastCompletedSet)
        #expect(first.endedAt == firstStart.addingTimeInterval(300))

        // The clock goes back to before the start: the session ends when it started.
        let second = try harness.sessions.startSession(from: workout)
        harness.clock.advance(by: 600)
        try harness.sessions.completeSet(firstLog(of: second), weightKg: 20, reps: 10)
        harness.clock.advance(by: -2 * 3_600)
        #expect(harness.sessions.suggestedEnd(for: second) == nil)
        try harness.sessions.finishSession(second, endingAt: .lastCompletedSet)
        #expect(second.endedAt == second.startedAt)
        #expect(second.duration == 0)
    }

    // MARK: - Discard

    @Test("Discarding deletes only the active session's data")
    func discardSession() throws {
        let finished = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: finished), weightKg: 20, reps: 10)
        try harness.sessions.finishSession(finished)
        let active = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: active), weightKg: 20, reps: 8)

        try harness.sessions.discardSession(active)

        #expect(try harness.sessions.activeSession() == nil)
        #expect(try count(Session.self, in: harness.context) == 1)
        #expect(try count(SessionExercise.self, in: harness.context) == 2)
        #expect(try count(SetLog.self, in: harness.context) == 3)
        #expect(finished.endedAt != nil)
        #expect(try count(Workout.self, in: harness.context) == 1)
        #expect(try count(PlannedSet.self, in: harness.context) == 3)
        #expect(try count(Exercise.self, in: harness.context) == 2)
    }

    @Test("A finished session cannot be discarded")
    func discardFinishedSession() throws {
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: session), weightKg: 20, reps: 10)
        try harness.sessions.finishSession(session)
        let before = try storeCounts(in: harness.context)

        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.discardSession(session) }
        #expect(try storeCounts(in: harness.context) == before)
    }

    // MARK: - Free sessions and changes during a session

    /// Counts of the planned workout's records, to prove a session change never touches the plan.
    private func planCounts() throws -> [Int] {
        [
            try count(Workout.self, in: harness.context),
            try count(WorkoutExercise.self, in: harness.context),
            try count(PlannedSet.self, in: harness.context),
        ]
    }

    @Test("A free session starts empty, without a workout")
    func startFreeSession() throws {
        let session = try harness.sessions.startFreeSession()

        #expect(session.isActive)
        #expect(session.startedAt == harness.clock.current)
        #expect(session.workout == nil)
        #expect(session.workoutNameSnapshot == "")
        #expect(session.exercises.isEmpty)
        #expect(try harness.sessions.activeSession()?.id == session.id)
    }

    @Test("No session can start while another is in progress, of either kind")
    func startWhileActive() throws {
        try harness.sessions.startFreeSession()
        let before = try storeCounts(in: harness.context)

        #expect(throws: SessionError.activeSessionExists) { try harness.sessions.startFreeSession() }
        #expect(throws: SessionError.activeSessionExists) { try harness.sessions.startSession(from: workout) }
        #expect(try storeCounts(in: harness.context) == before)
    }

    @Test("With two sessions left open, a new one is refused and the most recent is listed first")
    func twoActiveSessions() throws {
        let older = Session(startedAt: harness.clock.current, workoutNameSnapshot: "A")
        let newer = Session(startedAt: harness.clock.current.addingTimeInterval(60), workoutNameSnapshot: "B")
        harness.context.insert(older)
        harness.context.insert(newer)
        try harness.context.save()

        #expect(throws: SessionError.activeSessionExists) { try harness.sessions.startSession(from: workout) }
        let listed = try harness.context.fetch(SessionService.activeSessionsDescriptor)
        #expect(listed.map(\.workoutNameSnapshot) == ["B", "A"])

        // Discarding the shown one leaves the other, which is shown next; nothing else is lost.
        try harness.sessions.discardSession(newer)
        #expect(try harness.context.fetch(SessionService.activeSessionsDescriptor).map(\.id) == [older.id])
    }

    @Test("Exercises added to a session get one empty set and change only the session")
    func addExercisesToSession() throws {
        let session = try harness.sessions.startSession(from: workout)
        let row = try harness.exercises.createCustomExercise(name: "Remada", muscleGroup: .back)
        let plan = try planCounts()
        harness.clock.advance(by: 30)

        let added = try harness.sessions.addExercises([row], to: session)

        #expect(added.count == 1)
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta", "Remada"])
        #expect(session.orderedExercises.map(\.sortIndex) == [0, 1, 2])
        let performed = try #require(added.first)
        #expect(performed.exercise?.id == row.id)
        #expect(performed.muscleGroupSnapshot == .back)
        let sets = performed.orderedSetLogs
        #expect(sets.count == 1)
        #expect(sets[0].isCompleted == false)
        #expect(sets[0].reps == nil && sets[0].weightKg == nil && sets[0].targetRepsMax == nil)
        #expect(session.updatedAt == harness.clock.current)
        #expect(try planCounts() == plan)
        #expect(workout.orderedExercises.count == 2)
    }

    @Test("A free session receives exercises in the chosen order")
    func addExercisesToFreeSession() throws {
        let session = try harness.sessions.startFreeSession()

        try harness.sessions.addExercises([curl, bench], to: session)

        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Rosca Direta", "Supino Reto"])
        #expect(session.orderedExercises.map(\.sortIndex) == [0, 1])
    }

    @Test("Adding exercises is all or nothing: repeated or archived exercises change nothing")
    func addExercisesRules() throws {
        let session = try harness.sessions.startSession(from: workout)
        let row = try harness.exercises.createCustomExercise(name: "Remada", muscleGroup: .back)
        let hidden = try harness.exercises.createCustomExercise(name: "Antigo", muscleGroup: .back)
        try harness.exercises.archive(hidden)
        let before = try storeCounts(in: harness.context)

        #expect(throws: WorkoutError.exerciseAlreadyInWorkout) { try harness.sessions.addExercises([row, bench], to: session) }
        #expect(throws: WorkoutError.exerciseAlreadyInWorkout) { try harness.sessions.addExercises([row, row], to: session) }
        #expect(throws: WorkoutError.exerciseArchived) { try harness.sessions.addExercises([row, hidden], to: session) }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)
        #expect(try harness.sessions.addExercises([], to: session).isEmpty)
    }

    @Test("A finished session receives no exercises or sets")
    func changesAfterFinishing() throws {
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: session), weightKg: 20, reps: 10)
        try harness.sessions.finishSession(session)
        let row = try harness.exercises.createCustomExercise(name: "Remada", muscleGroup: .back)
        let before = try storeCounts(in: harness.context)

        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.addExercises([row], to: session) }
        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.addSetCopyingLast(to: session.orderedExercises[0]) }
        #expect(try storeCounts(in: harness.context) == before)
    }

    @Test("An added set copies the last set's load and targets, without repetitions, and changes only the session")
    func addSet() throws {
        let session = try harness.sessions.startSession(from: workout)
        let performed = session.orderedExercises[0]
        try harness.sessions.completeSet(performed.orderedSetLogs[1], weightKg: 25, reps: 7)
        let plan = try planCounts()

        let added = try harness.sessions.addSetCopyingLast(to: performed)

        #expect(performed.orderedSetLogs.map(\.id).last == added.id)
        #expect(added.sortIndex == 2)
        #expect(added.weightKg == 25)
        #expect(added.reps == nil)
        #expect(added.isCompleted == false)
        #expect(added.completedAt == nil)
        #expect(added.targetWeightKg == 22.25)
        #expect(added.targetRepsMin == 6)
        #expect(added.targetRepsMax == 8)
        #expect(try planCounts() == plan)
        #expect(workout.orderedExercises[0].orderedPlannedSets.count == 2)
    }

    @Test("A free session with added exercises and sets is kept after the store is reopened")
    func freeSessionSurvivesReopening() throws {
        try roundTripThroughDisk { context in
            let services = ServiceTestHarness(container: context.container)
            let exercise = try services.exercises.createCustomExercise(name: "Remada", muscleGroup: .back)
            let session = try services.sessions.startFreeSession()
            let performed = try #require(try services.sessions.addExercises([exercise], to: session).first)
            try services.sessions.completeSet(performed.orderedSetLogs[0], weightKg: 40, reps: 10)
            try services.sessions.addSetCopyingLast(to: performed)
        } read: { context in
            let session = try #require(try SessionService(context: context).activeSession())
            let logs = session.orderedExercises[0].orderedSetLogs
            #expect(session.workout == nil)
            #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Remada"])
            #expect(logs.map(\.isCompleted) == [true, false])
            #expect(logs.map(\.weightKg) == [40, 40])
            #expect(logs.map(\.reps) == [10, nil])
        }
    }

    // MARK: - Removing sets and exercises

    @Test("Removing a set moves the next ones up and changes only the session")
    func removeSet() throws {
        let session = try harness.sessions.startSession(from: workout)
        let performed = session.orderedExercises[0]
        try harness.sessions.addSetCopyingLast(to: performed)
        let logs = performed.orderedSetLogs
        let plan = try planCounts()
        harness.clock.advance(by: 30)

        try harness.sessions.removeSet(logs[0])

        let remaining = performed.orderedSetLogs
        #expect(remaining.map(\.id) == [logs[1].id, logs[2].id])
        #expect(remaining.map(\.sortIndex) == [0, 1])
        #expect(session.updatedAt == harness.clock.current)
        #expect(try count(SetLog.self, in: harness.context) == 3)
        #expect(try planCounts() == plan)
        #expect(workout.orderedExercises[0].orderedPlannedSets.count == 2)
    }

    @Test("A set already done can be removed, and so can the last set of an exercise, which stays without sets")
    func removeDoneAndLastSet() throws {
        let session = try harness.sessions.startSession(from: workout)
        let curlSet = session.orderedExercises[1].orderedSetLogs[0]
        try harness.sessions.completeSet(curlSet, weightKg: nil, reps: 12)

        try harness.sessions.removeSet(curlSet)

        #expect(session.orderedExercises.count == 2)
        #expect(session.orderedExercises[1].setLogs.isEmpty)
        // A set can be added to it again.
        try harness.sessions.addSetCopyingLast(to: session.orderedExercises[1])
        #expect(session.orderedExercises[1].setLogs.count == 1)
    }

    @Test("Removing an exercise removes its sets, done or not, moves the next exercises up and changes only the session")
    func removeExercise() throws {
        let session = try harness.sessions.startSession(from: workout)
        let performed = session.orderedExercises[0]
        try harness.sessions.completeSet(performed.orderedSetLogs[0], weightKg: 20, reps: 10)
        let plan = try planCounts()

        try harness.sessions.removeExercise(performed)

        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Rosca Direta"])
        #expect(session.orderedExercises.map(\.sortIndex) == [0])
        #expect(try count(SessionExercise.self, in: harness.context) == 1)
        #expect(try count(SetLog.self, in: harness.context) == 1)
        #expect(try planCounts() == plan)
        #expect(workout.orderedExercises.count == 2)
        // The exercise can be added to the session again.
        try harness.sessions.addExercises([bench], to: session)
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Rosca Direta", "Supino Reto"])
    }

    @Test("Sets and exercises of a finished session cannot be removed")
    func removeNeedsAnActiveSession() throws {
        let session = try harness.sessions.startSession(from: workout)
        let performed = session.orderedExercises[0]
        try harness.sessions.completeSet(performed.orderedSetLogs[0], weightKg: 20, reps: 10)
        try harness.sessions.finishSession(session)

        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.removeSet(performed.orderedSetLogs[1]) }
        #expect(throws: SessionError.sessionNotActive) { try harness.sessions.removeExercise(performed) }
        #expect(performed.setLogs.count == 2)
        #expect(session.exercises.count == 2)
        #expect(harness.context.hasChanges == false)
    }

    // MARK: - Última vez

    /// Starts a session of `workout`, lets `complete` do its sets, and finishes it 10 minutes later; the
    /// next session starts an hour after that.
    @discardableResult
    private func finishedSession(_ complete: ([SetLog], [SetLog]) throws -> Void) throws -> Session {
        let session = try harness.sessions.startSession(from: workout)
        try complete(session.orderedExercises[0].orderedSetLogs, session.orderedExercises[1].orderedSetLogs)
        harness.clock.advance(by: 600)
        try harness.sessions.finishSession(session)
        harness.clock.advance(by: 3_600)
        return session
    }

    @Test("The last time is the latest finished session with the exercise done, set by set in the order of the sets done")
    func lastTime() throws {
        try finishedSession { bench, _ in
            try harness.sessions.completeSet(bench[0], weightKg: 20, reps: 10)
            try harness.sessions.completeSet(bench[1], weightKg: 22.5, reps: 8)
        }
        // More recent: only the second set done, so it goes with set 1.
        try finishedSession { bench, _ in
            try harness.sessions.completeSet(bench[1], weightKg: 25, reps: 7)
        }
        // The most recent has no set of the bench press done: it is skipped for that exercise.
        try finishedSession { _, curl in
            try harness.sessions.completeSet(curl[0], weightKg: nil, reps: 12)
        }
        let current = try harness.sessions.startSession(from: workout)

        let last = try harness.sessions.lastPerformances(for: current)

        #expect(last[bench.id] == [PreviousSet(weightKg: 25, reps: 7)])
        #expect(last[curl.id] == [PreviousSet(weightKg: nil, reps: 12)], "Without a load, only the repetitions")
    }

    @Test("The last time may have fewer sets than now; an exercise never done has none")
    func lastTimeWithFewerSets() throws {
        try finishedSession { bench, _ in
            try harness.sessions.completeSet(bench[0], weightKg: 20, reps: 10)
        }
        let current = try harness.sessions.startSession(from: workout)

        let last = try harness.sessions.lastPerformances(for: current)

        #expect(last[bench.id] == [PreviousSet(weightKg: 20, reps: 10)])
        #expect(last[curl.id] == nil)
        // The second set has nothing to show ("—") and suggests the plan.
        let secondSet = current.orderedExercises[0].orderedSetLogs[1]
        let previous = last[bench.id]?.dropFirst().first
        #expect(previous == nil)
        #expect(LastPerformance.suggestion(
            previous: previous,
            targetWeightKg: secondSet.targetWeightKg,
            targetRepsMin: secondSet.targetRepsMin,
            targetRepsMax: secondSet.targetRepsMax
        ) == SetSuggestion(weightKg: 22.25, reps: 8))
    }

    @Test("The exercise is matched by its relationship: a deleted exercise's sets are never offered, even under its name")
    func lastTimeOfADeletedExercise() throws {
        try finishedSession { _, curlSets in
            try harness.sessions.completeSet(curlSets[0], weightKg: 10, reps: 12)
        }
        harness.context.delete(curl)
        try harness.context.save()
        let sameName = try harness.exercises.createCustomExercise(name: "Rosca Direta", muscleGroup: .biceps)
        let current = try harness.sessions.startFreeSession()
        try harness.sessions.addExercises([sameName], to: current)

        #expect(try harness.sessions.lastPerformances(for: current).isEmpty)
    }

    @Test("The current session and the sessions not finished are never the last time")
    func lastTimeIgnoresSessionsNotFinished() throws {
        let finished = try finishedSession { bench, _ in
            try harness.sessions.completeSet(bench[0], weightKg: 20, reps: 10)
        }
        // Started after it: a session left open and the current one, both with the bench press done.
        let open = try insertOpenSession(name: "Antigo", startedAt: harness.clock.current, createdAt: harness.clock.current, weightKg: 30)
        let openSet = open.orderedExercises[0].orderedSetLogs[0]
        openSet.reps = 10
        openSet.isCompleted = true
        harness.clock.advance(by: 600)
        let current = Session(startedAt: harness.clock.current, workoutNameSnapshot: "Push")
        harness.context.insert(current)
        let performed = SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Supino Reto", muscleGroupSnapshot: .chest)
        harness.context.insert(performed)
        performed.session = current
        performed.exercise = bench
        let currentSet = SetLog(sortIndex: 0, weightKg: 40, reps: 8)
        currentSet.isCompleted = true
        harness.context.insert(currentSet)
        currentSet.sessionExercise = performed
        try harness.context.save()

        #expect(try harness.sessions.lastPerformances(for: current)[bench.id] == [PreviousSet(weightKg: 20, reps: 10)])
        // A finished session is skipped when it is the one excluded (the current one, once finished).
        #expect(LastPerformance.previousSets(for: [bench.id], in: [finished], excluding: finished.id).isEmpty)
        #expect(LastPerformance.previousSets(for: [bench.id], in: [finished], excluding: nil)[bench.id] == [PreviousSet(weightKg: 20, reps: 10)])
    }

    // MARK: - Two sessions left open

    /// Inserts a session in progress with one exercise and one set, at explicit times. The services
    /// never open a second session, so this inconsistent state is built directly.
    private func insertOpenSession(name: String, startedAt: Date, createdAt: Date, weightKg: Double? = nil) throws -> Session {
        let session = Session(startedAt: startedAt, workoutNameSnapshot: name)
        session.createdAt = createdAt
        session.updatedAt = createdAt
        harness.context.insert(session)
        let performed = SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Supino Reto", muscleGroupSnapshot: .chest)
        performed.createdAt = createdAt
        performed.updatedAt = createdAt
        harness.context.insert(performed)
        performed.session = session
        performed.exercise = bench
        let log = SetLog(sortIndex: 0, weightKg: weightKg)
        log.createdAt = createdAt
        log.updatedAt = createdAt
        harness.context.insert(log)
        log.sessionExercise = performed
        try harness.context.save()
        return session
    }

    @Test("With two sessions left open, reporting it and refusing new starts change nothing")
    func twoOpenSessionsStayUntouched() throws {
        let older = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: older), weightKg: 20, reps: 10)
        try harness.sessions.updateSetValues(older.orderedExercises[0].orderedSetLogs[1], weightKg: 22.5, reps: nil)
        harness.clock.advance(by: 60)
        let newer = try insertOpenSession(name: "Livre", startedAt: harness.clock.current, createdAt: harness.clock.current, weightKg: 30)
        let before = try historySnapshot(harness.context)
        // Anything written from here on would carry a different time.
        harness.clock.advance(by: 60)

        #expect(throws: SessionError.multipleActiveSessions) { try harness.sessions.activeSession() }
        #expect(throws: SessionError.activeSessionExists) { try harness.sessions.startFreeSession() }
        #expect(throws: SessionError.activeSessionExists) { try harness.sessions.startSession(from: workout) }
        // What the screens read: the sessions in progress, and the one the Home shows.
        let listed = try harness.context.fetch(SessionService.activeSessionsDescriptor)
        #expect(TodayWorkoutState.resolve(activeSessions: listed, hasWorkouts: true)
            == .inProgress(name: newer.workoutNameSnapshot, startedAt: newer.startedAt))

        // No session is closed, deleted or changed, and nothing is left to save.
        #expect(try historySnapshot(harness.context) == before)
        #expect(harness.context.hasChanges == false)
    }

    @Test("The session bar and the Home show the same session: the most recently started, then the most recently created")
    func openSessionsOrder() throws {
        let start = harness.clock.current
        // Inserted in neither the expected order nor its reverse, so the order of insertion explains nothing.
        let earlierCreated = try insertOpenSession(name: "B", startedAt: start.addingTimeInterval(60), createdAt: start.addingTimeInterval(60))
        // Started first but created last: the start time decides before the creation time.
        let earliest = try insertOpenSession(name: "A", startedAt: start, createdAt: start.addingTimeInterval(300))
        // Started at the same time as "B": the most recently created comes first.
        let laterCreated = try insertOpenSession(name: "C", startedAt: start.addingTimeInterval(60), createdAt: start.addingTimeInterval(61))

        let listed = try harness.context.fetch(SessionService.activeSessionsDescriptor)
        #expect(listed.map(\.id) == [laterCreated.id, earlierCreated.id, earliest.id])
        // The session bar opens the first one; the Home shows the one `resolve` picks from the same list.
        let first = try #require(listed.first)
        #expect(TodayWorkoutState.resolve(activeSessions: listed, hasWorkouts: true)
            == .inProgress(name: first.workoutNameSnapshot, startedAt: first.startedAt))
    }

    @Test("Finishing the most recent of two open sessions leaves the other in progress, with all its data intact")
    func finishNewestOfTwoOpenSessions() throws {
        let older = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: older), weightKg: 20, reps: 10)
        try harness.sessions.updateSetValues(older.orderedExercises[0].orderedSetLogs[1], weightKg: 22.5, reps: nil)
        harness.clock.advance(by: 60)
        let newer = try insertOpenSession(name: "Livre", startedAt: harness.clock.current, createdAt: harness.clock.current, weightKg: 30)
        // Every stored value of the older session, its performed exercises and their sets.
        let olderKeys = ([older.id] + older.exercises.map(\.id) + older.exercises.flatMap(\.setLogs).map(\.id)).map(\.uuidString)
        let olderBefore = try historySnapshot(harness.context).filter { line in olderKeys.contains { line.contains($0) } }
        harness.clock.advance(by: 60)

        try harness.sessions.completeSet(firstLog(of: newer), weightKg: 30, reps: 8)
        try harness.sessions.finishSession(newer)

        #expect(newer.endedAt != nil)
        #expect(try count(Session.self, in: harness.context) == 2)
        #expect(try harness.context.fetch(SessionService.activeSessionsDescriptor).map(\.id) == [older.id])
        #expect(try harness.sessions.activeSession()?.id == older.id)
        let olderAfter = try historySnapshot(harness.context).filter { line in olderKeys.contains { line.contains($0) } }
        #expect(olderAfter == olderBefore)
    }

    @Test("Discarding the most recent of two open sessions deletes only its data and leaves the other in progress, intact")
    func discardNewestOfTwoOpenSessions() throws {
        let older = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(firstLog(of: older), weightKg: 20, reps: 10)
        try harness.sessions.updateSetValues(older.orderedExercises[0].orderedSetLogs[1], weightKg: 22.5, reps: nil)
        harness.clock.advance(by: 60)
        let newer = try insertOpenSession(name: "Livre", startedAt: harness.clock.current, createdAt: harness.clock.current, weightKg: 30)
        // Every stored value of the older session, its performed exercises and their sets.
        let olderKeys = ([older.id] + older.exercises.map(\.id) + older.exercises.flatMap(\.setLogs).map(\.id)).map(\.uuidString)
        let olderBefore = try historySnapshot(harness.context).filter { line in olderKeys.contains { line.contains($0) } }
        // Every stored value of the exercises and the planned workout.
        let planPrefixes = ["Exercise ", "Workout ", "WorkoutExercise ", "PlannedSet "]
        let planBefore = try historySnapshot(harness.context).filter { line in planPrefixes.contains { line.hasPrefix($0) } }
        harness.clock.advance(by: 60)

        try harness.sessions.discardSession(newer)

        #expect(try harness.context.fetch(SessionService.activeSessionsDescriptor).map(\.id) == [older.id])
        #expect(try harness.sessions.activeSession()?.id == older.id)
        // Only the discarded session and its own exercise and set are gone.
        #expect(try count(Session.self, in: harness.context) == 1)
        #expect(try count(SessionExercise.self, in: harness.context) == older.exercises.count)
        #expect(try count(SetLog.self, in: harness.context) == older.exercises.flatMap(\.setLogs).count)
        let olderAfter = try historySnapshot(harness.context).filter { line in olderKeys.contains { line.contains($0) } }
        #expect(olderAfter == olderBefore)
        let planAfter = try historySnapshot(harness.context).filter { line in planPrefixes.contains { line.hasPrefix($0) } }
        #expect(planAfter == planBefore)
    }
}
