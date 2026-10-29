import SwiftData
import SwiftUI

/// The Home "Sua semana" card: the week's goal (a ring with the workouts done against the days of the
/// weekly plan) or, without a plan, the week's count, and its seven days. Tapping a day marks it as
/// trained outside the app; a marked day is unmarked after a confirmation.
///
/// The card reads only `week`: its queries are built from the week's limits when the card is
/// created. `HomeView` gives the card the week's start as its identity, so a new week creates a new
/// card with new queries.
struct WeekCard: View {
    let week: WeekSummary.Week
    let now: Date
    let calendar: Calendar
    /// The weekdays of the weekly plan with a workout, 1 = Monday to 7 = Sunday.
    let plannedWeekdays: Set<Int>
    /// Without workouts there is nothing to plan, so the card does not offer it.
    let hasWorkouts: Bool
    /// Opens the weekly plan.
    let onPlan: @MainActor () -> Void

    /// Finished sessions started in the week.
    @Query private var sessions: [Session]
    /// Markings of the week's days.
    @Query private var markings: [ExternalWorkoutDay]

    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Shows "Dia 13 marcado como treinado".
    @Environment(RootFeedback.self) private var rootFeedback: RootFeedback?
    @State private var dayToUnmark: WeekSummary.Day?
    @State private var errorMessage: String?

    init(
        week: WeekSummary.Week,
        now: Date,
        calendar: Calendar,
        plannedWeekdays: Set<Int>,
        hasWorkouts: Bool,
        onPlan: @escaping @MainActor () -> Void
    ) {
        self.week = week
        self.now = now
        self.calendar = calendar
        self.plannedWeekdays = plannedWeekdays
        self.hasWorkouts = hasWorkouts
        self.onPlan = onPlan
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
        let days = WeekSummary.days(
            of: week,
            now: now,
            calendar: calendar,
            sessions: sessions,
            markedDays: markings.map(\.day),
            plannedWeekdays: plannedWeekdays
        )

        VStack(alignment: .leading, spacing: 15) {
            if let goal = WeekSummary.goal(of: days, plannedDays: plannedWeekdays.count) {
                goalSummary(goal)
            } else {
                countSummary(WeekSummary.workoutCount(of: days))
            }

            HStack(spacing: 3) {
                ForEach(days) { day in
                    WeekDayCell(day: day) {
                        tap(day)
                    }
                }
            }
            // Seven columns never fit the largest text sizes; the Large Content Viewer shows each day.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            Text("Treinou fora do app? Toque no dia para marcar.")
                .scaledFont(11)
                .foregroundStyle(.secondary)
        }
        .cardStyle(padding: EdgeInsets(top: 15, leading: 12, bottom: 14, trailing: 12), cornerRadius: 17)
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

    /// The ring and, beside it (below it with the accessibility text sizes), "3 de 4 treinos" and what
    /// is left to close the week.
    @ViewBuilder
    private func goalSummary(_ goal: WeekSummary.Goal) -> some View {
        let texts = VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: goal.titleText)
                .scaledFont(19, weight: .heavy)
                .accessibilityIdentifier("home.week.count")
            Text(verbatim: goal.remainingText)
                .scaledFont(12)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("home.week.remaining")
        }
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                WeekGoalRing(goal: goal)
                texts
            }
        } else {
            HStack(alignment: .center, spacing: 16) {
                WeekGoalRing(goal: goal)
                texts
                Spacer(minLength: 0)
            }
        }
    }

    /// Without a weekly plan: the week's count and an invitation to plan the week, which opens the plan
    /// when there are workouts to plan.
    private func countSummary(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: WeekSummary.workoutsText(count))
                .scaledFont(19, weight: .heavy)
                .accessibilityIdentifier("home.week.count")
            if hasWorkouts {
                Text("Programe a semana para acompanhar sua meta.")
                    .scaledFont(12)
                    .foregroundStyle(.secondary)
                Button(action: onPlan) {
                    Text("Programar semana")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(Theme.Colors.lightAccent)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // The touch area stays 44 points tall while the link takes less room.
                .padding(.vertical, -8)
                .accessibilityIdentifier("home.week.plan")
            } else {
                Text("Crie um treino para programar a semana.")
                    .scaledFont(12)
                    .foregroundStyle(.secondary)
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
                rootFeedback?.show(String(localized: "Dia \(day.number) marcado como treinado"))
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

/// The week's goal as a ring: the accent line fills the share of the goal done (full once it is reached
/// or passed), with "3/4" and "treinos" in the middle.
private struct WeekGoalRing: View {
    let goal: WeekSummary.Goal

    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 79

    var body: some View {
        let side = min(size, 120)
        let lineWidth: CGFloat = 8

        ZStack {
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(Theme.Colors.ringTrack, lineWidth: lineWidth)
            // Nothing at 0: a line cut to no length still draws a dot with its round ends.
            if goal.progress > 0 {
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: goal.progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text(verbatim: goal.ringText)
                    .scaledFont(22, weight: .heavy)
                    .monospacedDigit()
                Text(verbatim: goal.ringCaption)
                    .scaledFont(10)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(lineWidth + 4)
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: goal.accessibilityText))
        .accessibilityIdentifier("home.week.goal")
    }
}

/// One day: its letter, its number in a circle and, for a planned day still to do, a dot below.
///
/// Blue always means trained: a solid circle for a workout in the app, a dashed one for a day marked
/// outside the app. A day past without a workout is gray; today has a light ring; a future day shows
/// its number only. Only a day with an action is a button.
private struct WeekDayCell: View {
    let day: WeekSummary.Day
    let onTap: @MainActor () -> Void

    @ScaledMetric(relativeTo: .footnote) private var circleSize: CGFloat = 31

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
                .scaledFont(10, weight: day.isToday ? .bold : .semibold)
                .foregroundStyle(day.isToday ? Theme.Colors.brightText : Color.secondary)

            Text(day.number.formatted())
                .scaledFont(13, weight: numberWeight)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(numberColor)
                .frame(width: size, height: size)
                .background { circle }
                .overlay {
                    if day.isToday {
                        Circle().strokeBorder(Theme.Colors.brightText, lineWidth: 2)
                    }
                }

            // Decorative: the day's label already says it is planned.
            Circle()
                .fill(Color.accentColor)
                .frame(width: 4, height: 4)
                .opacity(day.showsPlanDot ? 1 : 0)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        // The whole column responds, at least 44 points tall.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityShowsLargeContentViewer()
    }

    @ViewBuilder
    private var circle: some View {
        switch day.appearance {
        case .trainedInApp:
            Circle().fill(Color.accentColor)
        case .markedOutside:
            Circle()
                .fill(Theme.Colors.markedDayBackground)
                .overlay {
                    Circle().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
        case .missed:
            Circle().fill(Theme.Colors.ringTrack)
        case .todayWithoutWorkout, .future:
            EmptyView()
        }
    }

    private var numberWeight: Font.Weight {
        switch day.appearance {
        case .trainedInApp, .markedOutside, .todayWithoutWorkout: .bold
        case .missed, .future: .regular
        }
    }

    private var numberColor: Color {
        switch day.appearance {
        case .trainedInApp: .white
        case .markedOutside: Theme.Colors.markedDayNumber
        case .missed: Theme.Colors.mediumText
        case .todayWithoutWorkout: Theme.Colors.brightText
        case .future: Theme.Colors.futureDayText
        }
    }
}
