import SwiftUI

/// An exercise of the Exercícios tab and of the exercise picker: the icon of its equipment (the 4 squares
/// of "Outro" for an exercise of the user's own without one), the name, "Grupo · Foco" (only the group for
/// an exercise of the user's own) and its badge, "MEU" or "ARQUIVADO", with the name of an archived one in
/// a softer white. VoiceOver reads it as one item. In the Exercícios tab it ends with the › of the row that
/// opens the exercise screen; in the picker it shows whether it is chosen, or "NO TREINO" when the
/// workout already has it.
struct ExerciseCard: View {
    /// What the card shows about choosing it.
    enum Selection: Equatable {
        /// Nothing: the Exercícios tab, where the row opens the exercise (the ›).
        case none
        /// The selection circle of the picker; a chosen card is outlined in blue on a lighter fill.
        case selectable(isSelected: Bool)
        /// Already in the workout: "NO TREINO", at half opacity.
        case inWorkout
    }

    let item: ExerciseCatalog.Item
    var selection: Selection = .none
    var identifier = "exercises.card"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSide: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 19
    @ScaledMetric(relativeTo: .body) private var circleSide: CGFloat = 24

    var body: some View {
        HStack(spacing: 12) {
            tile
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name)
                    .scaledFont(14, weight: .bold)
                    .foregroundStyle(item.isArchived ? AnyShapeStyle(Theme.Colors.mediumText) : AnyShapeStyle(.primary))
                    // Two lines at the default text size; larger text takes the lines it needs.
                    .lineLimit(dynamicTypeSize > .large ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .scaledFont(11)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if item.isCustom {
                badge(item.isArchived ? String(localized: "ARQUIVADO") : String(localized: "MEU"))
            }
            switch selection {
            case .none:
                // The › of the row, 13 points, in the prototype's gray (#7D7D83).
                AppIcon(.chevronRightList, size: 13)
                    .foregroundStyle(Theme.Colors.futureDayText)
            case .selectable(let isSelected):
                selectionCircle(isSelected: isSelected)
            case .inWorkout:
                // Gray on gray, as in the model: it is there already, nothing to choose.
                badge(String(localized: "NO TREINO"), foreground: Theme.Colors.mediumText, background: Theme.Colors.unplannedDayBackground)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isSelected ? Theme.Colors.selectedCardBackground : Theme.Colors.cardBackground, in: shape)
        .overlay {
            if isSelected {
                shape.strokeBorder(Color.accentColor, lineWidth: 1)
            }
        }
        .opacity(selection == .inWorkout ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
    }

    private var isSelected: Bool {
        selection == .selectable(isSelected: true)
    }

    private func badge(
        _ text: String,
        foreground: Color = Theme.Colors.highlightText,
        background: Color = Theme.Colors.highlightBadge
    ) -> some View {
        CapsuleBadge(
            text: text,
            weight: .bold,
            tracking: 0.8,
            padding: EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8),
            foreground: foreground,
            background: background
        )
    }

    /// The 24-point circle of the picker: outlined, or blue with a check once chosen.
    private func selectionCircle(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.accentColor)
                AppIcon(.check, size: 12, relativeTo: .body)
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(Theme.Colors.dashedBorder, lineWidth: 1.5)
            }
        }
        .frame(width: circleSide, height: circleSide)
        .accessibilityHidden(true)
    }

    /// The equipment icon (or "Outro") in light gray on the dark gray square.
    private var tile: some View {
        EquipmentIcon(equipment: item.equipment)
            .frame(width: iconSide, height: iconSide)
            .foregroundStyle(Theme.Colors.lightAccent)
            .frame(width: tileSide, height: tileSide)
            .background(Theme.Colors.iconTileBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }

    /// "Peito" in gray and " · Peitoral médio" darker; only the group when there is no focus.
    private var detail: AttributedString {
        var text = AttributedString(String(localized: item.group.displayName))
        text.foregroundColor = Theme.Colors.secondaryText
        if let focus = item.focus {
            var focusText = AttributedString(" · \(focus)")
            focusText.foregroundColor = Theme.Colors.dimText
            text += focusText
        }
        return text
    }

    /// "Supino Reto com Barra, Peito, Peitoral médio, Barra"; "Meu Supino, Peito, Outro, Meu exercício";
    /// "Puxada, Dorsais, Máquina, Exercício arquivado".
    private var accessibilityText: String {
        var parts = [item.name, String(localized: item.group.displayName)]
        if let focus = item.focus {
            parts.append(focus)
        }
        if let equipment = item.equipment {
            parts.append(String(localized: equipment.displayName))
        } else if item.isCustom {
            parts.append(String(localized: "Outro"))
        }
        if item.isCustom {
            parts.append(item.isArchived ? String(localized: "Exercício arquivado") : String(localized: "Meu exercício"))
        }
        if selection == .inWorkout {
            parts.append(String(localized: "Já está no treino"))
        }
        return parts.joined(separator: ", ")
    }
}

/// The card shown when nothing matches the search and the filters, with "+ Criar "texto"" when there is
/// a search: it opens the form of a new exercise with that name.
struct ExerciseEmptyCard: View {
    var identifier = "exercises.empty"
    /// Between the two lines: 8 in the Exercícios tab, 6 in the exercise picker, as in the prototype.
    var spacing: CGFloat = 6
    /// The search, without the spaces around it; empty without a search.
    var search = ""
    var onCreate: (@MainActor () -> Void)?

    @ScaledMetric(relativeTo: .caption) private var buttonHeight: CGFloat = 34

    var body: some View {
        VStack(spacing: spacing) {
            // The message is read as one; "+ Criar" stays a button of its own.
            VStack(spacing: spacing) {
                Text("Nenhum exercício encontrado")
                    .scaledFont(14, weight: .bold)
                Text("Tente outro nome ou outro filtro.")
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Nenhum exercício encontrado. Tente outro nome ou outro filtro."))
            .accessibilityIdentifier(identifier)
            if !search.isEmpty, let onCreate {
                Button(action: onCreate) {
                    Text(verbatim: String(localized: "+ Criar \"\(search)\""))
                        .scaledFont(12, weight: .bold)
                        .foregroundStyle(Theme.Colors.lightAccent)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(minHeight: buttonHeight)
                        .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1))
                        // 5 more points above and below respond to touches, for a 44-point touch area.
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .padding(.vertical, -5)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityIdentifier("\(identifier).create")
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
