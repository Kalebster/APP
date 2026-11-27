import Foundation

/// The question before removing an exercise of the user's own, as in the approved prototype: archived
/// when it has history, deleted when it has none, and in both cases the planned workouts it leaves.
/// Pure logic.
enum ExerciseRemovalText {
    /// "Arquivar “Puxada”?" / "Apagar “Puxada”?".
    static func title(name: String, archives: Bool) -> String {
        archives ? String(localized: "Arquivar “\(name)”?") : String(localized: "Apagar “\(name)”?")
    }

    /// What happens, with the workouts the exercise leaves, in the order of the Treinos tab.
    static func message(archives: Bool, workoutNames: [String]) -> String {
        if archives {
            let workouts = workoutNames.isEmpty ? "" : String(localized: " e \(leaving(workoutNames))")
            return String(localized: "Ele sai da lista de exercícios\(workouts). O histórico e os recordes continuam guardados, e você pode restaurar em Exercícios › Meus.")
        }
        let what = workoutNames.isEmpty
            ? String(localized: "Ele não está em nenhum treino e ainda não tem histórico.")
            : String(localized: "Ele sai \(leaving(workoutNames)) e é apagado.")
        return what + " " + String(localized: "Não dá para desfazer.")
    }

    /// "Arquivar exercício" / "Apagar exercício".
    static func action(archives: Bool) -> String {
        archives ? String(localized: "Arquivar exercício") : String(localized: "Apagar exercício")
    }

    /// "do treino Push" or "de 2 treinos (Push e Pull)".
    private static func leaving(_ names: [String]) -> String {
        if names.count == 1 {
            return String(localized: "do treino \(names[0])")
        }
        return String(localized: "de \(names.count) treinos (\(ExerciseForm.list(names)))")
    }
}
