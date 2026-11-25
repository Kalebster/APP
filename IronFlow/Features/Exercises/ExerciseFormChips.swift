import SwiftUI

/// A choice of the exercise form, as in the prototype: a capsule 36 points tall, dark with a 1-point border
/// and the text in `mediumText`; chosen, white with black text. A muscle of the other list (`isBlocked`) is
/// dashed, without fill, in gray, with "principal" or "secondary" after its name, and cannot be chosen.
/// The touch area is 44 points tall.
struct FormChip: View {
    let title: String
    /// The equipment's icon before the title; `nil` with `showsIcon` is the icon of "Outro".
    var icon: Equipment?
    var showsIcon = false
    let isOn: Bool
    var isBlocked = false
    /// "principal" or "secundário" after the name of a blocked muscle.
    var note: String?
    /// 14 in the form, 13 in the muscle sheets.
    var fontSize: CGFloat = 14
    /// 14 in the form, 12 in the muscle sheets.
    var horizontalPadding: CGFloat = 14
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 15

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsIcon {
                    EquipmentIcon(equipment: icon)
                        .frame(width: iconSide, height: iconSide)
                        .foregroundStyle(isOn ? Theme.Colors.primaryButtonText : Theme.Colors.lightAccent)
                }
                Text(verbatim: title)
                    .scaledFont(fontSize, weight: .semibold)
                    .lineLimit(1)
                if let note {
                    Text(verbatim: note)
                        .scaledFont(11, weight: .semibold)
                        .foregroundStyle(Theme.Colors.dimText)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background(background, in: Capsule())
            .overlay {
                if isBlocked {
                    Capsule().strokeBorder(Theme.Colors.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                } else {
                    Capsule().strokeBorder(isOn ? Theme.Colors.primaryButton : Theme.Colors.cardBorder, lineWidth: 1)
                }
            }
            // 44 points of touch without taking more room.
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .padding(.vertical, -4)
        }
        .buttonStyle(.plain)
        .disabled(isBlocked)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var foreground: Color {
        if isBlocked { return Theme.Colors.secondaryText }
        return isOn ? Theme.Colors.primaryButtonText : Theme.Colors.mediumText
    }

    private var background: Color {
        if isBlocked { return .clear }
        return isOn ? Theme.Colors.primaryButton : Theme.Colors.cardBackground
    }
}

/// One chip of a section of the exercise form.
struct FormChipOption: Identifiable {
    /// The storage key of what it chooses, the end of its accessibility identifier.
    let id: String
    let title: String
    var icon: Equipment?
    var showsIcon = false
    let isOn: Bool
    let action: () -> Void
}

/// A section of the exercise form with one choice among chips: its title (and a link on its right, such
/// as "O que é cada tipo") and the chips, wrapping with 8 points between them.
struct ExerciseFormChips<Accessory: View>: View {
    let title: LocalizedStringKey
    let identifier: String
    let options: [FormChipOption]
    let accessory: Accessory

    init(title: LocalizedStringKey, identifier: String, options: [FormChipOption], @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.identifier = identifier
        self.options = options
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ExerciseFormSectionTitle(title)
                Spacer(minLength: 0)
                accessory
            }
            FlowLayout(spacing: 8) {
                ForEach(options) { option in
                    FormChip(title: option.title, icon: option.icon, showsIcon: option.showsIcon, isOn: option.isOn, action: option.action)
                        .accessibilityIdentifier("\(identifier).\(option.id)")
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

extension ExerciseFormChips where Accessory == EmptyView {
    init(title: LocalizedStringKey, identifier: String, options: [FormChipOption]) {
        self.init(title: title, identifier: identifier, options: options) {
            EmptyView()
        }
    }
}
