import SwiftData
import SwiftUI

/// The Workouts tab: one card per planned workout. Creating a workout opens its editor;
/// "Iniciar" starts a session from it.
struct WorkoutListView: View {
    /// Opens the session in progress over the tabs.
    let openSession: @MainActor () -> Void

    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    @Environment(\.modelContext) private var context
    @State private var isCreating = false
    /// Workout created in the name sheet, opened once the sheet is dismissed.
    @State private var createdWorkout: Workout?
    @State private var openedWorkout: Workout?
    @State private var isSessionInProgress = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Metrics.cardSpacing) {
                ForEach(workouts) { workout in
                    WorkoutCard(workout: workout) {
                        openedWorkout = workout
                    } onStart: {
                        start(workout)
                    }
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .overlay {
            if workouts.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum treino ainda", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Seus treinos aparecerão aqui.")
                } actions: {
                    Button("Criar treino") {
                        isCreating = true
                    }
                    .accessibilityIdentifier("workouts.empty.create")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("workouts.empty")
            }
        }
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Label("Criar treino", systemImage: "plus")
                }
                .accessibilityIdentifier("workouts.add")
            }
        }
        .sheet(isPresented: $isCreating, onDismiss: openCreatedWorkout) {
            WorkoutNameSheet(title: "Novo treino") { name in
                createdWorkout = try WorkoutService(context: context).createWorkout(name: name)
            }
        }
        .navigationDestination(item: $openedWorkout) { workout in
            WorkoutEditorView(workout: workout)
        }
        .alert("Você já tem um treino em andamento.", isPresented: $isSessionInProgress) {
            Button("Continuar treino atual", action: openSession)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Conclua ou descarte o treino atual antes de iniciar outro.")
        }
        .errorAlert($errorMessage)
    }

    private func start(_ workout: Workout) {
        do {
            try SessionService(context: context).startSession(from: workout)
            openSession()
        } catch SessionError.activeSessionExists {
            isSessionInProgress = true
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func openCreatedWorkout() {
        guard let createdWorkout else { return }
        self.createdWorkout = nil
        openedWorkout = createdWorkout
    }
}

/// A workout card: name, number of exercises and a disclosure chevron (opens the editor), and
/// "Iniciar", which is unavailable while the workout has no exercises.
private struct WorkoutCard: View {
    let workout: Workout
    let onOpen: @MainActor () -> Void
    let onStart: @MainActor () -> Void

    var body: some View {
        let count = workout.exercises.count
        VStack(spacing: 12) {
            Button(action: onOpen) {
                summary(count: count)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workouts.card")

            Button(action: onStart) {
                Label("Iniciar", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(count == 0)
            .accessibilityIdentifier("workouts.start")
        }
        .cardStyle()
    }

    private func summary(count: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline)
                    .lineLimit(2)
                Group {
                    if count == 0 {
                        Text("Nenhum exercício")
                    } else {
                        Text("\(count) exercícios")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
