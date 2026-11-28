import SwiftUI

/// A screen section title: small, uppercase, heavy and widely spaced. Shared by the Início and Treinos
/// tabs (11 points, spaced 2,1) and their sheets (`SheetSectionTitle`, 10 points, spaced 1,8).
struct SectionTitle: View {
    let title: LocalizedStringKey
    let size: CGFloat
    let tracking: CGFloat
    /// The line in whole points, as the prototype's WebKit (`scaledFont(_:webKitLine:)`): in the screens
    /// measured against it since the base list.
    let webKitLine: Bool

    init(_ title: LocalizedStringKey, size: CGFloat = 11, tracking: CGFloat = 2.1, webKitLine: Bool = false) {
        self.title = title
        self.size = size
        self.tracking = tracking
        self.webKitLine = webKitLine
    }

    var body: some View {
        Text(title)
            .scaledFont(size, weight: .heavy, webKitLine: webKitLine)
            .tracking(tracking)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}
