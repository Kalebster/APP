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

        selection.toggle(squat.id)
        selection.toggle(bench.id)
        selection.toggle(row.id)
        #expect(selection.selectedIDs == [squat.id, bench.id, row.id])
        #expect(selection.count == 3)
        #expect(selection.isSelected(bench.id))

        selection.toggle(bench.id)
        #expect(selection.selectedIDs == [squat.id, row.id])
        #expect(!selection.isSelected(bench.id))
        #expect(selection.count == 2)
    }

    @Test("An exercise already in the workout is reported and cannot be selected")
    func exerciseInWorkoutNotSelectable() {
        var selection = ExerciseSelection(workoutExerciseIDs: [bench.id])

        selection.toggle(bench.id)

        #expect(selection.isInWorkout(bench.id))
        #expect(!selection.isInWorkout(row.id))
        #expect(!selection.isSelected(bench.id))
        #expect(selection.count == 0)
    }

    @Test("An exercise archived after it was chosen is not returned")
    func archivedNotReturned() {
        let archived = Exercise(name: "Antigo", muscleGroup: .chest, isCustom: true)
        var selection = ExerciseSelection(workoutExerciseIDs: [])
        selection.toggle(bench.id)
        selection.toggle(archived.id)

        archived.isArchived = true

        #expect(selection.selectedExercises(from: [bench, archived]).map(\.id) == [bench.id])
    }

    @Test("Selected exercises come back in selection order; missing ones are skipped")
    func selectedExercisesInOrder() {
        var selection = ExerciseSelection(workoutExerciseIDs: [])
        selection.toggle(row.id)
        selection.toggle(squat.id)
        selection.toggle(bench.id)

        #expect(selection.selectedExercises(from: [bench, row, squat]).map(\.id) == [row.id, squat.id, bench.id])
        #expect(selection.selectedExercises(from: [bench, squat]).map(\.id) == [squat.id, bench.id])
    }
}
