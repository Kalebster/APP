import SwiftUI

/// A screen section title: uppercase, heavy and widely spaced. Shared by the Início and Treinos tabs.
struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline.weight(.heavy))
            .tracking(3)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}
