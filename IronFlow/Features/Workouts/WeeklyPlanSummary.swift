import Foundation

/// The weekly plan as the screens show it: one row per weekday, the count of planned days and the
/// workout planned for a day. Pure logic: no UI and no store access.
///
/// A day whose workout no longer exists is a rest day everywhere here. When a weekday holds more than
/// one record (which the service never creates), the oldest is the one in use, as in the service.
enum WeeklyPlanSummary {
    /// One weekday of the plan: its workout, or a rest day.
    struct Row: Equatable, Identifiable, Sendable {
        /// 1 = Monday to 7 = Sunday.
        let weekday: Int
        /// "Segunda-feira".
        let dayName: String
        /// `nil` on a rest day.
        let workoutID: UUID?
        let workoutName: String?
        let isToday: Bool

        var id: Int { weekday }

        /// The workout's name, or "Descanso".
        var choiceText: String {
            workoutName ?? String(localized: "Descanso")
        }

        /// What VoiceOver reads: the day, "hoje" for today, and the choice. Examples:
        /// "segunda-feira, Push" and "quarta-feira, hoje, descanso".
        var accessibilityText: String {
            let choice = workoutName ?? String(localized: "Descanso").lowercased()
            let parts = isToday
                ? [dayName.lowercased(), String(localized: "hoje"), choice]
                : [dayName.lowercased(), choice]
            return parts.joined(separator: ", ")
        }
    }

    /// "Segunda-feira" to "Domingo" for 1 to 7.
    static func dayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: String(localized: "Segunda-feira")
        case 2: String(localized: "Terça-feira")
        case 3: String(localized: "Quarta-feira")
        case 4: String(localized: "Quinta-feira")
        case 5: String(localized: "Sexta-feira")
        case 6: String(localized: "Sábado")
        case 7: String(localized: "Domingo")
        default: ""
        }
    }

    /// The `id` of the workout planned for `weekday`, whether or not that workout still exists.
    static func scheduledWorkoutID(plan: [WeeklyPlanDay], weekday: Int) -> UUID? {
        plan.filter { $0.weekday == weekday }
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }?
            .workoutID
    }

    /// The workout planned for each weekday that has one that exists; the other days are rest days.
    static func workoutsByWeekday(plan: [WeeklyPlanDay], workouts: [Workout]) -> [Int: Workout] {
        let byID = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [Int: Workout] = [:]
        for weekday in TrainingDay.planWeekdays {
            if let id = scheduledWorkoutID(plan: plan, weekday: weekday), let workout = byID[id] {
                result[weekday] = workout
            }
        }
        return result
    }

    /// The seven days, Monday to Sunday. `todayWeekday` is today's weekday from 1 to 7
    /// (`TrainingDay.planWeekday(of:calendar:)`).
    static func rows(plan: [WeeklyPlanDay], workouts: [Workout], todayWeekday: Int) -> [Row] {
        let planned = workoutsByWeekday(plan: plan, workouts: workouts)
        return TrainingDay.planWeekdays.map { weekday in
            Row(
                weekday: weekday,
                dayName: dayName(weekday),
                workoutID: planned[weekday]?.id,
                workoutName: planned[weekday]?.name,
                isToday: weekday == todayWeekday
            )
        }
    }

    /// How many weekdays have a workout that exists.
    static func plannedDayCount(plan: [WeeklyPlanDay], workouts: [Workout]) -> Int {
        workoutsByWeekday(plan: plan, workouts: workouts).count
    }

    /// "Nenhum dia programado", "1 dia programado", "3 dias programados". The singular and the none
    /// case are chosen here: the Portuguese plural rules treat 0 as singular, which would read "0 dia".
    static func summaryText(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "Nenhum dia programado")
        case 1: String(localized: "1 dia programado")
        default: String(localized: "\(count) dias programados")
        }
    }
}
