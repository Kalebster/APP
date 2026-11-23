import SwiftUI

/// The exercise's name, 29 heavy with balanced lines as in the prototype, and "grupo · equipamento" below.
struct ExerciseDetailTitle: View {
    let name: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            BalancedTextLayout {
                Text(verbatim: name)
                    .scaledFont(29, weight: .heavy, lineHeight: 1.05)
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("exercise.title")
            }
            Text(verbatim: detail)
                .scaledFont(13)
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("exercise.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
