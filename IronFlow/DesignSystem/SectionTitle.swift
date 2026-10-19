import SwiftUI

/// A screen section title: small, uppercase, heavy and widely spaced. Shared by the Início and Treinos tabs.
struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .scaledFont(11, weight: .heavy)
            .tracking(2.1)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}
