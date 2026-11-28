import SwiftUI

extension EnvironmentValues {
    /// Opens the editor of a workout in the Treinos tab, from any screen: "Criar treino novo" of "Adicionar a
    /// um treino". Set by `RootView`; does nothing elsewhere (previews, tests of a screen alone).
    @Entry var openWorkoutEditor: @MainActor @Sendable (Workout) -> Void = { _ in }
}
