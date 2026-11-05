import SwiftUI

/// An icon of the approved model, from the `Icons` folder of the asset catalog: drawn on a 24 × 24
/// grid, kept as a vector and tinted by `foregroundStyle`, like the model's `currentColor`.
///
/// `size` is its side in points of the default text size, the model's size; it grows with Dynamic
/// Type like the text style of about that size, or like `textStyle` when the icon goes with a box
/// sized by another style. Decorative: the text next to it, or the label of its button, says what it is.
struct AppIcon: View {
    let resource: ImageResource
    @ScaledMetric private var side: CGFloat

    init(_ resource: ImageResource, size: CGFloat, relativeTo textStyle: Font.TextStyle? = nil) {
        self.resource = resource
        _side = ScaledMetric(wrappedValue: size, relativeTo: textStyle ?? .closest(toPoints: size))
    }

    var body: some View {
        Image(resource)
            .renderingMode(.template)
            .resizable()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}
