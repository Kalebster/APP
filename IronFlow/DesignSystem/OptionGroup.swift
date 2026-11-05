import SwiftUI

/// A block of options inside a sheet, as in the model: on the screen's background, corners of 14, a
/// line between the rows ("Opções do treino").
struct OptionGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Theme.Colors.rowSeparator
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                    row
                }
            }
        }
        .background(Theme.Colors.screenBackground, in: shape)
        .clipShape(shape)
    }
}

/// One row of an `OptionGroup`: its title (14 bold) and what it means (11, `secondaryText`, on as many
/// lines as it needs), with a control on the right: a `Toggle` in the accent color, or a link. 11 above
/// and below, 14 on the sides.
struct OptionRow<Accessory: View>: View {
    let title: Text
    let explanation: Text
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                title
                    .scaledFont(14, weight: .bold)
                    .foregroundStyle(Theme.Colors.brightText)
                explanation
                    .scaledFont(11, lineHeight: 1.35)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
    }
}

/// The iOS switch of an `OptionRow`: in the accent color, its label read by VoiceOver but not shown
/// (the row shows it).
struct OptionToggle: View {
    let label: Text
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            label
        }
        .labelsHidden()
        .tint(Color.accentColor)
    }
}
