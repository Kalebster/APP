import SwiftUI

/// Inter (`InterFont`) at a size given in points of the default text size, growing and shrinking with
/// Dynamic Type like the text style of about that size does. The models are drawn in points: this keeps
/// their sizes at the default text size and follows the user's setting at any other.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    /// The Bold Text setting, which a custom font does not follow by itself.
    @Environment(\.legibilityWeight) private var legibilityWeight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .closest(toPoints: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        // A fixed size: `size` already follows Dynamic Type, and a font relative to a text style would
        // grow a second time.
        let name = InterFont.name(for: weight, boldText: legibilityWeight == .bold)
        return content.font(.custom(name, fixedSize: size))
    }
}

/// The model's CSS `line-height` for a text in Inter at `size`, scaled like `ScaledFont`: each line takes
/// `lineHeight` times the size, as in the model, instead of Inter's own height. Only the texts that set
/// a line height have it.
private struct ScaledLineHeight: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let lineHeight: CGFloat
    @Environment(\.displayScale) private var displayScale

    init(size: CGFloat, lineHeight: CGFloat) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .closest(toPoints: size))
        self.lineHeight = lineHeight
    }

    func body(content: Content) -> some View {
        let metrics = LineHeightMetrics(size: size, lineHeight: lineHeight, displayScale: displayScale)
        return content
            .lineSpacing(metrics.lineSpacing)
            .padding(.vertical, metrics.edgePadding)
    }
}

/// How a text of Inter at `size` points takes the model's CSS `line-height` (1,05 for the big titles,
/// 1,4 for the texts of the sheets): as in CSS, half of what each line gains (or loses) over Inter's own
/// height (`InterFont.lineHeightRatio`, about 1,21) goes above the text and half below it, and the whole
/// of it between two lines when the text wraps. A line shorter than Inter's only moves the text's
/// neighbours: its letters are drawn whole, never cut. Lines of a wrapped text are never closer than
/// Inter's own height: SwiftUI does not bring them closer.
struct LineHeightMetrics: Equatable {
    /// The space added between two lines of the text.
    let lineSpacing: CGFloat
    /// The space added above the first line and below the last one; negative to take some away.
    let edgePadding: CGFloat

    init(size: CGFloat, lineHeight: CGFloat, displayScale: CGFloat) {
        // Inter's own line, as SwiftUI lays a text out: rounded up to the screen's pixels.
        let scale = max(displayScale, 1)
        let ownLine = (size * InterFont.lineHeightRatio * scale).rounded(.up) / scale
        lineSpacing = max(size * (lineHeight - InterFont.lineHeightRatio), 0)
        edgePadding = (size * lineHeight - ownLine) / 2
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
    /// `lineHeight` is the model's CSS `line-height`, for the texts that set one (`LineHeightMetrics`);
    /// without it the text takes Inter's own height, the model's `normal`.
    @ViewBuilder
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular, lineHeight: CGFloat? = nil) -> some View {
        if let lineHeight {
            modifier(ScaledFont(size: size, weight: weight))
                .modifier(ScaledLineHeight(size: size, lineHeight: lineHeight))
        } else {
            modifier(ScaledFont(size: size, weight: weight))
        }
    }
}
