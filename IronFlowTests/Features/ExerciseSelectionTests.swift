import Foundation
import Testing
@testable import IronFlow

@MainActor
struct ExerciseSelectionTests {
    private let bench = Exercise(name: "Supino", muscleGroup: .chest, isCustom: false)
    private let row = Exercise(name: "Remada", muscleGroup: .back, isCustom: false)
    private let squat = Exercise(name: "Agachamento", muscleGroup: .quadriceps, isCustom: false)

    @Test("Toggling selects and deselects, keeping the selection order")
    func toggleKeepsOrder() {
        var selection = ExerciseSelection(workoutExerciseIDs: [])

        selection.toggle(squat)
        selection.toggle(bench)
        selection.toggle(row)
        #expect(selection.selectedIDs == [squat.id, bench.id, row.id])
        #expect(selection.count == 3)
        #expect(selection.isSelected(bench))

        selection.toggle(bench)
        #expect(selection.selectedIDs == [squat.id, row.id])
        #expect(!selection.isSelected(bench))
        #expect(selection.count == 2)
    }

    @Test("An exercise already in the workout is reported and cannot be selected")
    func exerciseInWorkoutNotSelectable() {
        var selection = ExerciseSelection(workoutExerciseIDs: [bench.id])

        selection.toggle(bench)

        #expect(selection.isInWorkout(bench))
        #expect(!selection.isInWorkout(row))
        #expect(!selection.isSelected(bench))
        #expect(selection.count == 0)
    }

    @Test("An archived exercise cannot be selected")
    func archivedNotSelectable() {
        let archived = Exercise(name: "Antigo", muscleGroup: .chest, isCustom: true)
        archived.isArchived = true
        var selection = ExerciseSelection(workoutExerciseIDs: [])

        selection.toggle(archived)

        #expect(selection.count == 0)
    }

    @Test("Selected exercises come back in selection order; missing ones are skipped")
    func selectedExercisesInOrder() {
        var selection = ExerciseSelection(workoutExerciseIDs: [])
        selection.toggle(row)
        selection.toggle(squat)
        selection.toggle(bench)

        #expect(selection.selectedExercises(from: [bench, row, squat]).map(\.id) == [row.id, squat.id, bench.id])
        #expect(selection.selectedExercises(from: [bench, squat]).map(\.id) == [squat.id, bench.id])
    }
}
