import SwiftUI

/// An exercise of the session, as rows of the session list drawn as one card: its name, muscle group
/// and targets with the ⋯ menu, the set columns, its sets and "+ Adicionar série". Each set is its own
/// row, so it can be swiped to be removed. A finished exercise closes into one row; tapping it opens
/// and closes it.
struct SessionExerciseCard: View {
    let performed: SessionExercise
    let sets: [SetLog]
    /// The sets done the last time, the first done set going with set 1.
    let previousSets: [PreviousSet]
    let isCurrent: Bool
    let currentSetID: UUID?
    let isFinished: Bool
    let isClosed: Bool
    let focusedField: FocusState<SetField?>.Binding
    let draft: @MainActor (SetLog) -> Binding<SetDraft>
    let onToggle: @MainActor (SetLog, SetSuggestion) -> Void
    let onAddSet: @MainActor () -> Void
    let onRemoveSet: @MainActor (SetLog) -> Void
    let onRemoveExercise: @MainActor () -> Void
    let onOpenOrClose: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var menuSide: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var doneSide: CGFloat = 24

    var body: some View {
        // A group, so the list takes each of these as its own row.
        Group {
            if isClosed {
                closedRow
                    .sessionCardRow(.single, isCurrent: false)
            } else {
                titleRow
                    .sessionCardRow(.top, isCurrent: isCurrent)
                if !sets.isEmpty {
                    SessionSetColumns()
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        .sessionCardRow(.middle, isCurrent: isCurrent)
                }
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, log in
                    let previous = previousSets.indices.contains(index) ? previousSets[index] : nil
                    let suggestion = LastPerformance.suggestion(
                        previous: previous,
                        targetWeightKg: log.targetWeightKg,
                        targetRepsMin: log.targetRepsMin,
                        targetRepsMax: log.targetRepsMax
                    )
                    SessionSetRow(
                        number: index + 1,
                        log: log,
                        previous: previous,
                        suggestion: suggestion,
                        isCurrent: log.id == currentSetID,
                        draft: draft(log),
                        focusedField: focusedField
                    ) {
                        onToggle(log, suggestion)
                    }
                    .padding(.vertical, 2)
                    .sessionCardRow(.middle, isCurrent: isCurrent)
                    // Removing takes a second tap, on the button the swipe shows.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Remover") {
                            onRemoveSet(log)
                        }
                        .tint(.red)
                        .accessibilityIdentifier("session.set.remove")
                    }
                }
                addSetRow
                    .sessionCardRow(.bottom, isCurrent: isCurrent)
            }
        }
    }

    /// "Peito · meta 8–12 reps": the muscle group as performed, and the targets of the sets.
    private var subtitle: String {
        [String(localized: performed.muscleGroupSnapshot.displayName), SessionProgress.targetText(of: sets)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(performed.exerciseNameSnapshot)
                    .scaledFont(14, weight: .heavy)
                Text(verbatim: subtitle)
                    .scaledFont(10)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if isFinished {
                // A finished exercise opened again closes from here.
                Button(action: onOpenOrClose) {
                    roundIcon("chevron.up")
                }
                .buttonStyle(.plain)
                .padding(min(0, (menuSide - 44) / 2))
                .accessibilityLabel(Text("Fechar \(performed.exerciseNameSnapshot)"))
                .accessibilityIdentifier("session.exercise.close")
            }

            Menu {
                Button("Remover exercício", systemImage: "trash", role: .destructive, action: onRemoveExercise)
            } label: {
                roundIcon("ellipsis")
            }
            .padding(min(0, (menuSide - 44) / 2))
            .accessibilityLabel(Text("Opções de \(performed.exerciseNameSnapshot)"))
            .accessibilityIdentifier("session.exercise.menu")
        }
        .padding(.top, 10)
        .padding(.leading, SetRowMetrics.innerPadding)
    }

    /// An icon in a 26-point area that answers on 44 points.
    private func roundIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .scaledFont(13, weight: .bold)
            .foregroundStyle(.secondary)
            .frame(width: menuSide, height: menuSide)
            .frame(width: max(44, menuSide), height: max(44, menuSide))
            .contentShape(Rectangle())
    }

    private var addSetRow: some View {
        Button(action: onAddSet) {
            Label("Adicionar série", systemImage: "plus")
                .scaledFont(12, weight: .semibold)
                .foregroundStyle(Theme.Colors.lightAccent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, SetRowMetrics.innerPadding)
        .padding(.bottom, SessionCardSegment.gap)
        .accessibilityIdentifier("session.addSet")
    }

    /// A finished exercise in one row: the check, its name, what it did, "4/4" and the chevron.
    private var closedRow: some View {
        let done = sets.filter(\.isCompleted).count
        let summary = SessionProgress.doneSummary(of: sets)
        let doneText = sets.count == 1
            ? String(localized: "\(done) de 1 série")
            : String(localized: "\(done) de \(sets.count) séries")
        let group = String(localized: performed.muscleGroupSnapshot.displayName)
        return Button(action: onOpenOrClose) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .scaledFont(11, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(width: doneSide, height: doneSide)
                    .background(Color.accentColor, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(performed.exerciseNameSnapshot)
                        .scaledFont(13, weight: .bold)
                        .foregroundStyle(.primary)
                    Text(verbatim: "\(group) · \(summary)")
                        .scaledFont(10)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: "\(done)/\(sets.count)")
                    .scaledFont(11, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.mediumText)
                Image(systemName: "chevron.down")
                    .scaledFont(11, weight: .semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, SetRowMetrics.innerPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, SessionCardSegment.gap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(performed.exerciseNameSnapshot), concluído: \(doneText), \(summary)"))
        .accessibilityHint(Text("Mostra as séries."))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("session.exercise.done")
    }
}

/// Where a row sits in its exercise's card, so the rows of an exercise draw one card together.
enum SessionCardRowPosition {
    case top, middle, bottom, single
}

/// The part of an exercise's card behind one row: the card fill with its corners at the top or the
/// bottom, the outline of the current exercise on the card's outer edges only, and after the last row
/// the gap to the next card.
struct SessionCardSegment: View {
    let position: SessionCardRowPosition
    let isCurrent: Bool

    static let cornerRadius: CGFloat = 15
    /// The space between two cards, below each card's last row.
    static let gap: CGFloat = 14

    var body: some View {
        let isTop = position == .top || position == .single
        let isBottom = position == .bottom || position == .single
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isTop ? Self.cornerRadius : 0,
            bottomLeadingRadius: isBottom ? Self.cornerRadius : 0,
            bottomTrailingRadius: isBottom ? Self.cornerRadius : 0,
            topTrailingRadius: isTop ? Self.cornerRadius : 0,
            style: .continuous
        )
        shape
            .fill(Theme.Colors.cardBackground)
            .overlay {
                if isCurrent {
                    // The edges shared with the rows above and below are pushed out and clipped away.
                    shape
                        .strokeBorder(Theme.Colors.highlightBadge, lineWidth: 1)
                        .padding(.top, isTop ? 0 : -2)
                        .padding(.bottom, isBottom ? 0 : -2)
                }
            }
            .clipped()
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, isBottom ? Self.gap : 0)
    }
}

extension View {
    /// A row of an exercise's card in the session list: the card's margins, no separator, and the part
    /// of the card behind it.
    func sessionCardRow(_ position: SessionCardRowPosition, isCurrent: Bool) -> some View {
        listRowInsets(EdgeInsets(
            top: 0,
            leading: Theme.Metrics.screenPadding + 8,
            bottom: 0,
            trailing: Theme.Metrics.screenPadding + 8
        ))
        .listRowSeparator(.hidden)
        .listRowBackground(SessionCardSegment(position: position, isCurrent: isCurrent))
    }
}
