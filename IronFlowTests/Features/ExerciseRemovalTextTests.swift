import Foundation
import Testing
@testable import IronFlow

/// The question before archiving or deleting an exercise of the user's own, as in the prototype.
struct ExerciseRemovalTextTests {
    @Test("Archiving says the workouts it leaves, and that the history stays")
    func archive() {
        #expect(ExerciseRemovalText.title(name: "Puxada", archives: true) == "Arquivar “Puxada”?")
        #expect(ExerciseRemovalText.action(archives: true) == "Arquivar exercício")
        #expect(ExerciseRemovalText.message(archives: true, workoutNames: []) == "Ele sai da lista de exercícios. O histórico e os recordes continuam guardados, e você pode restaurar em Exercícios › Meus.")
        #expect(ExerciseRemovalText.message(archives: true, workoutNames: ["Pull"]) == "Ele sai da lista de exercícios e do treino Pull. O histórico e os recordes continuam guardados, e você pode restaurar em Exercícios › Meus.")
        #expect(ExerciseRemovalText.message(archives: true, workoutNames: ["Push", "Pull"]) == "Ele sai da lista de exercícios e de 2 treinos (Push e Pull). O histórico e os recordes continuam guardados, e você pode restaurar em Exercícios › Meus.")
    }

    @Test("Deleting says the workouts it leaves, or that it is in none, and that it cannot be undone")
    func delete() {
        #expect(ExerciseRemovalText.title(name: "Puxada", archives: false) == "Apagar “Puxada”?")
        #expect(ExerciseRemovalText.action(archives: false) == "Apagar exercício")
        #expect(ExerciseRemovalText.message(archives: false, workoutNames: []) == "Ele não está em nenhum treino e ainda não tem histórico. Não dá para desfazer.")
        #expect(ExerciseRemovalText.message(archives: false, workoutNames: ["Pull"]) == "Ele sai do treino Pull e é apagado. Não dá para desfazer.")
        #expect(ExerciseRemovalText.message(archives: false, workoutNames: ["Push", "Pull", "Pernas"]) == "Ele sai de 3 treinos (Push, Pull e Pernas) e é apagado. Não dá para desfazer.")
    }
}
