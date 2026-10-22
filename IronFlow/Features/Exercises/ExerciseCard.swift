import SwiftUI

/// An exercise of the Exercícios tab: the icon of its equipment (or the initial of a custom exercise,
/// which has none), the name, "Grupo · Foco" and the "MEU" badge of a custom exercise. VoiceOver reads it
/// as one item. It opens nothing for now.
struct ExerciseCard: View {
    let item: ExerciseCatalog.Item

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSide: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 19

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
                CapsuleBadge(
                    text: String(localized: "MEU"),
                    weight: .bold,
                    tracking: 0.8,
                    padding: EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
        .accessibilityIdentifier("exercises.card")
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
        return parts.joined(separator: ", ")
    }
}

/// The card shown when nothing matches the search and the filters.
struct ExerciseEmptyCard: View {
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
        .accessibilityIdentifier("exercises.empty")
    }
}
