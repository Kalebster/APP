import SwiftUI

/// Iron Flow's visual base, shared by every screen: black, white, gray and dark blue.
///
/// Colors live in the asset catalog with a single value each: the app is dark only, whatever the
/// device appearance. The accent (dark blue) is the catalog's `AccentColor`.
enum Theme {
    enum Colors {
        static let screenBackground = Color(.screenBackground)
        static let cardBackground = Color(.cardBackground)
        static let cardBorder = Color(.cardBorder)

        // The highlighted block of the Início (today's workout) and the card of today's workout in Treinos.
        static let highlightBackground = Color(.highlightBackground)
        static let highlightBorder = Color(.highlightBorder)
        /// Lines and outlines inside the highlight: chips and secondary buttons.
        static let highlightLine = Color(.highlightLine)
        static let highlightText = Color(.highlightText)
        static let highlightSecondaryText = Color(.highlightSecondaryText)
        /// The small uppercase label of the highlight ("TREINO DE HOJE").
        static let highlightLabel = Color(.highlightLabel)
        /// The capsule badges ("Programado", "HOJE").
        static let highlightBadge = Color(.highlightBadge)

        /// The square behind an icon, and the light blue of icons and links.
        static let iconTileBackground = Color(.iconTileBackground)
        static let lightAccent = Color(.lightAccent)

        // The week: the ring, the days and the letters of the weekly plan.
        /// The ring's track and the days past without a workout.
        static let ringTrack = Color(.ringTrack)
        static let markedDayBackground = Color(.markedDayBackground)
        static let markedDayNumber = Color(.markedDayNumber)
        static let plannedDayBackground = Color(.plannedDayBackground)
        static let plannedDayLetter = Color(.plannedDayLetter)
        static let unplannedDayBackground = Color(.unplannedDayBackground)
        static let futureDayText = Color(.futureDayText)
        /// Today's ring and letter.
        static let brightText = Color(.brightText)

        /// Faded text, such as the letter of a day without a planned workout.
        static let dimText = Color(.dimText)
        /// Text between the primary and the secondary color, such as a duration.
        static let mediumText = Color(.mediumText)
        /// The line between the rows of a card.
        static let rowSeparator = Color(.rowSeparator)

        // The session in progress.
        /// The fill of a set's load and repetition fields.
        static let setFieldBackground = Color(.setFieldBackground)
        /// The value offered in an empty field (the last time, or the plan).
        static let suggestionText = Color(.suggestionText)
        /// The outline of a set's completion mark and of the rest bar.
        static let controlBorder = Color(.controlBorder)
        /// The row of the current set, its fields and their suggestion.
        static let currentSetBackground = Color(.currentSetBackground)
        static let currentFieldBackground = Color(.currentFieldBackground)
        static let currentSuggestionText = Color(.currentSuggestionText)
        /// The floating rest bar.
        static let restBarBackground = Color(.restBarBackground)

        // The Exercícios model.
        /// Secondary text between `mediumText` and `dimText`: the counts, the search icon and the muscle
        /// group of an exercise.
        static let secondaryText = Color(.secondaryText)

        // The workout editor model.
        /// The fill of an exercise chosen in the exercise picker, outlined in the accent color.
        static let selectedCardBackground = Color(.selectedCardBackground)
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

    /// Content inside a rounded card with a subtle border, with the padding and corners of the
    /// Início and Treinos models (`cardStyle()` keeps those of the other screens).
    func cardStyle(padding: EdgeInsets, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground, in: shape)
            .overlay(shape.strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
    }

    /// Content inside the highlight: dark blue with a blue border. For today's workout.
    func highlightStyle(padding: EdgeInsets, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.highlightBackground, in: shape)
            .overlay(shape.strokeBorder(Theme.Colors.highlightBorder, lineWidth: 1))
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

    /// Gives the status bar area the screen background, so content scrolled up never shows behind the
    /// clock and the status icons. For screens that hide the navigation bar, which would otherwise be
    /// the one thing covering that area. It adds no height: the layout does not change.
    func statusBarBackground() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(Theme.Colors.screenBackground, ignoresSafeAreaEdges: .top)
        }
    }
}
