import SwiftUI

/// The muscles of the exercise: the body figure from the front and from the back and, on its right, the
/// legend: PRINCIPAL (PRINCIPAIS with more than one), SECUNDÁRIOS (only when there are some) and FOCO, or,
/// for an exercise of the user's own, the note that the figure shows its group. With the largest text
/// sizes the legend goes below the figure. VoiceOver reads the card as one item.
struct ExerciseMusclesCard: View {
    let primary: [Muscle]
    let secondary: [Muscle]
    let focus: String?
    let isCustom: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        layout {
            HStack(spacing: 4) {
                figure(.front, title: "Frente")
                figure(.back, title: "Costas")
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
            MusclesLegend(primary: primary, secondary: secondary, focus: focus, isCustom: isCustom)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle(padding: EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14), cornerRadius: 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
        .accessibilityValue(Text(verbatim: accessibilityDetail))
        .accessibilityIdentifier("exercise.muscles")
    }

    private func figure(_ side: BodyFigure.Side, title: LocalizedStringKey) -> some View {
        VStack(spacing: 6) {
            BodyFigure(side: side, primary: Set(primary), secondary: Set(secondary))
            Text(title)
                .scaledFont(11)
                .foregroundStyle(Theme.Colors.dimText)
        }
    }

    /// "Músculos principais: Peitoral. Secundários: Tríceps, Deltoide anterior."; without muscles,
    /// "Músculos principais: corpo inteiro.".
    private var accessibilityText: String {
        let main = primary.isEmpty
            ? String(localized: "corpo inteiro")
            : primary.map { String(localized: $0.displayName) }.joined(separator: ", ")
        var text = String(localized: "Músculos principais: \(main)")
        if !secondary.isEmpty {
            let others = secondary.map { String(localized: $0.displayName) }.joined(separator: ", ")
            text += String(localized: ". Secundários: \(others)")
        }
        return text + "."
    }

    /// What follows the muscles: the focus, or the note of an exercise of the user's own.
    private var accessibilityDetail: String {
        if isCustom {
            return String(localized: "Exercício seu: o boneco mostra o grupo dele.")
        }
        return focus.map { String(localized: "Foco: \($0)") } ?? ""
    }
}

/// The legend on the right of the body figure.
private struct MusclesLegend: View {
    let primary: [Muscle]
    let secondary: [Muscle]
    let focus: String?
    let isCustom: Bool

    @ScaledMetric(relativeTo: .caption2) private var swatchSide: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            group(
                title: primary.count > 1 ? "PRINCIPAIS" : "PRINCIPAL",
                swatch: .accentColor,
                values: primary.isEmpty ? [String(localized: "Corpo inteiro")] : primary.map { String(localized: $0.displayName) }
            )
            if !secondary.isEmpty {
                group(title: "SECUNDÁRIOS", swatch: Theme.Colors.muscleSecondary, values: secondary.map { String(localized: $0.displayName) })
            }
            if isCustom {
                Text("Exercício seu: o boneco mostra o grupo dele.")
                    .scaledFont(12, lineHeight: 1.35)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let focus {
                group(title: "FOCO", swatch: nil, values: [focus])
            }
        }
    }

    private func group(title: LocalizedStringKey, swatch: Color?, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if let swatch {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(swatch)
                        .frame(width: swatchSide, height: swatchSide)
                }
                Text(title)
                    .scaledFont(10, weight: .heavy)
                    .tracking(1.4)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(values, id: \.self) { value in
                    Text(verbatim: value)
                        .scaledFont(14, weight: .semibold, lineHeight: 1.25)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
