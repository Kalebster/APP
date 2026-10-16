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

    @Test("Starting copies targets in order, pre-fills the load and leaves reps empty")
    func startCopiesTargets() throws {
        let session = try harness.sessions.startSession(from: workout)

        let benchLogs = session.orderedExercises[0].orderedSetLogs
        #expect(benchLogs.map(\.sortIndex) == [0, 1])
        #expect(benchLogs.map(\.targetWeightKg) == [20, 22.25])
        #expect(benchLogs.map(\.targetRepsMin) == [8, 6])
        #expect(benchLogs.map(\.targetRepsMax) == [10, 8])
        #expect(benchLogs.map(\.weightKg) == [20, 22.25])

        let allLogs = session.orderedExercises.flatMap(\.orderedSetLogs)
        #expect(allLogs.count == 3)
        #expect(allLogs.allSatisfy { $0.reps == nil && !$0.isCompleted && $0.completedAt == nil })
        #expect(session.orderedExercises[1].orderedSetLogs[0].weightKg == nil)
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
        #expect(log.weightKg == 20)
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
        #expect(log.weightKg == 20)
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
