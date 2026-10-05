import SwiftUI

/// The app's main navigation: four tabs.
///
/// Each tab currently shows only an empty-state placeholder. The real screens
/// replace these placeholders in later stages.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Início", systemImage: "house") {
                NavigationStack {
                    ContentUnavailableView(
                        "Iron Flow",
                        systemImage: "house",
                        description: Text("Nada por aqui ainda.")
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("tab.home.root")
                    .navigationTitle("Início")
                }
            }

            Tab("Treinos", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    ContentUnavailableView(
                        "Nenhum treino ainda",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Seus treinos aparecerão aqui.")
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("tab.workouts.root")
                    .navigationTitle("Treinos")
                }
            }

            Tab("Exercícios", systemImage: "dumbbell") {
                NavigationStack {
                    ContentUnavailableView(
                        "Nenhum exercício ainda",
                        systemImage: "dumbbell",
                        description: Text("A biblioteca de exercícios aparecerá aqui.")
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("tab.exercises.root")
                    .navigationTitle("Exercícios")
                }
            }

            Tab("Histórico", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    ContentUnavailableView(
                        "Nenhum treino realizado",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Seus treinos concluídos aparecerão aqui.")
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("tab.history.root")
                    .navigationTitle("Histórico")
                }
            }
        }
    }
}

#Preview {
    RootView()
}
