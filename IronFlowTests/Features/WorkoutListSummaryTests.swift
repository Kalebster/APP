import Foundation
import Testing
@testable import IronFlow

/// The texts of the Treinos tab: how many workouts are in the plan and what a workout card says.
@MainActor
struct WorkoutListSummaryTests {
    @Test("The plan subtitle: plural, singular and none")
    func planSubtitle() {
        #expect(WorkoutListSummary.planSubtitle(0) == "0 treinos no plano")
        #expect(WorkoutListSummary.planSubtitle(1) == "1 treino no plano")
        #expect(WorkoutListSummary.planSubtitle(2) == "2 treinos no plano")
        #expect(WorkoutListSummary.planSubtitle(12) == "12 treinos no plano")
    }

    @Test("A card says how many exercises and sets the workout holds, with singular forms")
    func cardSummaryFromCounts() {
        #expect(WorkoutListSummary.cardSummary(exercises: 0, sets: 0) == "Nenhum exercício")
        #expect(WorkoutListSummary.cardSummary(exercises: 1, sets: 1) == "1 exercício · 1 série")
        #expect(WorkoutListSummary.cardSummary(exercises: 1, sets: 3) == "1 exercício · 3 séries")
        #expect(WorkoutListSummary.cardSummary(exercises: 3, sets: 12) == "3 exercícios · 12 séries")
    }

    @Test("The card of a workout counts its exercises and the planned sets of all of them")
    func cardSummaryOfAWorkout() throws {
        let harness = try ServiceTestHarness()
        let bench = try harness.insertSystemExercise(name: "Supino Reto", muscleGroup: .chest, libraryKey: "bench-press")
        let curl = try harness.exercises.createCustomExercise(name: "Rosca Direta", muscleGroup: .biceps)

        let empty = try harness.workouts.createWorkout(name: "Vazio")
        let single = try harness.makeWorkout(name: "Rosca", items: [(curl, [.reps(10, 12)])])
        let push = try harness.makeWorkout(name: "Push", items: [
            (bench, [.reps(8, 10, kg: 20), .reps(6, 8, kg: 22.25), .reps(6, 8)]),
            (curl, [.reps(10, 12), .reps(10, 12)]),
        ])

        #expect(WorkoutListSummary.cardSummary(for: empty) == "Nenhum exercício")
        #expect(WorkoutListSummary.cardSummary(for: single) == "1 exercício · 1 série")
        #expect(WorkoutListSummary.cardSummary(for: push) == "2 exercícios · 5 séries")
    }
}
