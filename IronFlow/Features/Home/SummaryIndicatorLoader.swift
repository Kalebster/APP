import Foundation
import SwiftData

/// Reads, for the indicators asked only, the records of their period, and returns what each shows
/// (`SummaryIndicators`). The month reads the month; the week's load and time read the week; the last
/// workout reads one session; the change of the weight reads the last 30 days; the sequence reads the
/// weeks back a few at a time and stops at the first one below the goal. Peso, Altura, Meta and TMB
/// read nothing: their data comes in `Known`.
@MainActor
struct SummaryIndicatorLoader {
    /// What the Início already holds: the latest body weight, the profile and the weekly plan's goal.
    struct Known {
        var latestWeightKg: Double?
        var profile: UserProfile?
        /// Days of the weekly plan with a workout that exists; 0 without a plan.
        var planGoal: Int
    }

    let context: ModelContext
    let now: Date
    let calendar: Calendar

    /// Weeks read at a time by the sequence.
    static let streakBatchWeeks = 8

    /// The value of each of `metrics`.
    func values(for metrics: [SummaryMetric], known: Known) throws -> [SummaryMetric: IndicatorValue] {
        var values: [SummaryMetric: IndicatorValue] = [:]
        // The load and the time of the week read the same sessions.
        var weekSessions: [Session]?
        func sessionsOfTheWeek() throws -> [Session] {
            if let weekSessions { return weekSessions }
            let week = WeekSummary.week(containing: now, calendar: calendar)
            let sessions = try finishedSessions(from: week.start, to: week.end)
            weekSessions = sessions
            return sessions
        }

        for metric in metrics {
            switch metric {
            case .monthWorkouts:
                let month = SummaryIndicators.month(of: now, calendar: calendar)
                let count = SummaryIndicators.workoutCount(
                    sessionCount: try finishedSessionCount(from: month.start, to: month.end),
                    markedDays: try markedDays(from: month.start, to: month.end)
                )
                values[metric] = SummaryIndicators.monthWorkouts(count: count, month: calendar.component(.month, from: now))
            case .streak:
                values[metric] = try SummaryIndicators.streak(weeks: known.planGoal > 0 ? streakWeeks(goal: known.planGoal) : nil)
            case .weekVolume:
                let sets = try sessionsOfTheWeek().flatMap { $0.exercises.flatMap(\.setLogs) }
                values[metric] = SummaryIndicators.weekVolume(kg: SessionProgress.volumeKg(of: sets))
            case .weekTime:
                let seconds = try sessionsOfTheWeek().reduce(0.0) { $0 + ($1.duration ?? 0) }
                values[metric] = SummaryIndicators.weekTime(seconds: seconds)
            case .lastWorkout:
                let last = try lastFinishedSession()
                values[metric] = SummaryIndicators.lastWorkout(
                    name: last.map { SessionFormatting.name($0.workoutNameSnapshot) },
                    startedAt: last?.startedAt,
                    now: now,
                    calendar: calendar
                )
            case .bodyWeight:
                values[metric] = SummaryIndicators.bodyWeight(known.latestWeightKg)
            case .height:
                values[metric] = SummaryIndicators.height(known.profile?.heightCm)
            case .dailyCalorieGoal:
                values[metric] = SummaryIndicators.calorieGoal(known.profile?.dailyCalorieGoalKcal)
            case .bmr:
                let inputs = BMRCalculator.inputs(profile: known.profile, weightKg: known.latestWeightKg)
                values[metric] = SummaryIndicators.bmr(BMRCalculator.estimate(inputs, now: now, calendar: calendar))
            case .weightChange:
                values[metric] = SummaryIndicators.weightChange(try weightChange())
            }
        }
        return values
    }

    // MARK: - Reading

    /// Finished sessions started from `start` to `end`, not included.
    private func finishedSessions(from start: Date, to end: Date) throws -> [Session] {
        try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { session in
            session.endedAt != nil && session.startedAt >= start && session.startedAt < end
        }))
    }

    private func finishedSessionCount(from start: Date, to end: Date) throws -> Int {
        try context.fetchCount(FetchDescriptor<Session>(predicate: #Predicate { session in
            session.endedAt != nil && session.startedAt >= start && session.startedAt < end
        }))
    }

    /// The days marked as trained outside the app from `start` to `end`, not included: at most a few
    /// weeks, looked up by the keys of their days, as the week's card does.
    private func markedDays(from start: Date, to end: Date) throws -> [String] {
        var keys: [String] = []
        var day = calendar.startOfDay(for: start)
        while day < end {
            keys.append(TrainingDay.key(for: day, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = calendar.startOfDay(for: next)
        }
        let dayKeys = keys
        return try context.fetch(FetchDescriptor<ExternalWorkoutDay>(predicate: #Predicate { marking in
            dayKeys.contains(marking.day)
        }))
        .map(\.day)
    }

    /// The finished session that started last.
    private func lastFinishedSession() throws -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// The change of the body weight in the last 30 days, today included.
    private func weightChange() throws -> Double? {
        let start = SummaryIndicators.last30DaysStart(now: now, calendar: calendar)
        let end = TrainingDay.dayInterval(of: now, calendar: calendar).end
        let entries = try context.fetch(FetchDescriptor<BodyWeightEntry>(predicate: #Predicate { entry in
            entry.measuredAt >= start && entry.measuredAt < end
        }))
        return SummaryIndicators.weightChange(of: entries.map { (measuredAt: $0.measuredAt, weightKg: $0.weightKg) })
    }

    /// The weeks in a row that reached `goal`, read `streakBatchWeeks` at a time from the current week
    /// back, each counted like the week's ring, and only until the first week below the goal.
    private func streakWeeks(goal: Int) throws -> Int {
        var counts: [Int] = []
        // The Monday of the most recent week of the next group to read.
        var newestMonday = WeekSummary.week(containing: now, calendar: calendar).start
        while true {
            guard let oldestMonday = calendar.date(byAdding: .weekOfYear, value: 1 - Self.streakBatchWeeks, to: newestMonday),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: newestMonday) else { break }
            let sessions = try finishedSessions(from: oldestMonday, to: end)
            let marked = Set(try markedDays(from: oldestMonday, to: end))
            for offset in 0..<Self.streakBatchWeeks {
                guard let monday = calendar.date(byAdding: .weekOfYear, value: -offset, to: newestMonday) else { break }
                let week = WeekSummary.week(containing: monday, calendar: calendar)
                let sessionCount = sessions.count(where: { $0.startedAt >= week.start && $0.startedAt < week.end })
                counts.append(sessionCount + marked.intersection(week.keys).count)
                if !SummaryIndicators.streakContinues(weekCounts: counts, goal: goal) {
                    return SummaryIndicators.streak(weekCounts: counts, goal: goal)
                }
            }
            // A group without a single workout ends the sequence above (its weeks are below the goal),
            // so the loop always ends.
            guard let next = calendar.date(byAdding: .weekOfYear, value: -Self.streakBatchWeeks, to: newestMonday) else { break }
            newestMonday = next
        }
        return SummaryIndicators.streak(weekCounts: counts, goal: goal)
    }
}
