import SwiftData
import SwiftUI

/// The Home "Sua semana" card: the week's workouts and trained days, and its seven days. Tapping a
/// day marks it as trained outside the app; a marked day is unmarked after a confirmation.
///
/// The card reads only `week`: its queries are built from the week's limits when the card is
/// created. `HomeView` gives the card the week's start as its identity, so a new week creates a new
/// card with new queries.
struct WeekCard: View {
    let week: WeekSummary.Week
    let now: Date
    let calendar: Calendar

    /// Finished sessions started in the week.
    @Query private var sessions: [Session]
    /// Markings of the week's days.
    @Query private var markings: [ExternalWorkoutDay]

    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var dayToUnmark: WeekSummary.Day?
    @State private var errorMessage: String?

    init(week: WeekSummary.Week, now: Date, calendar: Calendar) {
        self.week = week
        self.now = now
        self.calendar = calendar
        let start = week.start
        let end = week.end
        _sessions = Query(filter: #Predicate<Session> { session in
            session.endedAt != nil && session.startedAt >= start && session.startedAt < end
        })
        let keys = week.keys
        _markings = Query(filter: #Predicate<ExternalWorkoutDay> { marking in
            keys.contains(marking.day)
        })
    }

    var body: some View {
        let days = WeekSummary.days(of: week, now: now, calendar: calendar, sessions: sessions, markedDays: markings.map(\.day))

        VStack(alignment: .leading, spacing: 16) {
            counts(workouts: WeekSummary.workoutCount(of: days), trainedDays: WeekSummary.trainedDayCount(of: days))

            HStack(spacing: 0) {
                ForEach(days) { day in
                    WeekDayCell(day: day) {
                        tap(day)
                    }
                }
            }
            // Seven columns never fit the largest text sizes; the Large Content Viewer shows each day.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            Text("Treinou fora do app? Toque no dia para marcar.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.week")
        .confirmationDialog(
            "Desmarcar este dia?",
            isPresented: Binding(
                get: { dayToUnmark != nil },
                set: { if !$0 { dayToUnmark = nil } }
            ),
            titleVisibility: .visible,
            presenting: dayToUnmark
        ) { day in
            Button("Desmarcar", role: .destructive) {
                unmark(day)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { day in
            Text(verbatim: day.dateText)
        }
        .errorAlert($errorMessage)
    }

    /// "N treinos esta semana" and "D/7 dias", side by side or, with the largest text sizes, stacked.
    @ViewBuilder
    private func counts(workouts: Int, trainedDays: Int) -> some View {
        let workoutsText = Text(WeekSummary.workoutsText(workouts))
            .font(.headline)
            .accessibilityIdentifier("home.week.count")
        let daysText = Text(WeekSummary.trainedDaysText(trainedDays))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("home.week.days")
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                workoutsText
                daysText
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                workoutsText
                    .frame(maxWidth: .infinity, alignment: .leading)
                daysText
            }
        }
    }

    private func tap(_ day: WeekSummary.Day) {
        switch day.tapAction {
        case .unavailable:
            break
        case .mark:
            do {
                try ExternalWorkoutService(context: context, calendar: calendar).mark(day.date)
            } catch {
                errorMessage = UserFacingError.message(for: error)
            }
        case .confirmUnmark:
            dayToUnmark = day
        }
    }

    private func unmark(_ day: WeekSummary.Day) {
        do {
            try ExternalWorkoutService(context: context, calendar: calendar).unmark(day.date)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// One day: its letter, its number in a circle, and a check below when it was marked by hand.
///
/// Blue always means trained: a solid circle for a workout in the app, a dashed one for a day marked
/// by hand (with the check). Today has a ring in the text color. A future day is faded. Only a day
/// with an action is a button.
private struct WeekDayCell: View {
    let day: WeekSummary.Day
    let onTap: @MainActor () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var circleSize: CGFloat = 32

    var body: some View {
        if day.tapAction == .unavailable {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.accessibilityText)
                .accessibilityIdentifier(identifier)
        } else {
            Button(action: onTap) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel(day.accessibilityText)
            .accessibilityHint(day.tapAction == .mark
                ? Text("Marca o dia como treino feito fora do app.")
                : Text("Pede confirmação para desmarcar o dia."))
            .accessibilityIdentifier(identifier)
        }
    }

    private var identifier: String {
        day.isToday ? "home.week.today" : "home.week.day"
    }

    private var content: some View {
        // Never wider than a column of the smallest iPhone.
        let size = min(circleSize, 36)

        return VStack(spacing: 6) {
            Text(verbatim: day.letter)
                .font(.caption.weight(.semibold))
                .foregroundStyle(day.isToday ? Color.primary : Color.secondary)

            Text(day.number.formatted())
                .font(.subheadline.weight(day.isToday || day.isTrained ? .bold : .regular))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(numberColor)
                .frame(width: size, height: size)
                .background { circle }
                .padding(3)
                .overlay {
                    if day.isToday {
                        Circle().strokeBorder(Color.primary, lineWidth: 2)
                    }
                }

            Image(systemName: "checkmark")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Color.accentColor)
                .opacity(day.isMarked ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityShowsLargeContentViewer()
    }

    @ViewBuilder
    private var circle: some View {
        if day.appWorkouts > 0 {
            Circle().fill(Color.accentColor)
        } else if day.isMarked {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .overlay {
                    Circle().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
        } else if !day.isFuture {
            Circle().fill(.fill.tertiary)
        }
    }

    private var numberColor: Color {
        if day.appWorkouts > 0 { return .white }
        if day.isMarked { return .accentColor }
        return day.isFuture ? Color(uiColor: .tertiaryLabel) : .primary
    }
}
