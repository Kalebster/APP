import SwiftUI

/// An exercise of the Exercícios tab and of the exercise picker: the icon of its equipment (or the
/// initial of a custom exercise, which has none), the name, "Grupo · Foco" and the "MEU" badge of a custom
/// exercise. VoiceOver reads it as one item. In the Exercícios tab it opens nothing for now; in the picker
/// it shows whether it is chosen, or "NO TREINO" when the workout already has it.
struct ExerciseCard: View {
    /// What the card shows about choosing it.
    enum Selection: Equatable {
        /// Nothing: the Exercícios tab.
        case none
        /// The selection circle of the picker; a chosen card is outlined in blue on a blue fill.
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
                    // Two lines at the default text size; larger text takes the lines it needs.
                    .lineLimit(dynamicTypeSize > .large ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .scaledFont(11)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if item.isCustom {
                badge(String(localized: "MEU"))
            }
            switch selection {
            case .none:
                EmptyView()
            case .selectable(let isSelected):
                selectionCircle(isSelected: isSelected)
            case .inWorkout:
                badge(String(localized: "NO TREINO"))
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

    private func badge(_ text: String) -> some View {
        CapsuleBadge(
            text: text,
            weight: .bold,
            tracking: 0.8,
            padding: EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
        )
    }

    /// The 24-point circle of the picker: outlined, or blue with a check once chosen.
    private func selectionCircle(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.accentColor)
                Image(systemName: "checkmark")
                    .font(.system(size: circleSide * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(Theme.Colors.controlBorder, lineWidth: 1.5)
            }
        }
        .frame(width: circleSide, height: circleSide)
        .accessibilityHidden(true)
    }

    /// The equipment icon in light blue on the dark blue square, or the initial of the name.
    private var tile: some View {
        Group {
            if let equipment = item.equipment {
                EquipmentIcon(equipment: equipment)
                    .frame(width: iconSide, height: iconSide)
            } else {
                Text(verbatim: initial)
                    .scaledFont(15, weight: .bold)
            }
        }
        .foregroundStyle(Theme.Colors.lightAccent)
        .frame(width: tileSide, height: tileSide)
        .background(Theme.Colors.iconTileBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }

    private var initial: String {
        item.name.first.map { String($0).uppercased() } ?? ""
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

    /// "Supino Reto com Barra, Peito, Peitoral médio, Barra"; "Meu Supino, Peito, Meu exercício".
    private var accessibilityText: String {
        var parts = [item.name, String(localized: item.group.displayName)]
        if let focus = item.focus {
            parts.append(focus)
        }
        if let equipment = item.equipment {
            parts.append(String(localized: equipment.displayName))
        }
        if item.isCustom {
            parts.append(String(localized: "Meu exercício"))
        }
        if selection == .inWorkout {
            parts.append(String(localized: "Já está no treino"))
        }
        return parts.joined(separator: ", ")
    }
}

/// The card shown when nothing matches the search and the filters.
struct ExerciseEmptyCard: View {
    var identifier = "exercises.empty"

    var body: some View {
        VStack(spacing: 6) {
            Text("Nenhum exercício encontrado")
                .scaledFont(14, weight: .bold)
            Text("Tente outro nome ou outro filtro.")
                .scaledFont(12)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
