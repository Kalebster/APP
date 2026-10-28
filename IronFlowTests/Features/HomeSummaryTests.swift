import Foundation
import Testing
@testable import IronFlow

@MainActor
struct HomeSummaryTests {
    @Test("Without a saved choice the three indicators are shown in the default order")
    func defaultMetrics() {
        #expect(HomeSummary.metrics(fromStored: nil) == [.bodyWeight, .height, .dailyCalorieGoal])
        #expect(HomeSummary.defaultMetrics == [.bodyWeight, .height, .dailyCalorieGoal])
    }

    @Test("Ten indicators, the workout ones first; the keys saved by earlier versions stay the same")
    func tenIndicators() {
        #expect(SummaryMetric.allCases.map(\.rawValue) == [
            "monthWorkouts", "streak", "weekVolume", "weekTime", "lastWorkout",
            "bodyWeight", "height", "dailyCalorieGoal", "bmr", "weightChange",
        ])
        #expect(SummaryMetric.allCases.map { String(localized: $0.title) } == [
            "Treinos no mês", "Sequência", "Kg na semana", "Tempo na semana", "Último treino",
            "Peso", "Altura", "Meta de calorias", "TMB", "Variação do peso",
        ])
        #expect(SummaryMetric.allCases.filter { $0.category == .training } == [.monthWorkouts, .streak, .weekVolume, .weekTime, .lastWorkout])
        #expect(SummaryMetric.allCases.filter { $0.category == .body } == [.bodyWeight, .height, .dailyCalorieGoal, .bmr, .weightChange])
        #expect(SummaryMetric.Category.allCases.map { String(localized: $0.title) } == ["Treino", "Corpo"])
        #expect(Set(SummaryMetric.allCases.map(\.systemImage)).count == 10)
        // A choice saved before the new indicators is still read as it was.
        #expect(HomeSummary.metrics(fromStored: "height,dailyCalorieGoal") == [.height, .dailyCalorieGoal])
        #expect(HomeSummary.metrics(fromStored: "bmr,streak,bodyWeight") == [.bmr, .streak, .bodyWeight])
    }

    @Test("A saved choice keeps its order")
    func savedChoice() {
        #expect(HomeSummary.metrics(fromStored: "dailyCalorieGoal,bodyWeight") == [.dailyCalorieGoal, .bodyWeight])
        let choice: [SummaryMetric] = [.height, .dailyCalorieGoal]
        #expect(HomeSummary.metrics(fromStored: HomeSummary.storedValue(for: choice)) == choice)
    }

    @Test("An empty or entirely invalid saved value shows the defaults")
    func invalidSavedValue() {
        #expect(HomeSummary.metrics(fromStored: "") == HomeSummary.defaultMetrics)
        #expect(HomeSummary.metrics(fromStored: "abc") == HomeSummary.defaultMetrics)
        #expect(HomeSummary.metrics(fromStored: "unknown,,other") == HomeSummary.defaultMetrics)
    }

    @Test("Unknown entries are ignored when known ones are saved with them")
    func partlyInvalidSavedValue() {
        #expect(HomeSummary.metrics(fromStored: "unknown,height,abc,bodyWeight") == [.height, .bodyWeight])
    }

    @Test("Repeated entries are kept once")
    func repeatedEntries() {
        #expect(HomeSummary.metrics(fromStored: "height,height,bodyWeight,height") == [.height, .bodyWeight])
    }

    @Test("At most three indicators are kept")
    func atMostThree() {
        let stored = "dailyCalorieGoal,height,bodyWeight,dailyCalorieGoal,height"
        #expect(HomeSummary.metrics(fromStored: stored) == [.dailyCalorieGoal, .height, .bodyWeight])
    }

    @Test("Choosing no indicators is saved explicitly and shows none")
    func noIndicators() {
        #expect(HomeSummary.storedValue(for: []) == HomeSummary.noMetricsStoredValue)
        #expect(HomeSummary.metrics(fromStored: HomeSummary.noMetricsStoredValue) == [])
        #expect(HomeSummary.metrics(fromStored: HomeSummary.storedValue(for: [])) == [])
    }

    @Test("Toggling removes a shown indicator or adds it last")
    func toggle() {
        let all = HomeSummary.defaultMetrics
        #expect(HomeSummary.toggled(.height, in: all) == [.bodyWeight, .dailyCalorieGoal])
        #expect(HomeSummary.toggled(.height, in: [.bodyWeight, .dailyCalorieGoal]) == [.bodyWeight, .dailyCalorieGoal, .height])
        #expect(HomeSummary.toggled(.bodyWeight, in: []) == [.bodyWeight])
        #expect(HomeSummary.maxVisibleMetrics == 3)
    }

    @Test("Values use Brazilian formatting")
    func valueTexts() {
        #expect(HomeSummary.weightText(80) == "80 kg")
        #expect(HomeSummary.weightText(80.5) == "80,5 kg")
        #expect(HomeSummary.weightText(72.25) == "72,25 kg")
        #expect(HomeSummary.heightText(180) == "180 cm")
        #expect(HomeSummary.calorieText(800) == "800 kcal")
        #expect(HomeSummary.calorieText(2_300) == "2.300 kcal")
        #expect(HomeSummary.fieldText(nil, for: .bodyWeight) == "")
        #expect(HomeSummary.fieldText(80.5, for: .bodyWeight) == "80,5")
        #expect(HomeSummary.fieldText(80.25, for: .bodyWeight) == "80,25")
        #expect(HomeSummary.fieldText(1_000, for: .bodyWeight) == "1000")
        #expect(HomeSummary.fieldText(180, for: .height) == "180")
        #expect(HomeSummary.fieldText(2_300, for: .dailyCalorieGoal) == "2.300")
        #expect(HomeSummary.number(20) == "20")
        #expect(HomeSummary.number(8_000) == "8.000")
        #expect(HomeSummary.number(80.6) == "80,6")
    }

    @Test("Typed values are read and checked for each indicator; an empty field has no value")
    func typedValues() throws {
        #expect(try HomeSummary.value(for: .bodyWeight, text: "") == nil)
        #expect(try HomeSummary.value(for: .bodyWeight, text: "80,5") == 80.5)
        #expect(try HomeSummary.value(for: .bodyWeight, text: " 80.5 ") == 80.5)
        #expect(try HomeSummary.value(for: .bodyWeight, text: "80,25") == 80.25)
        for invalid in ["19", "301", "abc", "-80", "80,5,1"] {
            #expect(throws: ValidationError.invalidBodyWeight) { try HomeSummary.value(for: .bodyWeight, text: invalid) }
        }
        // Three or more decimals are never read as another number ("80,500" is not 80 500 g).
        for tooPrecise in ["80,123", "80,500", "80.500", "1.000"] {
            #expect(throws: ValidationError.tooManyDecimals) { try HomeSummary.value(for: .bodyWeight, text: tooPrecise) }
        }
        #expect(try HomeSummary.value(for: .height, text: "180") == 180)
        for invalid in ["99", "251", "1,8", "abc"] {
            #expect(throws: ValidationError.invalidHeight) { try HomeSummary.value(for: .height, text: invalid) }
        }
        #expect(try HomeSummary.value(for: .dailyCalorieGoal, text: "2300") == 2_300)
        #expect(try HomeSummary.value(for: .dailyCalorieGoal, text: "2.300") == 2_300)
        for invalid in ["2.30", "23.00", "799", "8001", "8.001", "99999999999999999999", "2,300"] {
            #expect(throws: ValidationError.invalidCalorieGoal) { try HomeSummary.value(for: .dailyCalorieGoal, text: invalid) }
        }
    }

    @Test("A whole number is read with or without the dots of the thousands, never with a dot out of place")
    func wholeNumbers() {
        #expect(HomeSummary.wholeNumber("2300") == 2_300)
        #expect(HomeSummary.wholeNumber("2.300") == 2_300)
        #expect(HomeSummary.wholeNumber("1.000.000") == 1_000_000)
        for invalid in ["2.30", "23.00", ".300", "2.", "2..300", "abc", "", "2.3a0"] {
            #expect(HomeSummary.wholeNumber(invalid) == nil, "\(invalid)")
        }
    }

    @Test("The editor's titles, units, lines and notices")
    func editorTexts() {
        #expect(BodyMetric.allCases.map { String(localized: $0.editorTitle) } == ["Peso corporal", "Altura", "Meta diária de calorias"])
        #expect(BodyMetric.allCases.map(\.unit) == ["kg", "cm", "kcal"])
        #expect(BodyMetric.allCases.map { $0.help.map { String(localized: $0) } } == [
            "Cada novo peso fica registrado com a data de hoje.", nil, "Quantas calorias você quer comer por dia.",
        ])
        #expect(BodyMetric.allCases.map { String(localized: $0.savedMessage) } == ["Peso salvo", "Altura salva", "Meta salva"])
        #expect(SummaryMetric.allCases.compactMap(\.bodyMetric) == [.bodyWeight, .height, .dailyCalorieGoal])
        #expect(SummaryMetric.bmr.bodyMetric == nil)
    }

    @Test("− and + step 0,1 kg, 1 cm and 50 kcal and never pass the limits")
    func steps() {
        #expect(MetricEditing.stepped(80, metric: .bodyWeight, direction: .up) == 80.1)
        #expect(MetricEditing.stepped(80, metric: .bodyWeight, direction: .down) == 79.9)
        #expect(MetricEditing.stepped(80.25, metric: .bodyWeight, direction: .up) == 80.35)
        #expect(MetricEditing.stepped(180, metric: .height, direction: .up) == 181)
        #expect(MetricEditing.stepped(2_300, metric: .dailyCalorieGoal, direction: .down) == 2_250)

        // At and past the limits.
        #expect(MetricEditing.stepped(299.95, metric: .bodyWeight, direction: .up) == 300)
        #expect(MetricEditing.stepped(20.05, metric: .bodyWeight, direction: .down) == 20)
        #expect(MetricEditing.stepped(500, metric: .bodyWeight, direction: .down) == 300)
        #expect(MetricEditing.stepped(5, metric: .bodyWeight, direction: .up) == 20)
        #expect(MetricEditing.stepped(250, metric: .height, direction: .up) == 250)
        #expect(MetricEditing.stepped(820, metric: .dailyCalorieGoal, direction: .down) == 800)
        #expect(!MetricEditing.canStep(300, metric: .bodyWeight, direction: .up))
        #expect(MetricEditing.canStep(300, metric: .bodyWeight, direction: .down))
        #expect(!MetricEditing.canStep(20, metric: .bodyWeight, direction: .down))
        #expect(!MetricEditing.canStep(100, metric: .height, direction: .down))
        #expect(!MetricEditing.canStep(8_000, metric: .dailyCalorieGoal, direction: .up))
        #expect(!MetricEditing.canStep(9_000, metric: .dailyCalorieGoal, direction: .up))
        #expect(MetricEditing.canStep(9_000, metric: .dailyCalorieGoal, direction: .down))
    }

    @Test("− and + start from the typed number, else the saved value, else 70 kg, 170 cm or 2.000 kcal")
    func stepBase() {
        #expect(MetricEditing.base(of: .bodyWeight, text: "82,5", saved: 80) == 82.5)
        #expect(MetricEditing.base(of: .bodyWeight, text: "", saved: 80) == 80)
        #expect(MetricEditing.base(of: .bodyWeight, text: "abc", saved: 80) == 80)
        #expect(MetricEditing.base(of: .bodyWeight, text: "", saved: nil) == 70)
        #expect(MetricEditing.base(of: .height, text: " ", saved: nil) == 170)
        #expect(MetricEditing.base(of: .dailyCalorieGoal, text: "", saved: nil) == 2_000)
        #expect(MetricEditing.base(of: .dailyCalorieGoal, text: "2.300", saved: 1_800) == 2_300)
        // A number beyond the limits is the start too: a step brings it back within them.
        #expect(MetricEditing.base(of: .bodyWeight, text: "500", saved: 80) == 500)
    }

    @Test("ÚLTIMOS REGISTROS: the date, the value and the change from the record below; the oldest has none")
    func weightRecords() throws {
        let container = try ModelContainerFactory.makeInMemory()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        func entry(_ weightKg: Double, day: Int) throws -> BodyWeightEntry {
            let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 7)))
            let entry = BodyWeightEntry(weightKg: weightKg, measuredAt: date)
            container.mainContext.insert(entry)
            return entry
        }
        let entries = [try entry(80, day: 13), try entry(80.6, day: 9), try entry(81.2, day: 2)]
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 12)))

        let rows = HomeSummary.weightRecordRows(entries, now: now, calendar: calendar)
        #expect(rows.map(\.dateText) == ["Ter, 13 out", "Sex, 9 out", "Sex, 2 out"])
        #expect(rows.map(\.valueText) == ["80 kg", "80,6 kg", "81,2 kg"])
        #expect(rows.map(\.changeText) == ["\u{2212}0,6", "\u{2212}0,6", nil])
        #expect(HomeSummary.weightRecordRows(Array(entries.prefix(1)), now: now, calendar: calendar).map(\.changeText) == [nil])
        #expect(HomeSummary.weightRecordRows([], now: now, calendar: calendar).isEmpty)
    }

    @Test("A change has its sign and the typographic minus, without the remainders of binary arithmetic")
    func signedNumbers() {
        #expect(HomeSummary.signedNumber(-0.6) == "\u{2212}0,6")
        #expect(HomeSummary.signedNumber(80 - 80.6) == "\u{2212}0,6")
        #expect(HomeSummary.signedNumber(0.4) == "+0,4")
        #expect(HomeSummary.signedNumber(1.25) == "+1,25")
        #expect(HomeSummary.signedNumber(-12) == "\u{2212}12")
        #expect(HomeSummary.signedNumber(0) == "0")
        #expect(HomeSummary.signedNumber(0.001) == "0")
    }

    @Test("Today's workout: a session in progress first, then whether workouts exist")
    func todayWorkoutState() {
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: false) == .noWorkouts)
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true) == .nothingPlanned)

        let older = Session(startedAt: Date(timeIntervalSinceReferenceDate: 1_000), workoutNameSnapshot: "Push")
        let newer = Session(startedAt: Date(timeIntervalSinceReferenceDate: 2_000), workoutNameSnapshot: "Pull")
        #expect(TodayWorkoutState.resolve(activeSessions: [older, newer], hasWorkouts: false)
            == .inProgress(name: "Pull", startedAt: Date(timeIntervalSinceReferenceDate: 2_000)))

        // Started at the same moment: the most recently created, as "Continuar" opens it.
        let first = Session(startedAt: Date(timeIntervalSinceReferenceDate: 3_000), workoutNameSnapshot: "Legs")
        first.createdAt = Date(timeIntervalSinceReferenceDate: 3_000)
        let second = Session(startedAt: Date(timeIntervalSinceReferenceDate: 3_000), workoutNameSnapshot: "Arms")
        second.createdAt = Date(timeIntervalSinceReferenceDate: 3_001)
        for sessions in [[first, second], [second, first]] {
            #expect(TodayWorkoutState.resolve(activeSessions: sessions, hasWorkouts: true)
                == .inProgress(name: "Arms", startedAt: Date(timeIntervalSinceReferenceDate: 3_000)))
        }
    }

    @Test("Today's workout start: the time for today, the day first for an earlier day")
    func startedText() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 21)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 19, minute: 30)))
        let earlier = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 19, minute: 30)))

        #expect(HomeSummary.startedText(today, now: now, calendar: calendar) == "Iniciado às 19:30")
        let earlierText = HomeSummary.startedText(earlier, now: now, calendar: calendar)
        #expect(earlierText.hasPrefix("Iniciado em 4 de outubro"))
        #expect(earlierText.hasSuffix(", às 19:30"))
    }

    @Test("Today's workout start shows minutes 0 to 9 with two digits")
    func startedTextSingleDigitMinutes() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 21)))
        for minute in 0...9 {
            let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 19, minute: minute)))
            #expect(HomeSummary.startedText(start, now: now, calendar: calendar) == "Iniciado às 19:0\(minute)")
        }
        let earlier = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 7, minute: 5)))
        #expect(HomeSummary.startedText(earlier, now: now, calendar: calendar).hasSuffix(", às 07:05"))
    }

    @Test("Today's card actions: continue a session in progress; start the workout planned for today unless it was finished; otherwise choose a workout (when one exists) or start a free one")
    func todayActions() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        #expect(TodayWorkoutState.inProgress(name: "Push", startedAt: start).actions == [.continueSession])
        #expect(TodayWorkoutState.inProgress(name: "", startedAt: start).actions == [.continueSession])
        #expect(TodayWorkoutState.scheduled(workoutID: UUID(), name: "Push").actions == [.startScheduledWorkout, .chooseWorkout, .startFreeWorkout])
        #expect(TodayWorkoutState.scheduledCompleted(name: "Push", duration: 3_300).actions == [.chooseWorkout, .startFreeWorkout])
        #expect(TodayWorkoutState.nothingPlanned.actions == [.chooseWorkout, .startFreeWorkout])
        #expect(TodayWorkoutState.noWorkouts.actions == [.startFreeWorkout])
    }

    @Test("The block's white button is the first action, except once today's planned workout is finished; the others are outlined")
    func todayButtons() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let inProgress = TodayWorkoutState.inProgress(name: "Push", startedAt: start)
        #expect(inProgress.mainAction == .continueSession)
        #expect(inProgress.secondaryActions.isEmpty)
        let scheduled = TodayWorkoutState.scheduled(workoutID: UUID(), name: "Push")
        #expect(scheduled.mainAction == .startScheduledWorkout)
        #expect(scheduled.secondaryActions == [.chooseWorkout, .startFreeWorkout])
        let completed = TodayWorkoutState.scheduledCompleted(name: "Push", duration: nil)
        #expect(completed.mainAction == nil)
        #expect(completed.secondaryActions == [.chooseWorkout, .startFreeWorkout])
        #expect(TodayWorkoutState.noWorkouts.mainAction == .startFreeWorkout)
        #expect(TodayWorkoutState.noWorkouts.secondaryActions.isEmpty)
        #expect(TodayWorkoutState.nothingPlanned.mainAction == .chooseWorkout)
        #expect(TodayWorkoutState.nothingPlanned.secondaryActions == [.startFreeWorkout])
    }

    @Test("What the block says in each state: badge, title, the line below, chips and what VoiceOver reads")
    func todayContent() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 21)))
        let started = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 19, minute: 30)))

        let scheduled = TodayWorkoutContent(
            state: .scheduled(workoutID: UUID(), name: "Push"),
            summary: "4 exercícios · 12 séries",
            muscleGroups: ["Peito", "Ombros", "Tríceps"]
        )
        #expect(scheduled.badge == "Programado")
        #expect(scheduled.title == "Push")
        #expect(scheduled.subtitle == "4 exercícios · 12 séries")
        #expect(scheduled.chips == ["Peito", "Ombros", "Tríceps"])
        #expect(scheduled.accessibilityText == "Push, programado para hoje, 4 exercícios · 12 séries, Peito · Ombros · Tríceps")

        let inProgress = TodayWorkoutContent(state: .inProgress(name: "", startedAt: started), now: now, calendar: calendar)
        #expect(inProgress.badge == "Em andamento")
        #expect(inProgress.title == "Treino livre")
        #expect(inProgress.subtitle == "Iniciado às 19:30")
        #expect(inProgress.chips.isEmpty)
        #expect(inProgress.accessibilityText == "Treino em andamento, Treino livre, Iniciado às 19:30")

        let completed = TodayWorkoutContent(state: .scheduledCompleted(name: "Push", duration: 55 * 60))
        #expect(completed.badge == "Concluído")
        #expect(completed.subtitle == "Concluído hoje · 55 min")
        #expect(completed.accessibilityText == "Push concluído hoje, 55 min")
        let long = TodayWorkoutContent(state: .scheduledCompleted(name: "Push", duration: 62 * 60))
        #expect(long.subtitle == "Concluído hoje · 1 h 02")
        let noDuration = TodayWorkoutContent(state: .scheduledCompleted(name: "Push", duration: nil))
        #expect(noDuration.subtitle == "Concluído hoje")
        #expect(noDuration.accessibilityText == "Push concluído hoje")

        let noWorkouts = TodayWorkoutContent(state: .noWorkouts)
        #expect(noWorkouts.badge == nil)
        #expect(noWorkouts.title == "Nenhum treino criado")
        #expect(noWorkouts.subtitle == "Crie um treino na aba Treinos ou comece um treino livre.")

        let nothingPlanned = TodayWorkoutContent(state: .nothingPlanned)
        #expect(nothingPlanned.badge == "Livre")
        #expect(nothingPlanned.title == "Descanso hoje")
        #expect(nothingPlanned.subtitle == "Nada programado para hoje. Quer treinar mesmo assim?")
        #expect(nothingPlanned.accessibilityText == "Descanso hoje. Nada programado para hoje. Quer treinar mesmo assim?")
    }
}
