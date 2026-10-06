import SwiftUI

/// Iron Flow's visual base, shared by every screen: black, white, gray and dark blue.
///
/// Colors live in the asset catalog with light and dark variants, so the system switches
/// them with the device appearance. The accent (dark blue) is the catalog's `AccentColor`.
enum Theme {
    enum Colors {
        static let screenBackground = Color(.screenBackground)
        static let cardBackground = Color(.cardBackground)
        static let cardBorder = Color(.cardBorder)
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }
}

extension View {
    /// Content inside a rounded card with a subtle border.
    func cardStyle() -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
        return padding(Theme.Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground, in: shape)
            .overlay(shape.strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
    }

    /// A `List` row laid out like the card stacks: no separator, transparent row
    /// background and the same spacing and margins. The row content draws its own card.
    func cardListRow() -> some View {
        listRowInsets(EdgeInsets(
            top: Theme.Metrics.cardSpacing / 2,
            leading: Theme.Metrics.screenPadding,
            bottom: Theme.Metrics.cardSpacing / 2,
            trailing: Theme.Metrics.screenPadding
        ))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    /// The screen background, extended under the bars.
    func screenBackground() -> some View {
        background {
            Theme.Colors.screenBackground.ignoresSafeArea()
        }
    }
}
