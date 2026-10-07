import Foundation
import Testing
@testable import IronFlow

struct UserFacingErrorTests {
    private struct UnknownError: Error {}

    @Test("Every validation and workout error has its own message")
    func distinctMessages() {
        let errors: [any Error] = [
            ValidationError.emptyName, ValidationError.nameTooLong, ValidationError.duplicateExerciseName,
            ValidationError.invalidRepsMin, ValidationError.invalidRepsMax, ValidationError.repsMinGreaterThanMax,
            ValidationError.negativeWeight, ValidationError.invalidWeight, ValidationError.tooManyDecimals,
            ValidationError.invalidReps, ValidationError.repsTooHigh, ValidationError.weightTooHigh,
            PlannedSetInputError.repsRequired, PlannedSetInputError.thousandsSeparator,
            WorkoutError.exerciseArchived, WorkoutError.exerciseAlreadyInWorkout, WorkoutError.lastPlannedSet,
            WorkoutError.workoutHasNoExercises, WorkoutError.exerciseMissing, WorkoutError.plannedSetsMissing,
            WorkoutError.invalidPosition,
        ]

        let messages = errors.map { UserFacingError.message(for: $0) }

        #expect(messages.allSatisfy { !$0.isEmpty })
        #expect(Set(messages).count == errors.count)
    }

    @Test("Specific messages for the errors the workout screens show")
    func workoutMessages() {
        #expect(UserFacingError.message(for: WorkoutError.exerciseAlreadyInWorkout) == "Este exercício já está no treino.")
        #expect(UserFacingError.message(for: ValidationError.nameTooLong) == "O nome pode ter no máximo 60 caracteres.")
        #expect(UserFacingError.message(for: ValidationError.repsTooHigh) == "As repetições podem ser no máximo 100.")
        #expect(UserFacingError.message(for: ValidationError.weightTooHigh) == "A carga pode ser no máximo 1.000 kg.")
        #expect(UserFacingError.message(for: PlannedSetInputError.repsRequired) == "Informe as repetições com números inteiros.")
        #expect(UserFacingError.message(for: PlannedSetInputError.thousandsSeparator) == "Para mil quilos, digite 1000. Use vírgula ou ponto só para casas decimais.")
    }

    @Test("Save failures and unknown errors get a generic message")
    func genericMessages() {
        let save = UserFacingError.message(for: SaveError.saveFailed("disk full"))
        let unknown = UserFacingError.message(for: UnknownError())

        #expect(save == "Não foi possível salvar. Nenhuma alteração foi feita.")
        #expect(unknown == "Algo deu errado. Tente novamente.")
    }
}
