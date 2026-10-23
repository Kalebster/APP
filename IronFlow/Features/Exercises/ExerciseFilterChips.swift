import SwiftUI

/// A muscle group filter of the Exercícios tab ("Todos", "Meus", "Peito"...): a capsule on the card fill
/// with the card border; the selected one is white with dark text. It answers on 44 points.
struct GroupFilterChip: View {
    let title: LocalizedStringResource
    let isSelected: Bool
    /// The height of the capsule; the touch area grows above and below it to 44 points.
    let height: CGFloat
    let identifier: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .scaledFont(13, weight: .semibold)
                .foregroundStyle(isSelected ? Theme.Colors.screenBackground : Theme.Colors.mediumText)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .frame(minHeight: height)
                .background(isSelected ? Color.white : Theme.Colors.cardBackground, in: Capsule())
                .overlay {
                    if !isSelected {
                        Capsule().strokeBorder(Theme.Colors.cardBorder, lineWidth: 1)
                    }
                }
                .padding(.vertical, ChipMetrics.touchExtra(for: height))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

/// An equipment filter: the icon and the name in an outlined capsule; the selected one is filled with
/// the highlight. It answers on 44 points.
struct EquipmentFilterChip: View {
    let equipment: Equipment
    let isSelected: Bool
    let height: CGFloat
    let iconSide: CGFloat
    let identifier: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                EquipmentIcon(equipment: equipment)
                    .frame(width: iconSide, height: iconSide)
                    .foregroundStyle(isSelected ? Theme.Colors.highlightText : Theme.Colors.lightAccent)
                Text(equipment.displayName)
                    .scaledFont(12, weight: .semibold)
                    .foregroundStyle(isSelected ? Theme.Colors.highlightText : Theme.Colors.mediumText)
                    .lineLimit(1)
            }
            .padding(.leading, 9)
            .padding(.trailing, 11)
            .frame(minHeight: height)
            .background(isSelected ? Theme.Colors.highlightBadge : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Theme.Colors.highlightLine : Theme.Colors.cardBorder, lineWidth: 1))
            .padding(.vertical, ChipMetrics.touchExtra(for: height))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

/// A row of filter chips that scrolls sideways from edge to edge of the screen, its first chip aligned
/// with the screen margin. The touch areas of the chips go beyond the row without taking room.
struct FilterChipRow<Content: View>: View {
    /// The height of the chips of the row.
    let chipHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                content()
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Theme.Metrics.screenPadding, for: .scrollContent)
        .padding(.vertical, -ChipMetrics.touchExtra(for: chipHeight))
    }
}

enum ChipMetrics {
    /// What a chip answers on above and below its capsule, for a touch area of 44 points.
    static func touchExtra(for height: CGFloat) -> CGFloat {
        max(0, 44 - height) / 2
    }
}
