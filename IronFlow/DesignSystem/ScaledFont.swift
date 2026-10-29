import SwiftUI

/// Inter (`InterFont`) at a size given in points of the default text size, growing and shrinking with
/// Dynamic Type like the text style of about that size does. The models are drawn in points: this keeps
/// their sizes at the default text size and follows the user's setting at any other.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: Self.textStyle(for: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        // A fixed size: `size` already follows Dynamic Type, and a font relative to a text style would
        // grow a second time.
        content.font(.custom(InterFont.name(for: weight), fixedSize: size))
    }

    /// The text style whose default size is closest, so the font grows at the same rate as it.
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
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
    /// Inter at `size` points of the default text size, in the file of `weight`, scaled with Dynamic Type.
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}
