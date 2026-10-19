import Foundation

/// The texts of the Treinos tab: how many workouts are in the plan and what a workout card says
/// about its content and muscle groups. Pure logic: no UI and no store access.
enum WorkoutListSummary {
    /// "3 treinos no plano", "1 treino no plano", "0 treinos no plano". The singular is chosen here:
    /// the Portuguese plural rules treat 0 as singular, which would read "0 treino".
    static func planSubtitle(_ count: Int) -> String {
        count == 1 ? String(localized: "1 treino no plano") : String(localized: "\(count) treinos no plano")
    }

    /// The card of `workout`: its exercises and the planned sets of all of them.
    static func cardSummary(for workout: Workout) -> String {
        cardSummary(exercises: workout.exercises.count, sets: workout.exercises.reduce(0) { $0 + $1.plannedSets.count })
    }

    /// The muscle groups of the workout's exercises, in the order of the exercises, each once.
    static func muscleGroups(of workout: Workout) -> [MuscleGroup] {
        var groups: [MuscleGroup] = []
        for item in workout.orderedExercises {
            if let group = item.exercise?.muscleGroup, !groups.contains(group) {
                groups.append(group)
            }
        }
        return groups
    }

    /// "Peito · Ombros · Tríceps"; empty without groups.
    static func muscleGroupsText(_ groups: [MuscleGroup]) -> String {
        groups.map { String(localized: $0.displayName) }.joined(separator: " · ")
    }

    /// What a workout card says about its content: "3 exercícios · 12 séries", "1 exercício · 3 séries",
    /// or "Nenhum exercício" when the workout has none.
    static func cardSummary(exercises: Int, sets: Int) -> String {
        guard exercises > 0 else { return String(localized: "Nenhum exercício") }
        // The catalog gives the singular and plural forms.
        return [String(localized: "\(exercises) exercícios"), String(localized: "\(sets) séries")].joined(separator: " · ")
    }
}
