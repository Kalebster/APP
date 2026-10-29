import SwiftData
import SwiftUI

/// "Programação semanal": how many days have a workout, the week's goal it makes, and the seven days of
/// the current week, Monday to Sunday, each with its date and its workout or "Descanso". Tapping a day
/// opens its sheet, where choosing saves at once and closes it; the day then shows a blue outline for a
/// moment. A day has at most one workout; the same workout can be on several days.
///
/// As in the model, the navigation and tab bars are hidden: the screen has its own "‹ Treinos" (or
/// "‹ Início", `backTitle`), and the swipe from the edge still goes back.
struct WeeklyPlanView: View {
    /// The screen it was opened from: "Treinos" or "Início".
    let backTitle: LocalizedStringKey

    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    /// The weekly plan: at most seven records, so all of them are read.
    @Query private var plan: [WeeklyPlanDay]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// The moment "Hoje" and the dates are shown for; follows the day, as the Home does.
    @State private var now = Date.now
    @State private var editingDay: WeeklyPlanSummary.Row?
    /// The day just changed, outlined for a moment.
    @State private var changedWeekday: Int?
    @State private var errorMessage: String?

    var body: some View {
        let calendar = TrainingDay.calendar
        let rows = WeeklyPlanSummary.rows(
            plan: plan,
            workouts: workouts,
            todayWeekday: TrainingDay.planWeekday(of: now, calendar: calendar)
        )
        let plannedDays = WeeklyPlanSummary.plannedDayCount(plan: plan, workouts: workouts)
        let week = WeekSummary.week(containing: now, calendar: calendar)
        let byID = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Programação semanal")
                        .scaledFont(29, weight: .heavy)
                        .tracking(-0.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("plan.title")
                    Text(verbatim: WeeklyPlanSummary.headerText(plannedDays: plannedDays))
                        .scaledFont(13)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .accessibilityIdentifier("plan.header")
                }
                .padding(.bottom, 8)

                goalCard(plannedDays: plannedDays)
                    .padding(.bottom, 6)

                ForEach(rows) { row in
                    let workout = row.workoutID.flatMap { byID[$0] }
                    Button {
                        editingDay = row
                    } label: {
                        WeeklyPlanDayRow(
                            row: row,
                            dayNumber: calendar.component(.day, from: week.days[row.weekday - 1]),
                            workout: workout,
                            isChanged: changedWeekday == row.weekday
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: WeeklyPlanDayRow.accessibilityText(row: row, workout: workout)))
                    .accessibilityHint(Text("Abre as opções de treino deste dia."))
                    .accessibilityIdentifier(row.isToday ? "plan.today" : "plan.day.\(row.weekday)")
                }

                Text("A programação não impede treinar em outros dias · toque num dia para mudar")
                    .scaledFont(10)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 4)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                TextBackButton(title: backTitle) {
                    dismiss()
                }
                .accessibilityIdentifier("plan.back")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .background(Theme.Colors.screenBackground)
        }
        .screenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.screen")
        // The navigation bar is hidden for the model's own top row; the swipe back stays.
        .background(InteractivePopEnabler())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $editingDay) { row in
            WeeklyPlanDaySheet(row: row, workouts: workouts) { workout in
                choose(workout, for: row.weekday)
            }
        }
        .task(id: changedWeekday) {
            guard changedWeekday != nil else { return }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                // Another day was changed: its own task clears its outline.
                return
            }
            withAnimation(.easeOut(duration: 0.3)) {
                changedWeekday = nil
            }
        }
        .updatingCurrentDate($now)
        .errorAlert($errorMessage)
    }

    /// "Meta da semana: 4 treinos" on blue, with what it means.
    private func goalCard(plannedDays: Int) -> some View {
        HStack(spacing: 12) {
            IconTile(systemImage: "target", side: 36, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: WeeklyPlanSummary.goalText(plannedDays: plannedDays))
                    .scaledFont(15, weight: .heavy)
                    .foregroundStyle(Theme.Colors.highlightText)
                Text("É o anel da semana no Início. Cada dia com treino conta 1.")
                    .scaledFont(11)
                    .foregroundStyle(Theme.Colors.highlightSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .highlightStyle(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14), cornerRadius: 15)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plan.goal")
    }

    /// Plans `workout` for the day, or makes it a rest day when there is none, and outlines the day.
    private func choose(_ workout: Workout?, for weekday: Int) {
        let service = WeeklyPlanService(context: context)
        do {
            if let workout {
                try service.setWorkout(workout, for: weekday)
            } else {
                try service.clear(weekday: weekday)
            }
            changedWeekday = weekday
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// One day: its abbreviation and date in a square (blue with a workout), the workout with what it
/// holds, or "Descanso" in gray, and a chevron. Today is on blue with "HOJE". VoiceOver reads the day,
/// "hoje" for today, the choice and what the workout holds.
private struct WeeklyPlanDayRow: View {
    let row: WeeklyPlanSummary.Row
    let dayNumber: Int
    /// The day's workout; `nil` on a rest day.
    let workout: Workout?
    /// Just changed: outlined in blue.
    let isChanged: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var dateSide: CGFloat = 46

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        HStack(spacing: 12) {
            dateSquare
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(verbatim: row.choiceText)
                        .scaledFont(15, weight: .bold)
                        .foregroundStyle(workout == nil ? Theme.Colors.secondaryText : Theme.Colors.brightText)
                        .lineLimit(lineLimit)
                    if row.isToday {
                        CapsuleBadge(
                            text: String(localized: "HOJE"),
                            weight: .bold,
                            tracking: 0.9,
                            padding: EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6),
                            size: 9
                        )
                        .accessibilityHidden(true)
                    }
                }
                Text(detail)
                    .scaledFont(11)
                    .lineLimit(lineLimit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .scaledFont(12, weight: .semibold)
                .foregroundStyle(Theme.Colors.dimText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(row.isToday ? Theme.Colors.highlightBackground : Theme.Colors.cardBackground, in: shape)
        .overlay(shape.strokeBorder(row.isToday ? Theme.Colors.highlightBorder : Theme.Colors.cardBorder, lineWidth: 1))
        .overlay(shape.strokeBorder(Color.accentColor, lineWidth: 2).opacity(isChanged ? 1 : 0))
        .contentShape(shape)
    }

    /// Two lines at most, cut at the end; whole with the accessibility text sizes.
    private var lineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 2
    }

    /// "SEG" over "12", blue on a day with a workout.
    private var dateSquare: some View {
        VStack(spacing: 0) {
            Text(verbatim: WeeklyPlanSummary.dayAbbreviation(row.weekday))
                .scaledFont(11, weight: .heavy)
                .tracking(0.8)
            Text(verbatim: "\(dayNumber)")
                .scaledFont(15, weight: .heavy)
        }
        .foregroundStyle(workout == nil ? Theme.Colors.secondaryText : Theme.Colors.plannedDayLetter)
        .frame(width: dateSide, height: dateSide)
        .background(
            workout == nil ? Theme.Colors.unplannedDayBackground : Theme.Colors.plannedDayBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    /// "2 exercícios · 6 séries" and, darker, " · Costas · Bíceps"; "Nenhum exercício ainda"; or "Sem
    /// treino neste dia".
    private var detail: AttributedString {
        guard let workout else {
            var text = AttributedString(String(localized: "Sem treino neste dia"))
            text.foregroundColor = Theme.Colors.secondaryText
            return text
        }
        return WeeklyPlanDaySheet.detail(of: workout)
    }

    /// What VoiceOver reads for a day: "sexta-feira, hoje, Push, 4 exercícios · 15 séries, Peito · Ombros ·
    /// Tríceps" or "terça-feira, descanso".
    static func accessibilityText(row: WeeklyPlanSummary.Row, workout: Workout?) -> String {
        var parts = [row.accessibilityText]
        if let workout {
            parts.append(contentsOf: WeeklyPlanDaySheet.contentParts(of: workout))
        }
        return parts.joined(separator: ", ")
    }
}

/// The sheet of one day: "Terça" (or "Sexta · hoje"), "Descanso" and every workout with what it holds,
/// the day's choice checked, and "Cancelar". Choosing saves at once and closes the sheet.
struct WeeklyPlanDaySheet: View {
    let row: WeeklyPlanSummary.Row
    let workouts: [Workout]
    /// Called with the chosen workout, or `nil` for "Descanso", once the sheet starts closing.
    let onChoose: @MainActor (Workout?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(
                    Text(verbatim: WeeklyPlanSummary.sheetTitle(weekday: row.weekday, isToday: row.isToday)),
                    explanation: Text("Escolha o treino deste dia. A mudança é salva na hora.")
                )
                options
            }
            .sheetContentPadding()
        } bottom: {
            SheetButton(Text("Cancelar"), kind: .secondary) {
                dismiss()
            }
            .accessibilityIdentifier("plan.sheet.cancel")
            .sheetButtonBar()
        }
    }

    /// "Descanso" and the workouts in one block, a line between them.
    private var options: some View {
        VStack(spacing: 0) {
            option(
                title: String(localized: "Descanso"),
                detail: AttributedString(String(localized: "Sem treino neste dia")),
                spoken: [String(localized: "Descanso"), String(localized: "Sem treino neste dia")],
                isSelected: row.workoutID == nil,
                identifier: "plan.option.rest"
            ) {
                choose(nil)
            }
            ForEach(workouts) { workout in
                Theme.Colors.rowSeparator
                    .frame(height: 1)
                    .accessibilityHidden(true)
                option(
                    title: workout.name,
                    detail: Self.detail(of: workout),
                    spoken: [workout.name] + Self.contentParts(of: workout),
                    isSelected: row.workoutID == workout.id,
                    identifier: "plan.option.\(workout.name)"
                ) {
                    choose(workout)
                }
            }
        }
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func option(
        title: String,
        detail: AttributedString,
        spoken: [String],
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: title)
                        .scaledFont(15, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                    Text(detail)
                        .scaledFont(11)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .scaledFont(13, weight: .bold)
                        .foregroundStyle(Theme.Colors.lightAccent)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spoken.joined(separator: ", ")))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }

    /// Choosing the day's own choice again only closes the sheet.
    private func choose(_ workout: Workout?) {
        dismiss()
        if workout?.id != row.workoutID {
            onChoose(workout)
        }
    }

    /// "4 exercícios · 15 séries" and, darker, " · Peito · Ombros · Tríceps"; "Nenhum exercício ainda" for a
    /// workout without exercises.
    static func detail(of workout: Workout) -> AttributedString {
        guard !workout.exercises.isEmpty else {
            var text = AttributedString(String(localized: "Nenhum exercício ainda"))
            text.foregroundColor = Theme.Colors.secondaryText
            return text
        }
        var text = AttributedString(WorkoutListSummary.cardSummary(for: workout))
        text.foregroundColor = Theme.Colors.secondaryText
        let groups = WorkoutListSummary.muscleGroupsText(WorkoutListSummary.muscleGroups(of: workout))
        if !groups.isEmpty {
            var groupsText = AttributedString(" · \(groups)")
            groupsText.foregroundColor = Theme.Colors.dimText
            text += groupsText
        }
        return text
    }

    /// What VoiceOver reads after a workout's name: "4 exercícios · 15 séries", "Peito · Ombros ·
    /// Tríceps"; "Nenhum exercício ainda".
    static func contentParts(of workout: Workout) -> [String] {
        guard !workout.exercises.isEmpty else { return [String(localized: "Nenhum exercício ainda")] }
        let groups = WorkoutListSummary.muscleGroupsText(WorkoutListSummary.muscleGroups(of: workout))
        return [WorkoutListSummary.cardSummary(for: workout)] + (groups.isEmpty ? [] : [groups])
    }
}
