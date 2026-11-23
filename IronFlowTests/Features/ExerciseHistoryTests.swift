import Foundation
import Testing
@testable import IronFlow

/// The rules of the exercise screen: which sessions and sets count, the best sets, the metrics, the
/// periods, the change and the texts.
struct ExerciseHistoryTests {
    /// A fixed calendar, so the days do not depend on the machine's time zone.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        return calendar
    }()

    /// The prototype's "today": Friday, 16 October 2026, at noon.
    private static let today = date(2026, 10, 16, hour: 12)

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private typealias Record = ExerciseHistory.SetRecord

    private static func set(_ weight: Double?, _ reps: Int?, _ type: SetType = .working, number: Int = 1) -> Record {
        Record(number: number, type: type, weightKg: weight, reps: reps)
    }

    private static func entry(_ date: Date, _ sets: [Record], name: String = "Push", id: UUID = UUID()) -> ExerciseHistory.Entry {
        let numbered = sets.enumerated().map { Record(number: $0 + 1, type: $1.type, weightKg: $1.weightKg, reps: $1.reps) }
        return ExerciseHistory.Entry(id: id, workoutName: name, startedAt: date, sets: numbered)
    }

    // MARK: - Sessions and kind

    @Test("A session with only warm-up or feeder sets of the exercise is left out; the others are ordered from the oldest")
    func sessionsThatCount() {
        let warmUpOnly = Self.entry(Self.date(2026, 10, 9), [Self.set(40, 15, .warmup), Self.set(50, 6, .feeder)])
        let older = Self.entry(Self.date(2026, 9, 1), [Self.set(60, 10)])
        let newer = Self.entry(Self.date(2026, 10, 1), [Self.set(40, 15, .warmup), Self.set(62, 8, .failure)])
        let history = ExerciseHistory(entries: [newer, warmUpOnly, older], isAssisted: false)
        #expect(history.entries.map(\.id) == [older.id, newer.id])
        // The warm-up set is still shown in its session.
        #expect(history.entries[1].sets.map(\.type) == [.warmup, .failure])
        #expect(ExerciseHistory(entries: [warmUpOnly], isAssisted: false).isEmpty)
    }

    @Test("The kind: Graviton when the exercise is assisted; without kg in any counted set, by repetitions; else with load")
    func kinds() {
        let loaded = Self.entry(Self.date(2026, 10, 1), [Self.set(20, 10)])
        let bodyweight = Self.entry(Self.date(2026, 10, 2), [Self.set(10, 15, .warmup), Self.set(nil, 12), Self.set(0, 10)])
        #expect(ExerciseHistory(entries: [loaded], isAssisted: false).kind == .load)
        #expect(ExerciseHistory(entries: [loaded], isAssisted: true).kind == .assisted)
        #expect(ExerciseHistory(entries: [bodyweight], isAssisted: false).kind == .bodyweight)
        #expect(ExerciseHistory(entries: [loaded, bodyweight], isAssisted: false).kind == .load)
        #expect(ExerciseHistory(entries: [loaded], isAssisted: false).metrics == [.maxLoad, .volume])
        #expect(ExerciseHistory(entries: [loaded], isAssisted: true).metrics == [.leastHelp, .maxReps])
        #expect(ExerciseHistory(entries: [bodyweight], isAssisted: false).metrics == [.maxReps, .totalReps])
    }

    // MARK: - Best sets

    @Test("Best set: more kg, then more repetitions; on a full tie the oldest; warm-ups never count")
    func bestSetWithLoad() throws {
        let first = Self.entry(Self.date(2026, 9, 1), [Self.set(100, 20, .warmup), Self.set(60, 8), Self.set(60, 10)])
        let second = Self.entry(Self.date(2026, 9, 8), [Self.set(60, 10), Self.set(55, 12, .failure)])
        let history = ExerciseHistory(entries: [second, first], isAssisted: false)
        let best = try #require(history.bestSet)
        #expect(best.sessionID == first.id)
        #expect(best.set.number == 3)
        #expect(best.set.load == 60)
        #expect(best.set.reps == 10)
        // "Última vez": the best of the most recent session.
        let last = try #require(history.lastTime)
        #expect(last.sessionID == second.id)
        #expect(last.set.number == 1)
    }

    @Test("Graviton: less kg is better, then more repetitions")
    func bestSetAssisted() throws {
        let first = Self.entry(Self.date(2026, 9, 1), [Self.set(45, 6), Self.set(35, 8)])
        let second = Self.entry(Self.date(2026, 9, 8), [Self.set(35, 9), Self.set(40, 12)])
        let best = try #require(ExerciseHistory(entries: [first, second], isAssisted: true).bestSet)
        #expect(best.sessionID == second.id)
        #expect(best.set.load == 35)
        #expect(best.set.reps == 9)
    }

    @Test("Without kg: more repetitions; on a tie the oldest")
    func bestSetBodyweight() throws {
        let first = Self.entry(Self.date(2026, 9, 1), [Self.set(nil, 20), Self.set(nil, 18)])
        let second = Self.entry(Self.date(2026, 9, 8), [Self.set(nil, 20)])
        let best = try #require(ExerciseHistory(entries: [first, second], isAssisted: false).bestSet)
        #expect(best.sessionID == first.id)
        #expect(best.set.number == 1)
    }

    // MARK: - Metrics

    @Test("The value of each metric comes from the working and failure sets of the session")
    func metricValues() {
        let entry = Self.entry(Self.date(2026, 10, 1), [
            Self.set(40, 15, .warmup), Self.set(60, 10), Self.set(57.5, 9), Self.set(50, 12, .failure),
        ])
        #expect(ExerciseHistory.value(of: .maxLoad, in: entry) == 60)
        #expect(ExerciseHistory.value(of: .leastHelp, in: entry) == 50)
        #expect(ExerciseHistory.value(of: .maxReps, in: entry) == 12)
        #expect(ExerciseHistory.value(of: .volume, in: entry) == 600 + 517.5 + 600)
        #expect(ExerciseHistory.value(of: .totalReps, in: entry) == 31)
    }

    // MARK: - Periods

    @Test("The period counts back from the start of today: 90 days includes the session 90 days ago, not 91")
    func periods() {
        let ninety = Self.entry(Self.date(2026, 7, 18), [Self.set(50, 10)])
        let ninetyOne = Self.entry(Self.date(2026, 7, 17), [Self.set(48, 10)])
        let recent = Self.entry(Self.date(2026, 10, 9), [Self.set(62, 10)])
        let yearAgo = Self.entry(Self.date(2025, 10, 16), [Self.set(40, 10)])
        let older = Self.entry(Self.date(2025, 10, 15), [Self.set(38, 10)])
        let history = ExerciseHistory(entries: [ninety, ninetyOne, recent, yearAgo, older], isAssisted: false)

        let threeMonths = history.chart(metric: .maxLoad, period: .threeMonths, today: Self.today, calendar: Self.calendar)
        #expect(threeMonths.points.map(\.id) == [ninety.id, recent.id])
        #expect(threeMonths.start == Self.date(2026, 7, 18, hour: 0))
        #expect(threeMonths.end == Self.date(2026, 10, 16, hour: 0))

        let year = history.chart(metric: .maxLoad, period: .oneYear, today: Self.today, calendar: Self.calendar)
        #expect(year.points.map(\.id) == [yearAgo.id, ninetyOne.id, ninety.id, recent.id])

        let all = history.chart(metric: .maxLoad, period: .all, today: Self.today, calendar: Self.calendar)
        #expect(all.points.count == 5)
        #expect(all.start == Self.date(2025, 10, 15, hour: 0))
        #expect(all.points.first?.day == Self.date(2025, 10, 15, hour: 0))
    }

    // MARK: - Change

    @Test("The change is the last point minus the first: ▲ better, ▼ worse, Igual when the same")
    func changes() {
        #expect(ExerciseChart.change(from: 50, to: 62, metric: .maxLoad, period: .threeMonths)
            == .init(text: "▲ 12 kg nos últimos 3 meses", isWorse: false))
        #expect(ExerciseChart.change(from: 62, to: 57.5, metric: .maxLoad, period: .oneYear)
            == .init(text: "▼ 4,5 kg no último ano", isWorse: true))
        #expect(ExerciseChart.change(from: 1_000, to: 2_234, metric: .volume, period: .all)
            == .init(text: "▲ 1.234 kg desde o primeiro treino", isWorse: false))
        #expect(ExerciseChart.change(from: 12, to: 16, metric: .maxReps, period: .threeMonths)
            == .init(text: "▲ 4 reps nos últimos 3 meses", isWorse: false))
        #expect(ExerciseChart.change(from: 60, to: 60, metric: .maxLoad, period: .oneYear)
            == .init(text: "Igual no último ano", isWorse: false))
    }

    @Test("Graviton, less help: less kg is ▲, with 'a menos de ajuda'; more help is ▼")
    func assistedChange() {
        #expect(ExerciseChart.change(from: 35, to: 25, metric: .leastHelp, period: .threeMonths)
            == .init(text: "▲ 10 kg a menos de ajuda nos últimos 3 meses", isWorse: false))
        #expect(ExerciseChart.change(from: 25, to: 30, metric: .leastHelp, period: .oneYear)
            == .init(text: "▼ 5 kg a mais de ajuda no último ano", isWorse: true))
        // "Mais repetições" of a Graviton exercise is not inverted.
        #expect(ExerciseChart.change(from: 6, to: 8, metric: .maxReps, period: .all)
            == .init(text: "▲ 2 reps desde o primeiro treino", isWorse: false))
    }

    // MARK: - Messages

    @Test("One session: the invitation to do it once more, without a chart")
    func oneSession() {
        let history = ExerciseHistory(entries: [Self.entry(Self.date(2026, 10, 9), [Self.set(10, 12)])], isAssisted: false)
        let chart = history.chart(metric: .maxLoad, period: .threeMonths, today: Self.today, calendar: Self.calendar)
        #expect(chart.message == "Faça este exercício em mais um treino para ver a evolução.")
        #expect(chart.showsChart == false)
        #expect(chart.change == nil)
        #expect(chart.points.count == 1)
    }

    @Test("Fewer than 2 sessions in the period: say so and invite a longer period")
    func fewInThePeriod() {
        let history = ExerciseHistory(entries: [
            Self.entry(Self.date(2026, 1, 9), [Self.set(50, 10)]),
            Self.entry(Self.date(2026, 3, 9), [Self.set(55, 10)]),
            Self.entry(Self.date(2026, 10, 9), [Self.set(60, 10)]),
        ], isAssisted: false)
        let one = history.chart(metric: .maxLoad, period: .threeMonths, today: Self.today, calendar: Self.calendar)
        #expect(one.message == "Só 1 treino com este exercício nos últimos 3 meses. Escolha um período maior para ver a evolução.")
        let none = history.chart(metric: .maxLoad, period: .threeMonths, today: Self.date(2027, 3, 1), calendar: Self.calendar)
        #expect(none.message == "Nenhum treino com este exercício nos últimos 3 meses. Escolha um período maior para ver a evolução.")
        #expect(none.points.isEmpty)
        let year = history.chart(metric: .maxLoad, period: .oneYear, today: Self.today, calendar: Self.calendar)
        #expect(year.showsChart)
        #expect(year.change?.text == "▲ 10 kg no último ano")
    }

    // MARK: - Axes

    @Test("Round steps of 1, 2, 2,5 and 5 times a power of 10")
    func niceSteps() {
        #expect(ExerciseChart.niceStep(4) == 5)
        #expect(ExerciseChart.niceStep(1) == 1)
        #expect(ExerciseChart.niceStep(1.4) == 2)
        #expect(ExerciseChart.niceStep(2.2) == 2.5)
        #expect(ExerciseChart.niceStep(30) == 50)
        #expect(ExerciseChart.niceStep(0.33) == 0.5)
    }

    @Test("The horizontal lines go by a round step from below the lowest value to above the highest")
    func ticks() {
        #expect(ExerciseChart.ticks(for: [50, 62], metric: .maxLoad) == [50, 55, 60, 65])
        // Equal values get room: 2 kg or reps, 100 kg of volume.
        #expect(ExerciseChart.ticks(for: [10, 10], metric: .maxLoad) == [8, 10, 12])
        #expect(ExerciseChart.ticks(for: [1_000, 1_000], metric: .volume) == [900, 1_000, 1_100])
        // Repetitions never go by less than 1.
        #expect(ExerciseChart.ticks(for: [12, 13], metric: .maxReps) == [12, 13])
        #expect(ExerciseChart.ticks(for: [], metric: .maxLoad).isEmpty)
        for values in [[50.0, 62], [140, 180], [17.5, 25], [1_200, 4_310], [6, 8]] {
            let count = ExerciseChart.ticks(for: values, metric: .maxLoad).count
            #expect((3...5).contains(count), "\(values): \(count) lines")
        }
    }

    @Test("The months below the chart: the first day of each month in the period, none too close")
    func months() {
        let threeMonths = ExerciseChart.monthLabels(start: Self.date(2026, 7, 18, hour: 0), end: Self.date(2026, 10, 16, hour: 0), calendar: Self.calendar)
        #expect(threeMonths == [Self.date(2026, 8, 1, hour: 0), Self.date(2026, 9, 1, hour: 0), Self.date(2026, 10, 1, hour: 0)])
        let year = ExerciseChart.monthLabels(start: Self.date(2025, 10, 16, hour: 0), end: Self.date(2026, 10, 16, hour: 0), calendar: Self.calendar)
        // 12 months: every other one.
        #expect(year.count == 6)
        #expect(year.first == Self.date(2025, 11, 1, hour: 0))
    }

    // MARK: - Texts

    @Test("Sets, values, dates and the count as the app writes them")
    func texts() {
        #expect(ExerciseHistoryFormatting.setText(Self.set(62, 10)) == "62 kg × 10")
        #expect(ExerciseHistoryFormatting.setText(Self.set(17.5, 12)) == "17,5 kg × 12")
        #expect(ExerciseHistoryFormatting.setText(Self.set(nil, 12)) == "12 reps")
        #expect(ExerciseHistoryFormatting.setText(Self.set(0, 8)) == "8 reps")
        #expect(ExerciseHistoryFormatting.valueText(4_210.4, metric: .volume) == "4.210 kg")
        #expect(ExerciseHistoryFormatting.number(62.5, metric: .maxLoad) == "62,5")
        #expect(ExerciseHistoryFormatting.number(24, metric: .totalReps) == "24")
        #expect(ExerciseHistoryFormatting.dateText(Self.date(2026, 10, 9), today: Self.today, calendar: Self.calendar) == "sex, 9 out")
        #expect(ExerciseHistoryFormatting.dateText(Self.date(2025, 10, 10), today: Self.today, calendar: Self.calendar) == "sex, 10 out 2025")
        #expect(ExerciseHistoryFormatting.countText(24, isAssisted: false) == "24 treinos")
        #expect(ExerciseHistoryFormatting.countText(1, isAssisted: false) == "1 treino")
        #expect(ExerciseHistoryFormatting.countText(25, isAssisted: true) == "25 treinos · kg é a ajuda")
    }

    @Test("VoiceOver reads the chart from its first to its last point")
    func accessibilitySummary() {
        let history = ExerciseHistory(entries: [
            Self.entry(Self.date(2026, 7, 22), [Self.set(50, 10)]),
            Self.entry(Self.date(2026, 10, 9), [Self.set(62, 10)]),
        ], isAssisted: false)
        let chart = history.chart(metric: .maxLoad, period: .threeMonths, today: Self.today, calendar: Self.calendar)
        #expect(chart.accessibilitySummary(today: Self.today, calendar: Self.calendar) == "Maior carga: de 50 kg em qua, 22 jul a 62 kg em sex, 9 out")
    }
}
