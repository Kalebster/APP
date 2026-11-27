import SwiftUI

/// The rows of a base exercise, on its screen and in the choice sheet: EQUIPAMENTO and, when the base has
/// one, PEGADA or VARIAÇÃO. Buttons with text only, in fixed rows that wrap and never scroll: the order of
/// the equipment is the base's, and never changes with the taps. The common equipment is a normal button,
/// the others are gray (text `secondaryText`, a dashed outline, no fill) and can be chosen all the same;
/// the chosen one is white with black text. Changing the equipment keeps the grip or variation.
///
/// A combination hidden because an exercise of the user's own has its name stays in its place, unavailable,
/// at 35 %.
struct ExerciseOptionRows: View {
    let base: ExerciseBase
    /// The combination chosen.
    let selected: DefaultExercise
    /// The keys of the library exercises hidden because their name is taken.
    var hiddenKeys: Set<String> = []
    /// 18 between the rows on the screen and in the sheet; in the sheet 4 more above the first title.
    var captionTopPadding: CGFloat = 0
    var identifierPrefix = "exercise"
    let onChoose: @MainActor (DefaultExercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption("EQUIPAMENTO")
                .padding(.top, captionTopPadding)
            row(label: Text("Equipamento"), items: base.equipment.compactMap { option in
                ExerciseBaseIndex.combination(of: base.name, option: option, variation: selected.variation).map { target in
                    Option(
                        title: String(localized: option.displayName),
                        target: target,
                        isOn: option == selected.option,
                        isRare: !target.isCommon,
                        identifier: "\(identifierPrefix).equipment.\(option.rawValue)"
                    )
                }
            })
            if let secondRow = base.secondRow {
                caption(secondRow.kind == .grip ? "PEGADA" : "VARIAÇÃO")
                    .padding(.top, 18)
                row(label: secondRow.kind == .grip ? Text("Pegada") : Text("Variação"), items: secondRow.options.compactMap { option in
                    ExerciseBaseIndex.combination(of: base.name, option: selected.option, variation: option).map { target in
                        Option(
                            title: option,
                            target: target,
                            isOn: option == selected.variation,
                            isRare: false,
                            identifier: "\(identifierPrefix).variation.\(option)"
                        )
                    }
                })
            }
        }
    }

    private struct Option: Identifiable {
        var id: String { identifier }
        let title: String
        let target: DefaultExercise
        let isOn: Bool
        let isRare: Bool
        let identifier: String
    }

    /// EQUIPAMENTO, PEGADA, VARIAÇÃO: 10 heavy, spacing 1.4, in a line of 12, `secondaryText`, 10 above the row.
    private func caption(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .scaledFont(10, weight: .heavy, lineHeight: 1.2)
            .tracking(1.4)
            .foregroundStyle(Theme.Colors.secondaryText)
            .padding(.bottom, 10)
            .accessibilityHidden(true)
    }

    /// The buttons, 6 apart and 12 between the lines.
    private func row(label: Text, items: [Option]) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 12) {
            ForEach(items) { item in
                button(item)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func button(_ item: Option) -> some View {
        let isHidden = hiddenKeys.contains(item.target.key) && !item.isOn
        return Button {
            guard !item.isOn else { return }
            onChoose(item.target)
        } label: {
            ExerciseOptionLabel(title: item.title, isOn: item.isOn, isRare: item.isRare)
        }
        .buttonStyle(PrototypeButtonStyle())
        .disabled(isHidden)
        .accessibilityLabel(Text(verbatim: accessibilityText(item, isHidden: isHidden)))
        .accessibilityAddTraits(item.isOn ? .isSelected : [])
        .accessibilityIdentifier(item.identifier)
    }

    /// "Polia", "Kettlebell, menos comum", and for a hidden one "indisponível: você já tem um exercício com
    /// este nome".
    private func accessibilityText(_ item: Option, isHidden: Bool) -> String {
        var parts = [item.title]
        if item.isRare {
            parts.append(String(localized: "menos comum"))
        }
        var text = parts.joined(separator: ", ")
        if isHidden {
            text += ", " + String(localized: "indisponível: você já tem um exercício com este nome")
        }
        return text
    }
}

/// A button of the rows: 12 semibold, 32 high (44 of touch), 10 on the sides, a capsule. Normal: the card's
/// fill with a 1-point `cardBorder` outline and `brightText`; gray (less common): no fill, a dashed outline
/// and `secondaryText`; chosen: `primaryButton` with `primaryButtonText`.
struct ExerciseOptionLabel: View {
    let title: String
    let isOn: Bool
    let isRare: Bool

    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 32

    var body: some View {
        Text(verbatim: title)
            .scaledFont(12, weight: .semibold)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(minHeight: height)
            .background(background, in: Capsule())
            .overlay {
                if !isOn {
                    Capsule().strokeBorder(
                        Theme.Colors.cardBorder,
                        style: StrokeStyle(lineWidth: 1, dash: isRare ? [3, 3] : [])
                    )
                }
            }
            // 6 more points above and below respond to touches, for a 44-point touch area.
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .padding(.vertical, -6)
    }

    private var foreground: Color {
        if isOn { return Theme.Colors.primaryButtonText }
        return isRare ? Theme.Colors.secondaryText : Theme.Colors.brightText
    }

    private var background: Color {
        if isOn { return Theme.Colors.primaryButton }
        return isRare ? .clear : Theme.Colors.cardBackground
    }
}
