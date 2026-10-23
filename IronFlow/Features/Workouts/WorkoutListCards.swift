import SwiftUI

/// A workout in the "Meus treinos" grid: name, what it holds and its muscle groups, a start button (▶)
/// and an options menu (⋮) with "Editar treino", "Renomear" and "Excluir". The workout planned for today is highlighted, with "HOJE". The card opens
/// the workout's editor; the other two controls sit over it, not inside its button, so each one is its
/// own accessibility element. The card fills the height it is given, so the cards of a row match.
struct WorkoutGridCard: View {
    let workout: Workout
    /// Planned for today in the weekly plan.
    let isToday: Bool
    let onOpen: @MainActor () -> Void
    let onEdit: @MainActor () -> Void
    let onStart: @MainActor () -> Void
    let onRename: @MainActor () -> Void
    let onDelete: @MainActor () -> Void

    /// The card's minimum height, 128 points at the default text size, without its padding.
    @ScaledMetric(relativeTo: .body) private var minContentHeight: CGFloat = 106

    var body: some View {
        let summary = WorkoutListSummary.cardSummary(for: workout)
        let groups = WorkoutListSummary.muscleGroupsText(WorkoutListSummary.muscleGroups(of: workout))

        ZStack {
            Button(action: onOpen) {
                let content = VStack(alignment: .leading, spacing: 6) {
                    if isToday {
                        CapsuleBadge(
                            text: String(localized: "HOJE"),
                            weight: .bold,
                            tracking: 0.9,
                            padding: EdgeInsets(top: 3, leading: 7, bottom: 3, trailing: 7)
                        )
                    }
                    Text(workout.name)
                        .scaledFont(15, weight: .heavy)
                        .foregroundStyle(isToday ? Theme.Colors.highlightText : Color.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        // The room of the ⋮ menu, which sits over the top corner.
                        .padding(.trailing, 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary)
                        if !groups.isEmpty {
                            Text(verbatim: groups)
                        }
                    }
                    .scaledFont(11)
                    .foregroundStyle(isToday ? Theme.Colors.highlightSecondaryText : Color.secondary)
                    .multilineTextAlignment(.leading)
                    // The room of the start button, which sits over the bottom corner.
                    Color.clear.frame(height: 34)
                }
                .frame(maxWidth: .infinity, minHeight: minContentHeight, maxHeight: .infinity, alignment: .topLeading)

                let padding = EdgeInsets(top: 12, leading: 12, bottom: 10, trailing: 9)
                if isToday {
                    content.highlightStyle(padding: padding, cornerRadius: 17)
                } else {
                    content.cardStyle(padding: padding, cornerRadius: 17)
                }
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .accessibilityLabel(Text(verbatim: accessibilityText(summary: summary, groups: groups)))
            .accessibilityIdentifier("workouts.card")
        }
        .overlay(alignment: .topTrailing) {
            optionsMenu
        }
        .overlay(alignment: .bottomTrailing) {
            startButton(isEnabled: !workout.exercises.isEmpty)
        }
        .accessibilityElement(children: .contain)
    }

    /// "Push, programado para hoje, 4 exercícios · 12 séries, Peito · Ombros · Tríceps".
    private func accessibilityText(summary: String, groups: String) -> String {
        var parts = [workout.name]
        if isToday {
            parts.append(String(localized: "programado para hoje"))
        }
        parts.append(summary)
        if !groups.isEmpty {
            parts.append(groups)
        }
        return parts.joined(separator: ", ")
    }

    /// The ⋮ menu: edit, rename and delete. 27 points of dots in a 44-point touch area.
    private var optionsMenu: some View {
        Menu {
            Button("Editar treino", systemImage: "slider.horizontal.3", action: onEdit)
            Button("Renomear", systemImage: "pencil", action: onRename)
            Button("Excluir", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .scaledFont(15, weight: .bold)
                // A fixed gray, so the accent color of the menu does not tint the dots.
                .foregroundStyle(Color.secondary)
                .frame(width: 27, height: 27)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .padding(.top, 2)
        .accessibilityLabel(Text("Opções de \(workout.name)"))
        .accessibilityIdentifier("workouts.menu")
    }

    /// The ▶ button: starts a session of the workout. Unavailable while the workout has no exercises.
    /// White on today's workout, accent on the others.
    private func startButton(isEnabled: Bool) -> some View {
        Button(action: onStart) {
            Image(systemName: "play.fill")
                .scaledFont(13, weight: .bold)
                .foregroundStyle(isToday ? Theme.Colors.screenBackground : Color.white)
                .frame(width: 34, height: 34)
                .background(isToday ? Color.white : Color.accentColor, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        // The circle is 5 points inside its 44-point touch area; it sits 9 and 10 points from the card's edges.
        .padding(.bottom, 5)
        .padding(.trailing, 4)
        .accessibilityLabel(Text("Iniciar \(workout.name)"))
        .accessibilityIdentifier("workouts.start")
    }
}

/// The "Treino livre" row: starts a session without a planned workout.
struct FreeWorkoutCard: View {
    let onStart: @MainActor () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 12) {
                IconTile(systemImage: "bolt.fill", side: 36, cornerRadius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Treino livre")
                        .scaledFont(14, weight: .bold)
                    Text("Escolha os exercícios na hora e registre suas séries")
                        .scaledFont(12)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .scaledFont(12, weight: .semibold)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .cardStyle(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 14), cornerRadius: 17)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workouts.free")
    }
}

/// A recent session, a row of the "Treinos recentes" card: its name, the day and time it started, its
/// duration and a chevron. Read as one sentence by VoiceOver.
struct RecentSessionRow: View {
    let session: Session

    var body: some View {
        let name = SessionFormatting.name(session.workoutNameSnapshot)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .scaledFont(14, weight: .bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(verbatim: "\(SessionFormatting.weekdayDateText(session.startedAt)) · \(SessionFormatting.timeText(session.startedAt))")
                    .scaledFont(12)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let duration = session.duration {
                Text(verbatim: SessionFormatting.compactDurationText(duration))
                    .scaledFont(12, weight: .semibold)
                    .foregroundStyle(Theme.Colors.mediumText)
            }
            Image(systemName: "chevron.right")
                .scaledFont(12, weight: .semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
            IconTile(systemImage: "list.bullet.rectangle", side: 36, cornerRadius: 10)
            Text("Nenhum treino ainda")
                .scaledFont(14, weight: .bold)
            Text("Seus treinos aparecerão aqui.")
                .scaledFont(12)
                .foregroundStyle(.secondary)
            Button(action: onCreate) {
                Text("Criar treino")
                    .scaledFont(13, weight: .bold)
                    .foregroundStyle(Theme.Colors.lightAccent)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 34)
                    .overlay(Capsule().strokeBorder(Theme.Colors.lightAccent, lineWidth: 1))
                    // 5 more points above and below respond to touches, for a 44-point touch area.
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workouts.empty.create")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .cardStyle(padding: EdgeInsets(top: 16, leading: 12, bottom: 12, trailing: 12), cornerRadius: 17)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workouts.empty")
    }
}
