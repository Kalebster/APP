import SwiftUI

/// One view of the body figure, 81 × 220 points as in the prototype: the main muscles in the accent color,
/// the secondary ones in the darker blue, the others in gray and the parts without muscle darker still.
/// Drawn in one pass from paths read once. Decorative: the card says the muscles to VoiceOver.
struct BodyFigure: View {
    enum Side {
        case front, back
    }

    let side: Side
    let primary: Set<Muscle>
    let secondary: Set<Muscle>

    static let size = CGSize(width: 81, height: 220)

    var body: some View {
        Canvas { context, size in
            // The prototype's SVG fits its viewBox in the frame, centered (preserveAspectRatio meet).
            let box = BodyFigurePaths.viewBox
            let scale = min(size.width / box.width, size.height / box.height)
            context.translateBy(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -box.minX, y: -box.minY)
            context.fill(BodyFigurePaths.skin, with: .color(Theme.Colors.figureBase))
            for region in side == .front ? BodyFigurePaths.frontRegions : BodyFigurePaths.backRegions {
                context.fill(region.path, with: .color(color(of: region)))
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }

    /// A region shows a main muscle first, then a secondary one, else none.
    private func color(of region: BodyFigurePaths.DrawnRegion) -> Color {
        if region.muscles.contains(where: primary.contains) {
            return .accentColor
        }
        if region.muscles.contains(where: secondary.contains) {
            return Theme.Colors.muscleSecondary
        }
        return Theme.Colors.muscleInactive
    }
}
