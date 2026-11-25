import SwiftUI

/// The exercise's name, 29 heavy with balanced lines as in the prototype, and "grupo · equipamento" below,
/// followed by MEU or ARQUIVADO for an exercise of the user's own. With large text the badge goes below.
struct ExerciseDetailTitle: View {
    let name: String
    let detail: String
    var badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            BalancedTextLayout {
                Text(verbatim: name)
                    .scaledFont(29, weight: .heavy, lineHeight: 1.05)
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("exercise.title")
            }
            if let badge {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        subtitle
                        badgeView(badge)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        subtitle
                        badgeView(badge)
                    }
                }
            } else {
                subtitle
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: some View {
        Text(verbatim: detail)
            .scaledFont(13)
            .foregroundStyle(Theme.Colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("exercise.subtitle")
    }

    /// The prototype's badge: 10 bold, spaced 0,8, on a 14-point line, 1 point above the baseline.
    private func badgeView(_ text: String) -> some View {
        CapsuleBadge(
            text: text,
            weight: .bold,
            tracking: 0.8,
            padding: EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
        )
        .alignmentGuide(.firstTextBaseline) { $0[.firstTextBaseline] + 1 }
        .accessibilityIdentifier("exercise.badge")
    }
}
