import SwiftUI
import UIKit

/// SF Pro, the system font, at a size given in points of the default text size, growing and shrinking
/// with Dynamic Type like the text style of about that size does. The models are drawn in points: this
/// keeps their sizes at the default text size and follows the user's setting at any other. The system
/// font follows the Bold Text setting by itself.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .closest(toPoints: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        // A fixed size: `size` already follows Dynamic Type, and a font relative to a text style would
        // grow a second time.
        content.font(.system(size: size, weight: weight))
    }
}

/// The model's CSS `line-height` for a text of SF Pro at `size` and `weight`, scaled like `ScaledFont`:
/// each line takes `lineHeight` times the size, as in the model, instead of the font's own height. Only
/// the texts that set a line height have it.
private struct ScaledLineHeight: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let lineHeight: CGFloat
    @Environment(\.displayScale) private var displayScale

    init(size: CGFloat, weight: Font.Weight, lineHeight: CGFloat) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .closest(toPoints: size))
        self.weight = weight
        self.lineHeight = lineHeight
    }

    func body(content: Content) -> some View {
        let metrics = LineHeightMetrics(size: size, weight: weight, lineHeight: lineHeight, displayScale: displayScale)
        return content
            .lineSpacing(metrics.lineSpacing)
            .padding(.vertical, metrics.edgePadding)
    }
}

/// SF Pro, as iOS draws it.
enum SystemFont {
    /// The height iOS gives a line of the system font at `size` points and `weight`: the model's
    /// `line-height: normal`. It is the font's own, and it changes with the size: the font switches from
    /// its Text design to its Display design at 20 points.
    static func lineHeight(size: CGFloat, weight: Font.Weight) -> CGFloat {
        UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight).lineHeight
    }
}

extension Font.Weight {
    /// The same weight for UIKit.
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

/// How a text of SF Pro at `size` points and `weight` takes the model's CSS `line-height` (1,05 for the
/// big titles, 1,4 for the texts of the sheets): as in CSS, half of what each line gains (or loses) over
/// the font's own height (`SystemFont.lineHeight`) goes above the text and half below it, and the whole
/// of it between two lines when the text wraps. A line shorter than the font's only moves the text's
/// neighbours: its letters are drawn whole, never cut. Lines of a wrapped text are never closer than the
/// font's own height: SwiftUI does not bring them closer.
struct LineHeightMetrics: Equatable {
    /// The space added between two lines of the text.
    let lineSpacing: CGFloat
    /// The space added above the first line and below the last one; negative to take some away.
    let edgePadding: CGFloat

    init(size: CGFloat, weight: Font.Weight, lineHeight: CGFloat, displayScale: CGFloat) {
        let ownHeight = SystemFont.lineHeight(size: size, weight: weight)
        // The font's own line, as SwiftUI lays a text out: rounded up to the screen's pixels.
        let scale = max(displayScale, 1)
        let ownLine = (ownHeight * scale).rounded(.up) / scale
        lineSpacing = max(size * lineHeight - ownHeight, 0)
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

extension View {
    /// SF Pro at `size` points of the default text size and `weight`, scaled with Dynamic Type.
    /// `lineHeight` is the model's CSS `line-height`, for the texts that set one (`LineHeightMetrics`);
    /// without it the text takes the font's own height, the model's `normal`.
    @ViewBuilder
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular, lineHeight: CGFloat? = nil) -> some View {
        if let lineHeight {
            modifier(ScaledFont(size: size, weight: weight))
                .modifier(ScaledLineHeight(size: size, weight: weight, lineHeight: lineHeight))
        } else {
            modifier(ScaledFont(size: size, weight: weight))
        }
    }
}
