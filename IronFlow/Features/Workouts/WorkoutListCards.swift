import SwiftUI

/// A workout in the "Meus treinos" grid: name, what it holds, a start button (▶) and an options menu
/// (⋮). The card opens the workout's editor; the other two controls sit over it, not inside its button,
/// so each one is its own accessibility element.
struct WorkoutGridCard: View {
    let workout: Workout
    let onOpen: @MainActor () -> Void
    let onStart: @MainActor () -> Void
    let onRename: @MainActor () -> Void
    let onDelete: @MainActor () -> Void

    var body: some View {
        let exerciseCount = workout.exercises.count

        ZStack {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 6) {
                    // Two lines are always reserved, so the cards of a row have the same height.
                    Text(workout.name)
                        .font(.headline)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                        .padding(.trailing, 20)
                    Text(WorkoutListSummary.cardSummary(for: workout))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    // The room of the start button, which sits over the bottom corner.
                    Color.clear.frame(height: 34)
                }
                .cardStyle()
                .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workouts.card")
        }
        .overlay(alignment: .topTrailing) {
            optionsMenu
        }
        .overlay(alignment: .bottomTrailing) {
            startButton(isEnabled: exerciseCount > 0)
        }
        .accessibilityElement(children: .contain)
    }

    /// The ⋮ menu: rename and delete.
    private var optionsMenu: some View {
        Menu {
            Button("Renomear", systemImage: "pencil", action: onRename)
            Button("Excluir", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.body.weight(.bold))
                // A fixed gray, so the accent color of the menu does not tint the dots.
                .foregroundStyle(Color.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .padding([.top, .trailing], 5)
        .accessibilityLabel(Text("Opções de \(workout.name)"))
        .accessibilityIdentifier("workouts.menu")
    }

    /// The ▶ button: starts a session of the workout. Unavailable while the workout has no exercises.
    private func startButton(isEnabled: Bool) -> some View {
        Button(action: onStart) {
            Image(systemName: "play.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        // The circle is 5 points inside its 44-point touch area; it sits 16 points from the card's edges.
        .padding([.bottom, .trailing], 11)
        .accessibilityLabel(Text("Iniciar \(workout.name)"))
        .accessibilityIdentifier("workouts.start")
    }
}

/// The "Treino livre" card: starts a session without a planned workout.
struct FreeWorkoutCard: View {
    let onStart: @MainActor () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Treino livre")
                        .font(.headline)
                    Text("Escolha exercícios na hora e registre suas séries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .cardStyle()
            .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workouts.free")
    }
}

/// A recent session: its name, a clock with the date, the time it started and its duration, and a
/// chevron. Read as one sentence by VoiceOver.
struct RecentSessionRow: View {
    let session: Session

    var body: some View {
        let name = SessionFormatting.name(session.workoutNameSnapshot)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(SessionFormatting.recentText(startedAt: session.startedAt, duration: session.duration))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(SessionFormatting.recentAccessibilityText(
            name: name,
            startedAt: session.startedAt,
            duration: session.duration
        )))
        .accessibilityHint(Text("Abre o detalhe do treino."))
    }
}

/// Takes the place of the grid when there are no workouts.
struct EmptyWorkoutsCard: View {
    let onCreate: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Nenhum treino ainda")
                .font(.headline)
            Text("Seus treinos aparecerão aqui.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Criar treino", action: onCreate)
                .buttonStyle(.bordered)
                .padding(.top, 4)
                .accessibilityIdentifier("workouts.empty.create")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workouts.empty")
    }
}
