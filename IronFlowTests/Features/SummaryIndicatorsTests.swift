import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The ten indicators of the "Resumo rápido": their texts, their periods, how the sequence of weeks is
/// counted, and that only the indicators asked are read.
@MainActor
struct SummaryIndicatorsTests {
    static let saoPaulo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        return calendar
    }()

    /// Tuesday, 27 October 2026, at noon in São Paulo. Its week runs from Monday the 26th to Sunday,
    /// 1 November.
    static let now = moment(2026, 10, 27, 12, 0)

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    // MARK: - Texts

    @Test("Treinos no mês: the count and the current month's name")
    func monthWorkoutsTexts() {
        let october = SummaryIndicators.monthWorkouts(count: 8, month: 10)
        #expect(october == IndicatorValue(value: "8", unit: nil, caption: "Treinos em out", line: "8 treinos em outubro", spoken: "8 treinos em outubro"))
        #expect(SummaryIndicators.monthWorkouts(count: 1, month: 10).line == "1 treino em outubro")
        #expect(SummaryIndicators.monthWorkouts(count: 0, month: 10).line == "0 treinos em outubro")
        #expect(SummaryIndicators.monthWorkouts(count: 0, month: 10).value == "0")
        #expect(SummaryIndicators.monthWorkouts(count: 3, month: 5).caption == "Treinos em mai")
        #expect(SummaryIndicators.monthWorkouts(count: 3, month: 5).line == "3 treinos em maio")
        #expect(SummaryIndicators.monthWorkoutsExplanation(month: 10) == "Treinos concluídos em outubro")
    }

    @Test("Sequência: weeks in a row on the goal, and what to do without a weekly plan")
    func streakTexts() {
        #expect(SummaryIndicators.streak(weeks: 4) == IndicatorValue(value: "4 sem.", unit: nil, caption: "Na meta", line: "4 semanas seguidas batendo a meta", spoken: "4 semanas seguidas batendo a meta"))
        #expect(SummaryIndicators.streak(weeks: 1).line == "1 semana seguida batendo a meta")
        #expect(SummaryIndicators.streak(weeks: 0).value == "0 sem.")
        #expect(SummaryIndicators.streak(weeks: 0).line == "0 semanas seguidas batendo a meta")
        let withoutPlan = SummaryIndicators.streak(weeks: nil)
        #expect(withoutPlan.value == nil)
        #expect(withoutPlan.caption == "Na meta")
        #expect(withoutPlan.line == "Monte a Programação semanal para ter uma meta")
    }

    @Test("Kg na semana and Tempo na semana")
    func weekTexts() {
        #expect(SummaryIndicators.weekVolume(kg: 14_250) == IndicatorValue(value: "14.250", unit: nil, caption: "kg na semana", line: "Só séries válidas e de falha", spoken: "14.250 kg na semana"))
        #expect(SummaryIndicators.weekVolume(kg: 0).value == "0")
        #expect(SummaryIndicators.weekVolume(kg: 1_399.6).value == "1.400")

        #expect(SummaryIndicators.weekTime(seconds: 103 * 60) == IndicatorValue(value: "1h43", unit: nil, caption: "Treinando", line: "1 h 43 min treinando esta semana", spoken: "1 h 43 min treinando esta semana"))
        #expect(SummaryIndicators.weekTime(seconds: 0).value == "0h00")
        #expect(SummaryIndicators.weekTime(seconds: 0).line == "0 min treinando esta semana")
        #expect(SummaryIndicators.weekTime(seconds: 45 * 60).value == "0h45")
        #expect(SummaryIndicators.weekTime(seconds: 45 * 60).line == "45 min treinando esta semana")
        #expect(SummaryIndicators.weekTime(seconds: 120 * 60).value == "2h00")
        #expect(SummaryIndicators.weekTime(seconds: 120 * 60).line == "2 h treinando esta semana")
        #expect(SummaryIndicators.weekTime(seconds: 65 * 60).value == "1h05")
        #expect(SummaryIndicators.weekTime(seconds: 65 * 60).line == "1 h 5 min treinando esta semana")
        // Rounded once, for the whole week: two sessions of 29,5 minutes are 59 minutes.
        #expect(SummaryIndicators.weekTime(seconds: 2 * 29.5 * 60).value == "0h59")
    }

    @Test("Último treino: the name and the day, today, yesterday or the date")
    func lastWorkoutTexts() {
        let calendar = Self.saoPaulo
        let yesterday = SummaryIndicators.lastWorkout(name: "Pernas", startedAt: Self.moment(2026, 10, 26, 19, 0), now: Self.now, calendar: calendar)
        #expect(yesterday == IndicatorValue(value: "Pernas", unit: nil, caption: "ontem", line: "Pernas · ontem", spoken: "Pernas, ontem"))
        #expect(SummaryIndicators.lastWorkout(name: "Push", startedAt: Self.moment(2026, 10, 27, 7, 0), now: Self.now, calendar: calendar).caption == "hoje")
        #expect(SummaryIndicators.lastWorkout(name: "Push", startedAt: Self.moment(2026, 10, 14, 7, 0), now: Self.now, calendar: calendar).line == "Push · 14 out")
        #expect(SummaryIndicators.lastWorkout(name: "Push", startedAt: Self.moment(2025, 10, 14, 7, 0), now: Self.now, calendar: calendar).caption == "14 out 2025")
        // Across the turn of the month, in the device's time zone.
        let november = Self.moment(2026, 11, 1, 0, 30)
        #expect(SummaryIndicators.lastWorkout(name: "Push", startedAt: Self.moment(2026, 10, 31, 23, 0), now: november, calendar: calendar).caption == "ontem")

        let none = SummaryIndicators.lastWorkout(name: nil, startedAt: nil, now: Self.now, calendar: calendar)
        #expect(none.value == nil)
        #expect(none.caption == "Último treino")
        #expect(none.line == "Nenhum treino concluído ainda")
    }

    @Test("Peso, Altura and Meta de calorias, with and without a value")
    func bodyTexts() {
        #expect(SummaryIndicators.bodyWeight(80) == IndicatorValue(value: "80", unit: "kg", caption: "Peso", line: "80 kg · o último registro", spoken: "80 kg"))
        #expect(SummaryIndicators.bodyWeight(80.6).value == "80,6")
        #expect(SummaryIndicators.bodyWeight(nil).value == nil)
        #expect(SummaryIndicators.bodyWeight(nil).line == "Nenhum registro ainda")

        #expect(SummaryIndicators.height(180) == IndicatorValue(value: "180", unit: "cm", caption: "Altura", line: "180 cm", spoken: "180 cm"))
        #expect(SummaryIndicators.height(nil).line == "Não informada")

        #expect(SummaryIndicators.calorieGoal(2_300) == IndicatorValue(value: "2.300", unit: nil, caption: "kcal / dia", line: "2.300 kcal por dia", spoken: "2.300 kcal"))
        #expect(SummaryIndicators.calorieGoal(nil).value == nil)
        #expect(SummaryIndicators.calorieGoal(nil).line == "Não informada")
    }

    @Test("TMB: the value, or the calculator's message of what is missing")
    func bmrTexts() {
        let estimate = BMRCalculator.Estimate(bmrKcal: 1_780, expenditureKcal: 2_760, goalKcal: 2_360)
        #expect(SummaryIndicators.bmr(.success(estimate)) == IndicatorValue(value: "1.780", unit: nil, caption: "TMB (kcal)", line: "1.780 kcal · o que o corpo gasta parado", spoken: "1.780 kcal"))
        let missing = SummaryIndicators.bmr(.failure(.sexAndBirthDate))
        #expect(missing.value == nil)
        #expect(missing.caption == "TMB · calcular")
        #expect(missing.line == "Escolha o sexo e a data de nascimento para ver o resultado.")
        #expect(SummaryIndicators.bmr(.failure(.bodyData)).line == "Registre o seu peso e a sua altura para calcular.")
        #expect(SummaryIndicators.bmr(.failure(.ageOutOfRange)).line == "Confira a data de nascimento: a calculadora vale de 15 a 100 anos.")
    }

    @Test("Variação do peso: the change with its sign, exactly zero, or fewer than two records")
    func weightChangeTexts() {
        #expect(SummaryIndicators.weightChange(-1.2) == IndicatorValue(value: "\u{2212}1,2", unit: "kg", caption: "Peso em 30 dias", line: "\u{2212}1,2 kg nos últimos 30 dias", spoken: "\u{2212}1,2 kg nos últimos 30 dias"))
        #expect(SummaryIndicators.weightChange(0.4).value == "+0,4")
        #expect(SummaryIndicators.weightChange(0).value == "0")
        #expect(SummaryIndicators.weightChange(0).line == "0 kg nos últimos 30 dias")
        let none = SummaryIndicators.weightChange(nil)
        #expect(none.value == nil)
        #expect(none.line == "Registre o peso mais vezes para ver a variação")
    }

    // MARK: - Rules

    @Test("The sequence counts back from the current week, which only counts once it reaches the goal")
    func streakRule() {
        #expect(SummaryIndicators.streak(weekCounts: [4, 4, 4, 3], goal: 4) == 3)
        // The current week below the goal does not break the sequence.
        #expect(SummaryIndicators.streak(weekCounts: [2, 4, 5, 1, 4], goal: 4) == 2)
        #expect(SummaryIndicators.streak(weekCounts: [4, 4, 0], goal: 4) == 2)
        #expect(SummaryIndicators.streak(weekCounts: [2], goal: 4) == 0)
        #expect(SummaryIndicators.streak(weekCounts: [0, 0], goal: 1) == 0)
        #expect(SummaryIndicators.streak(weekCounts: [], goal: 3) == 0)
        #expect(SummaryIndicators.streak(weekCounts: [5, 5], goal: 0) == 0)

        #expect(SummaryIndicators.streakContinues(weekCounts: [0], goal: 2))
        #expect(SummaryIndicators.streakContinues(weekCounts: [0, 2, 3], goal: 2))
        #expect(!SummaryIndicators.streakContinues(weekCounts: [2, 2, 1], goal: 2))
        #expect(!SummaryIndicators.streakContinues(weekCounts: [2], goal: 0))
    }

    @Test("The change of the weight is the latest record minus the oldest; one record is not enough")
    func weightChangeRule() {
        let early = Self.moment(2026, 10, 1, 8, 0)
        let late = Self.moment(2026, 10, 27, 8, 0)
        #expect(SummaryIndicators.weightChange(of: []) == nil)
        #expect(SummaryIndicators.weightChange(of: [(measuredAt: late, weightKg: 80)]) == nil)
        let change = SummaryIndicators.weightChange(of: [(measuredAt: late, weightKg: 79.4), (measuredAt: early, weightKg: 80.6)])
        #expect(change.map(HomeSummary.signedNumber) == "\u{2212}1,2")
    }

    @Test("The periods: the month of the device's calendar and the last 30 days, today included")
    func periods() {
        let month = SummaryIndicators.month(of: Self.now, calendar: Self.saoPaulo)
        #expect(month.start == Self.moment(2026, 10, 1, 0, 0))
        #expect(month.end == Self.moment(2026, 11, 1, 0, 0))
        #expect(SummaryIndicators.last30DaysStart(now: Self.now, calendar: Self.saoPaulo) == Self.moment(2026, 9, 28, 0, 0))
    }

    @Test("Peso, Altura and Meta open their editor, TMB the calculator; the others say what they are")
    func cardActions() {
        #expect(SummaryMetric.bodyWeight.cardAction(month: 10) == .edit(.bodyWeight))
        #expect(SummaryMetric.height.cardAction(month: 10) == .edit(.height))
        #expect(SummaryMetric.dailyCalorieGoal.cardAction(month: 10) == .edit(.dailyCalorieGoal))
        #expect(SummaryMetric.bmr.cardAction(month: 10) == .calculateBMR)
        #expect(SummaryMetric.monthWorkouts.cardAction(month: 10) == .explain("Treinos concluídos em outubro"))
        #expect(SummaryMetric.streak.cardAction(month: 10) == .explain("Semanas seguidas em que você bateu a meta da programação"))
        #expect(SummaryMetric.weekVolume.cardAction(month: 10) == .explain("Soma das séries válidas e de falha desta semana"))
        #expect(SummaryMetric.weekTime.cardAction(month: 10) == .explain("Tempo dos treinos concluídos nesta semana"))
        #expect(SummaryMetric.lastWorkout.cardAction(month: 10) == .explain("O último treino concluído"))
        #expect(SummaryMetric.weightChange.cardAction(month: 10) == .explain("Calculado com os seus registros de peso"))
    }

    // MARK: - Reading the store

    @Test("An empty store: no workout, no record, every value at zero or missing")
    func emptyStore() throws {
        let values = try loader().values(for: SummaryMetric.allCases, known: .init(latestWeightKg: nil, profile: nil, planGoal: 0))
        #expect(values.count == 10)
        #expect(values[.monthWorkouts]?.line == "0 treinos em outubro")
        #expect(values[.streak]?.line == "Monte a Programação semanal para ter uma meta")
        #expect(values[.weekVolume]?.value == "0")
        #expect(values[.weekTime]?.value == "0h00")
        #expect(values[.lastWorkout]?.line == "Nenhum treino concluído ainda")
        #expect(values[.bodyWeight]?.value == nil)
        #expect(values[.height]?.line == "Não informada")
        #expect(values[.dailyCalorieGoal]?.line == "Não informada")
        #expect(values[.bmr]?.line == "Registre o seu peso e a sua altura para calcular.")
        #expect(values[.weightChange]?.value == nil)

        // With a plan and no workout yet: zero weeks.
        let planned = try loader().values(for: [.streak], known: .init(latestWeightKg: nil, profile: nil, planGoal: 3))
        #expect(planned[.streak]?.value == "0 sem.")
    }

    @Test("Only the indicators asked are read")
    func onlyTheAskedIndicators() throws {
        let values = try loader().values(for: [.height, .weekTime], known: .init(latestWeightKg: 80, profile: nil, planGoal: 2))
        #expect(Set(values.keys) == [.height, .weekTime])
    }

    @Test("The month's workouts: finished sessions of the month and the days marked outside the app, each day once")
    func monthWorkoutsFromTheStore() throws {
        finished("A", at: Self.moment(2026, 10, 1, 0, 10))
        finished("B", at: Self.moment(2026, 10, 15, 19, 0))
        // 23:30 in São Paulo on the 31st is already 1 November in UTC: still October here.
        finished("C", at: Self.moment(2026, 10, 31, 23, 30))
        // Outside the month: the day before and the day after, and a session still in progress.
        finished("D", at: Self.moment(2026, 9, 30, 23, 50))
        finished("E", at: Self.moment(2026, 11, 1, 8, 0))
        context.insert(Session(startedAt: Self.moment(2026, 10, 20, 8, 0), workoutNameSnapshot: "Aberto"))
        for day in ["2026-10-05", "2026-10-05", "2026-10-15", "2026-09-30", "2026-11-01"] {
            context.insert(ExternalWorkoutDay(day: day))
        }
        try context.save()

        let values = try loader().values(for: [.monthWorkouts], known: .init(latestWeightKg: nil, profile: nil, planGoal: 0))
        #expect(values[.monthWorkouts]?.value == "5")
        #expect(values[.monthWorkouts]?.line == "5 treinos em outubro")
    }

    @Test("The sequence reads back week by week, past a group of weeks, and stops at the first one below the goal")
    func streakFromTheStore() throws {
        // A goal of 2: the current week has 1 so far, which does not break the sequence; the ten weeks
        // before it have 2 each (one of them with a day marked outside the app); the one before has 1.
        let currentMonday = Self.moment(2026, 10, 26, 0, 0)
        finished("Hoje", at: Self.moment(2026, 10, 27, 7, 0))
        for weeksBack in 1...10 {
            let monday = try #require(Self.saoPaulo.date(byAdding: .weekOfYear, value: -weeksBack, to: currentMonday))
            finished("A", at: monday.addingTimeInterval(8 * 3_600))
            if weeksBack == 4 {
                context.insert(ExternalWorkoutDay(day: TrainingDay.key(for: monday.addingTimeInterval(2 * 86_400), calendar: Self.saoPaulo)))
            } else {
                finished("B", at: monday.addingTimeInterval(3 * 86_400))
            }
        }
        let eleventh = try #require(Self.saoPaulo.date(byAdding: .weekOfYear, value: -11, to: currentMonday))
        finished("A", at: eleventh.addingTimeInterval(8 * 3_600))
        let twelfth = try #require(Self.saoPaulo.date(byAdding: .weekOfYear, value: -12, to: currentMonday))
        finished("A", at: twelfth)
        finished("B", at: twelfth.addingTimeInterval(3_600))
        try context.save()

        let known = SummaryIndicatorLoader.Known(latestWeightKg: nil, profile: nil, planGoal: 2)
        #expect(try loader().values(for: [.streak], known: known)[.streak]?.value == "10 sem.")

        // The current week reaches the goal: it counts too.
        finished("Hoje 2", at: Self.moment(2026, 10, 27, 9, 0))
        try context.save()
        #expect(try loader().values(for: [.streak], known: known)[.streak]?.value == "11 sem.")

        // A higher goal breaks the sequence at the week before the current one.
        let higher = SummaryIndicatorLoader.Known(latestWeightKg: nil, profile: nil, planGoal: 3)
        #expect(try loader().values(for: [.streak], known: higher)[.streak]?.value == "0 sem.")
    }

    @Test("The week's load and time: finished sessions of the week, only working and failure sets done")
    func weekFromTheStore() throws {
        let monday = finished("Push", at: Self.moment(2026, 10, 26, 18, 0), minutes: 61.5)
        addSet(to: monday, kg: 100, reps: 10, type: .working)
        addSet(to: monday, kg: 50, reps: 10, type: .warmup)
        addSet(to: monday, kg: 80, reps: 5, type: .failure)
        addSet(to: monday, kg: 100, reps: 10, type: .working, done: false)
        // Sunday 1 November is in this week.
        let sunday = finished("Pull", at: Self.moment(2026, 11, 1, 9, 0), minutes: 41.5)
        addSet(to: sunday, kg: 20, reps: 12, type: .working)
        // Last week and a session in progress do not count.
        let lastWeek = finished("Legs", at: Self.moment(2026, 10, 25, 18, 0), minutes: 50)
        addSet(to: lastWeek, kg: 200, reps: 10, type: .working)
        let inProgress = Session(startedAt: Self.moment(2026, 10, 27, 8, 0), workoutNameSnapshot: "Aberto")
        context.insert(inProgress)
        addSet(to: inProgress, kg: 300, reps: 10, type: .working)
        try context.save()

        let values = try loader().values(for: [.weekVolume, .weekTime], known: .init(latestWeightKg: nil, profile: nil, planGoal: 0))
        // 100 × 10 + 80 × 5 + 20 × 12.
        #expect(values[.weekVolume]?.value == "1.640")
        #expect(values[.weekTime]?.value == "1h43")
    }

    @Test("The last workout is the finished session that started last; a free one is a Treino livre")
    func lastWorkoutFromTheStore() throws {
        finished("Pernas", at: Self.moment(2026, 10, 20, 18, 0))
        finished("", at: Self.moment(2026, 10, 26, 18, 0))
        context.insert(Session(startedAt: Self.moment(2026, 10, 27, 8, 0), workoutNameSnapshot: "Aberto"))
        try context.save()

        let value = try loader().values(for: [.lastWorkout], known: .init(latestWeightKg: nil, profile: nil, planGoal: 0))[.lastWorkout]
        #expect(value?.line == "Treino livre · ontem")
    }

    @Test("The change of the weight reads today and the 29 days before it")
    func weightChangeFromTheStore() throws {
        let profile = ProfileService(context: context, now: { Self.moment(2026, 9, 27, 8, 0) }, calendar: Self.saoPaulo)
        try profile.recordWeight(90)
        #expect(try loader().values(for: [.weightChange], known: .init(latestWeightKg: 90, profile: nil, planGoal: 0))[.weightChange]?.value == nil)

        try ProfileService(context: context, now: { Self.moment(2026, 9, 28, 7, 0) }, calendar: Self.saoPaulo).recordWeight(81.4)
        // One record inside the 30 days is not enough.
        #expect(try loader().values(for: [.weightChange], known: .init(latestWeightKg: 81.4, profile: nil, planGoal: 0))[.weightChange]?.value == nil)

        try ProfileService(context: context, now: { Self.moment(2026, 10, 27, 7, 0) }, calendar: Self.saoPaulo).recordWeight(80.2)
        let value = try loader().values(for: [.weightChange], known: .init(latestWeightKg: 80.2, profile: nil, planGoal: 0))[.weightChange]
        #expect(value?.value == "\u{2212}1,2")
        #expect(value?.line == "\u{2212}1,2 kg nos últimos 30 dias")
    }

    @Test("Peso, Altura, Meta and TMB come from the latest weight and the profile")
    func bodyFromTheProfile() throws {
        let service = ProfileService(context: context, now: { Self.now }, calendar: Self.saoPaulo)
        try service.setHeight(180)
        try service.setDailyCalorieGoal(2_300)
        try service.setSex(.male)
        try service.setBirthDate(BirthDate(day: 15, month: 5, year: 1996))
        let profile = try service.profile()

        let values = try loader().values(
            for: [.bodyWeight, .height, .dailyCalorieGoal, .bmr],
            known: .init(latestWeightKg: 80, profile: profile, planGoal: 0)
        )
        #expect(values[.bodyWeight]?.line == "80 kg · o último registro")
        #expect(values[.height]?.line == "180 cm")
        #expect(values[.dailyCalorieGoal]?.line == "2.300 kcal por dia")
        #expect(values[.bmr]?.value == "1.780")
    }

    // MARK: - Support

    private func loader() -> SummaryIndicatorLoader {
        SummaryIndicatorLoader(context: context, now: Self.now, calendar: Self.saoPaulo)
    }

    @discardableResult
    private func finished(_ name: String, at start: Date, minutes: Double = 45) -> Session {
        let session = Session(startedAt: start, workoutNameSnapshot: name)
        context.insert(session)
        session.endedAt = start.addingTimeInterval(minutes * 60)
        return session
    }

    private func addSet(to session: Session, kg: Double, reps: Int, type: SetType, done: Bool = true) {
        let exercise = SessionExercise(sortIndex: session.exercises.count, exerciseNameSnapshot: "Supino Reto", muscleGroupSnapshot: .chest)
        context.insert(exercise)
        exercise.session = session
        let set = SetLog(sortIndex: 0, weightKg: kg, reps: reps, setType: type)
        context.insert(set)
        set.sessionExercise = exercise
        set.isCompleted = done
    }

    static func moment(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        saoPaulo.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }
}
