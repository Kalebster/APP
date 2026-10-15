import SwiftData
import SwiftUI

/// "Programação semanal": the seven days of the week, Monday to Sunday, each with a workout or
/// "Descanso". A day has at most one workout; the same workout can be on several days. Every choice
/// is saved right away, through `WeeklyPlanService`.
struct WeeklyPlanView: View {
    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    /// The weekly plan: at most seven records, so all of them are read.
    @Query private var plan: [WeeklyPlanDay]

    @Environment(\.modelContext) private var context
    /// The moment "Hoje" is shown for; follows the day, as the Home does.
    @State private var now = Date.now
    @State private var errorMessage: String?

    var body: some View {
        let rows = WeeklyPlanSummary.rows(
            plan: plan,
            workouts: workouts,
            todayWeekday: TrainingDay.planWeekday(of: now, calendar: TrainingDay.calendar)
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
                Text("Escolha um treino para cada dia. A programação não impede treinos em outros dias.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(rows) { row in
                    WeeklyPlanDayRow(row: row, workouts: workouts) { workout in
                        choose(workout, for: row.weekday)
                    }
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .screenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.screen")
        .navigationTitle("Programação semanal")
        .updatingCurrentDate($now)
        .errorAlert($errorMessage)
    }

    /// Plans `workout` for the day, or makes it a rest day when there is none.
    private func choose(_ workout: Workout?, for weekday: Int) {
        let service = WeeklyPlanService(context: context)
        do {
            if let workout {
                try service.setWorkout(workout, for: weekday)
            } else {
                try service.clear(weekday: weekday)
            }
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// One day: its name, a "hoje" mark for today and its choice. Tapping it opens a menu with "Descanso"
/// and every workout, the current choice checked. VoiceOver reads the day, "hoje" for today and the
/// choice.
private struct WeeklyPlanDayRow: View {
    let row: WeeklyPlanSummary.Row
    let workouts: [Workout]
    /// Called with the chosen workout, or `nil` for "Descanso".
    let onChoose: @MainActor (Workout?) -> Void

    var body: some View {
        Menu {
            Button {
                onChoose(nil)
            } label: {
                option(String(localized: "Descanso"), isSelected: row.workoutID == nil)
            }
            .accessibilityAddTraits(row.workoutID == nil ? .isSelected : [])

            ForEach(workouts) { workout in
                let isSelected = row.workoutID == workout.id
                Button {
                    onChoose(workout)
                } label: {
                    option(workout.name, isSelected: isSelected)
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        } label: {
            content
                .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.accessibilityText)
        .accessibilityHint(Text("Abre as opções de treino deste dia."))
        .accessibilityIdentifier(row.isToday ? "plan.today" : "plan.day")
    }

    private var content: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.dayName)
                        .font(.headline)
                    if row.isToday {
                        Text("hoje")
                            .textCase(.uppercase)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.fill.tertiary, in: Capsule())
                    }
                }
                Text(row.choiceText)
                    .font(.subheadline)
                    .foregroundStyle(row.workoutName == nil ? Color.secondary : Color.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(Color.primary)
    }

    /// A menu option: its name, with a check when it is the day's choice.
    @ViewBuilder
    private func option(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
