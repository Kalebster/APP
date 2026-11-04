import SwiftUI

/// Inter (`InterFont`) at a size given in points of the default text size, growing and shrinking with
/// Dynamic Type like the text style of about that size does. The models are drawn in points: this keeps
/// their sizes at the default text size and follows the user's setting at any other.
///
/// `lineHeight` is the model's CSS `line-height` for the texts that set one (1,05 for the big titles,
/// 1,4 for the texts of the sheets): each line then takes `lineHeight` times the size, as in the model,
/// instead of Inter's own height (`InterFont.lineHeightRatio`, about 1,21). As in CSS, half of the
/// difference goes above the text and half below it, and between two lines when the text wraps. A line
/// shorter than Inter's only moves the text's neighbours: its letters are drawn whole, never cut. Lines
/// of a wrapped text are never closer than Inter's own height: SwiftUI does not bring them closer.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let lineHeight: CGFloat?
    /// The Bold Text setting, which a custom font does not follow by itself.
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.displayScale) private var displayScale

    init(size: CGFloat, weight: Font.Weight, lineHeight: CGFloat?) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .closest(toPoints: size))
        self.weight = weight
        self.lineHeight = lineHeight
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        // A fixed size: `size` already follows Dynamic Type, and a font relative to a text style would
        // grow a second time.
        let name = InterFont.name(for: weight, boldText: legibilityWeight == .bold)
        let font = content.font(.custom(name, fixedSize: size))
        if let lineHeight {
            // Inter's own line, as SwiftUI lays a text out: rounded up to the screen's pixels.
            let scale = max(displayScale, 1)
            let ownLine = (size * InterFont.lineHeightRatio * scale).rounded(.up) / scale
            font
                // What each line gains between two lines (never less than Inter's own height).
                .lineSpacing(max(size * (lineHeight - InterFont.lineHeightRatio), 0))
                // Half of what the first and last lines gain (or lose, below 1,21) above and below.
                .padding(.vertical, (size * lineHeight - ownLine) / 2)
        } else {
            font
        }
    }
}

extension Font.TextStyle {
    /// The text style whose default size is closest to `points`, so what is sized in points of the
    /// default text size (a font, an icon) grows at the same rate as that text.
    static func closest(toPoints points: CGFloat) -> Font.TextStyle {
        switch points {
        case ..<11.5: .caption2
        case ..<12.5: .caption
        case ..<14: .footnote
        case ..<15.5: .subheadline
        case ..<16.5: .callout
        case ..<18.5: .body
        case ..<21: .title3
        case ..<25: .title2
        case ..<30.5: .title
        default: .largeTitle
        }
    }
}

/// Inter Regular at 17 points, scaled with Dynamic Type like the body text, for the texts that set no
/// font of their own; heavier with the Bold Text setting.
private struct DefaultInterFont: ViewModifier {
    @Environment(\.legibilityWeight) private var legibilityWeight

    func body(content: Content) -> some View {
        let name = InterFont.name(for: .regular, boldText: legibilityWeight == .bold)
        return content.font(.custom(name, size: 17, relativeTo: .body))
    }
}

extension View {
    /// Inter for the texts below that set no font of their own (`scaledFont` sets one).
    func defaultInterFont() -> some View {
        modifier(DefaultInterFont())
    }

    /// Inter at `size` points of the default text size, in the file of `weight`, scaled with Dynamic Type.
    /// `lineHeight` is the model's CSS `line-height`, for the texts that set one; without it the text
    /// takes Inter's own height, the model's `normal`.
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular, lineHeight: CGFloat? = nil) -> some View {
        modifier(ScaledFont(size: size, weight: weight, lineHeight: lineHeight))
    }
}
