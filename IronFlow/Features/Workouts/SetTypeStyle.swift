import SwiftUI

extension SetType {
    /// The color of the number of a set of this type: yellow, lilac, the light gray of a working set,
    /// or red.
    var numberColor: Color {
        switch self {
        case .warmup: Theme.Colors.warmupSet
        case .feeder: Theme.Colors.feederSet
        case .working: Theme.Colors.mediumText
        case .failure: Theme.Colors.failureSet
        }
    }

    /// The fill behind the number: the type's color at 16% (17% for the lilac), or the dark gray of a
    /// working set.
    var numberBackground: Color {
        switch self {
        case .warmup: Theme.Colors.warmupSet.opacity(0.16)
        case .feeder: Theme.Colors.feederSet.opacity(0.17)
        case .working: Theme.Colors.unplannedDayBackground
        case .failure: Theme.Colors.failureSet.opacity(0.16)
        }
    }
}

/// The number of a set in the colors of its type, on a rounded square: in the rows of the workout
/// editor and in the set type sheet. Decorative: the row says the type.
struct SetNumberSquare: View {
    let number: Int
    let type: SetType
    /// The side of the square, in points of the default text size; it grows with the text.
    @ScaledMetric private var side: CGFloat
    private let fontSize: CGFloat

    init(number: Int, type: SetType, side: CGFloat, fontSize: CGFloat) {
        self.number = number
        self.type = type
        self.fontSize = fontSize
        _side = ScaledMetric(wrappedValue: side, relativeTo: .caption)
    }

    var body: some View {
        Text(number.formatted())
            .scaledFont(fontSize, weight: .heavy)
            .monospacedDigit()
            .foregroundStyle(type.numberColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: side, height: side)
            .background(type.numberBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// The legend of the set types, above the exercises of the workout editor: a 9-point dot in each
/// type's color and its name, 12 points apart. It wraps with large text. VoiceOver reads it once.
struct SetTypeLegend: View {
    @ScaledMetric(relativeTo: .caption2) private var dotSide: CGFloat = 9

    var body: some View {
        FlowLayout(spacing: 12) {
            ForEach(SetType.allCases, id: \.self) { (type: SetType) in
                HStack(spacing: 5) {
                    Circle()
                        .fill(type.numberColor)
                        .frame(width: dotSide, height: dotSide)
                    Text(type.displayName)
                        .scaledFont(11)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
        .accessibilityIdentifier("workout.legend")
    }

    /// "Tipos de série: Aquecimento, Preparatória, Válida, Falha".
    private var accessibilityText: String {
        let names = SetType.allCases.map { String(localized: $0.displayName) }.joined(separator: ", ")
        return String(localized: "Tipos de série: \(names)")
    }
}
