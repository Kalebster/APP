import SwiftUI

/// Messages shown to the user for service errors.
enum UserFacingError {
    static func message(for error: any Error) -> String {
        switch error {
        case let error as ValidationError:
            message(for: error)
        case let error as WorkoutError:
            message(for: error)
        case is SaveError:
            String(localized: "Não foi possível salvar. Nenhuma alteração foi feita.")
        default:
            String(localized: "Algo deu errado. Tente novamente.")
        }
    }

    private static func message(for error: ValidationError) -> String {
        switch error {
        case .emptyName:
            String(localized: "Informe um nome.")
        case .nameTooLong:
            String(localized: "O nome pode ter no máximo \(Validation.maxNameLength) caracteres.")
        case .duplicateExerciseName:
            String(localized: "Já existe um exercício com esse nome.")
        case .invalidRepsMin:
            String(localized: "As repetições mínimas devem ser maiores que zero.")
        case .invalidRepsMax:
            String(localized: "As repetições máximas devem ser maiores que zero.")
        case .repsMinGreaterThanMax:
            String(localized: "O mínimo de repetições não pode ser maior que o máximo.")
        case .negativeWeight:
            String(localized: "A carga não pode ser negativa.")
        case .invalidWeight:
            String(localized: "Carga inválida.")
        case .tooManyDecimals:
            String(localized: "A carga pode ter no máximo duas casas decimais.")
        case .invalidReps:
            String(localized: "As repetições devem ser maiores que zero.")
        }
    }

    private static func message(for error: WorkoutError) -> String {
        switch error {
        case .exerciseArchived:
            String(localized: "Este exercício está arquivado e não pode ser adicionado.")
        case .exerciseAlreadyInWorkout:
            String(localized: "Este exercício já está no treino.")
        case .lastPlannedSet:
            String(localized: "O exercício precisa ter pelo menos uma série.")
        case .workoutHasNoExercises:
            String(localized: "O treino não tem exercícios.")
        case .exerciseMissing:
            String(localized: "Um exercício deste treino não existe mais.")
        case .plannedSetsMissing:
            String(localized: "Um exercício deste treino está sem séries.")
        case .invalidPosition:
            String(localized: "Não foi possível mover o exercício.")
        }
    }
}

extension View {
    /// Shows `message` in an alert while it is not `nil`; dismissing clears it.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Não foi possível concluir",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
