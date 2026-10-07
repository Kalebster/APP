import SwiftData
import SwiftUI

/// The app's main navigation: five tabs.
///
/// Tabs without a real screen yet show a simple placeholder, replaced in later stages.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Início", systemImage: "house") {
                NavigationStack {
                    HomeView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.home.root")
                        .navigationTitle("Início")
                }
            }

            Tab("Treinos", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    WorkoutListView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.workouts.root")
                        .navigationTitle("Treinos")
                }
            }

            Tab("Exercícios", systemImage: "dumbbell") {
                NavigationStack {
                    ExerciseListView()
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

            Tab("Ajustes", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tab.settings.root")
                        .navigationTitle("Ajustes")
                }
            }
        }
    }
}

#Preview {
    if let container = try? ModelContainerFactory.makeInMemory() {
        let _ = try? ExerciseLibrarySeeder(context: container.mainContext).seed()
        RootView()
            .modelContainer(container)
    }
}
