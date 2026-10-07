import SwiftUI

/// The Ajustes tab. Its options come in their own step.
struct SettingsView: View {
    var body: some View {
        ContentUnavailableView(
            "Ajustes",
            systemImage: "gearshape",
            description: Text("As opções do app chegarão em breve.")
        )
        .screenBackground()
    }
}
