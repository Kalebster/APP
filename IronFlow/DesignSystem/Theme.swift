import SwiftUI

/// Iron Flow's visual base, shared by every screen: black, white and gray, with blue only in details.
///
/// Colors live in the asset catalog with a single value each: the app is dark only, whatever the
/// device appearance. The blue of the details is the catalog's `AccentColor`.
enum Theme {
    enum Colors {
        static let screenBackground = Color(.screenBackground)
        static let cardBackground = Color(.cardBackground)
        static let cardBorder = Color(.cardBorder)

        // The highlighted block of the Início (today's workout) and the card of today's workout in Treinos.
        static let highlightBackground = Color(.highlightBackground)
        /// White at 14%.
        static let highlightBorder = Color(.highlightBorder)
        /// Lines and outlines inside the highlight (chips), and the outline of the current exercise in the
        /// session: white at 18%.
        static let highlightLine = Color(.highlightLine)
        static let highlightText = Color(.highlightText)
        static let highlightSecondaryText = Color(.highlightSecondaryText)
        /// The small uppercase label of the highlight ("TREINO DE HOJE").
        static let highlightLabel = Color(.highlightLabel)
        /// The capsule badges ("Programado", "HOJE"): white at 10%.
        static let highlightBadge = Color(.highlightBadge)
        /// The line of light along the top edge of the Início's "Treino de hoje": white at 10%.
        static let highlightGlow = Color(.highlightGlow)

        /// The main buttons ("Iniciar", "Criar treino", "Concluir", the ▶, the sheets' action): white, with
        /// black text and icons. Also the logo's square, the day trained in the app and the number of the
        /// current working set.
        static let primaryButton = Color(.primaryButton)
        static let primaryButtonText = Color(.primaryButtonText)
        /// The chosen tab of the tab bar (the bar is the system's; this is its tint).
        static let selectedTab = Color(.selectedTab)

        /// The square behind an icon, and the light gray of icons and links.
        static let iconTileBackground = Color(.iconTileBackground)
        static let lightAccent = Color(.lightAccent)

        // The week: the ring, the days and the letters of the weekly plan.
        /// The ring's track and the days past without a workout.
        static let ringTrack = Color(.ringTrack)
        static let markedDayBackground = Color(.markedDayBackground)
        static let markedDayNumber = Color(.markedDayNumber)
        /// The dashed outline of a day marked as trained.
        static let markedDayBorder = Color(.markedDayBorder)
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
        /// The outline of a set's completion mark.
        static let controlBorder = Color(.controlBorder)
        /// The row of the current set, its fields and their suggestion.
        static let currentSetBackground = Color(.currentSetBackground)
        static let currentFieldBackground = Color(.currentFieldBackground)
        static let currentSuggestionText = Color(.currentSuggestionText)
        /// The outline of the current set's row (white at 35%, 1,5 points) and of its completion mark
        /// still to do (white at 55%, 2 points).
        static let currentSetBorder = Color(.currentSetBorder)
        static let currentCheckBorder = Color(.currentCheckBorder)

        // The Exercícios model.
        /// Secondary text between `mediumText` and `dimText`: the counts, the search icon and the muscle
        /// group of an exercise.
        static let secondaryText = Color(.secondaryText)

        // The workout editor model.
        /// The fill of an exercise chosen in the exercise picker, outlined in blue.
        static let selectedCardBackground = Color(.selectedCardBackground)
        /// The border of the dashed "Adicionar exercícios" button.
        static let dashedBorder = Color(.dashedBorder)
        // The lock screen drawn in the "Avisar quando o descanso acabar?" sheet, an illustration: a light
        // from the top over black (`lockScreenTop` to `lockScreenMiddle` to `screenBackground`), and the
        // notice on translucent gray.
        static let lockScreenTop = Color(.lockScreenTop)
        static let lockScreenMiddle = Color(.lockScreenMiddle)
        static let noticeBackground = Color(.noticeBackground)
        static let noticeText = Color(.noticeText)
        static let noticeSecondaryText = Color(.noticeSecondaryText)

        /// The colors of the set types, for the number of a set; their fills are these colors at 16–17%.
        static let warmupSet = Color(.warmupSet)
        static let feederSet = Color(.feederSet)
        static let failureSet = Color(.failureSet)
        // The exercise screen.
        /// The accent color of the catalog (`AccentColor`, #3D7BF0) itself, whatever the tint around it. Inside
        /// the tabs the tint is the white of the chosen tab, and `Color.accentColor` follows the tint, so a
        /// drawing that must be in the accent color (the main muscles, the evolution chart) uses this.
        static let accent = Color("AccentColor")
        /// The secondary muscles on the body figure: a darker blue (#30569C); the main ones are `accent`.
        static let muscleSecondary = Color(.muscleSecondary)
        /// A muscle the exercise does not use (#2C2C30, the same value as `currentFieldBackground`).
        static let muscleInactive = Color(.currentFieldBackground)
        /// The head, neck, hands, knees and feet of the body figure (#1E1E21, the same value as
        /// `iconTileBackground`).
        static let figureBase = Color(.iconTileBackground)
        /// The ticks of the months below the evolution chart and the line of the chosen point (#3A3A3F).
        static let chartRule = Color(.chartRule)
        /// The lines between the rows of the "Tipos de máquina" sheet: white at 8%.
        static let sheetListSeparator = Color(.sheetListSeparator)
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

    /// Content inside the highlight: near black with a border of white at 14%, drawn inside. For today's
    /// workout. With `glow`, a line of light of 1 point (white at 10%) along the top edge, inside the
    /// border, as the model draws only on the "Treino de hoje" of the Início.
    func highlightStyle(padding: EdgeInsets, cornerRadius: CGFloat, glow: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Theme.Colors.highlightBackground)
                if glow {
                    // CSS `inset 0 1px 0`: the part of the shape that the same shape, 1 point lower, leaves.
                    shape.subtracting(shape.offset(y: 1)).fill(Theme.Colors.highlightGlow)
                }
            }
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
