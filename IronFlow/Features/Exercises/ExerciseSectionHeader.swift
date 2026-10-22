import SwiftUI

/// The muscle group title above its exercises in the exercise picker.
struct ExerciseSectionHeader: View {
    let group: MuscleGroup

    var body: some View {
        Text(group.displayName)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("exercises.section.\(group.rawValue)")
    }
}
