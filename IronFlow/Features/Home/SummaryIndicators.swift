import Foundation

/// What an indicator of the "Resumo rápido" shows: on its card on the Início and on its row in
/// Personalizar.
struct IndicatorValue: Equatable, Sendable {
    /// The large text of the card ("8", "4 sem.", "80"); `nil` without a value: "Adicionar" on the cards
    /// that edit a value, "—" on the others.
    var value: String?
    /// The small unit beside the value ("kg", "cm"); `nil` for none.
    var unit: String?
    /// The text under the value on the card ("Treinos em out", "ontem").
    var caption: String
    /// The line under the indicator's name in Personalizar ("8 treinos em outubro").
    var line: String
    /// The value as VoiceOver reads it after the name ("8 treinos em outubro", "80 kg").
    var spoken: String
}

/// The values of the indicators, from records already read for their period, and how they are shown.
/// Pure logic: no UI and no store access (`SummaryIndicatorLoader` reads the records).
enum SummaryIndicators {
    // MARK: - Periods

    /// The month of `now` in `calendar`: from the first day at the start of the day to the first day
    /// of the next month, not included.
    static func month(of now: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .month, for: now) ?? TrainingDay.dayInterval(of: now, calendar: calendar)
    }

    /// The start of the "últimos 30 dias": today and the 29 days before it, in `calendar`.
    static func last30DaysStart(now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -29, to: today) ?? today)
    }

    // MARK: - Counting

    /// The workouts of a period ("Treinos no mês"): each finished session plus each day marked as
    /// trained outside the app, a day marked more than once counting once. Unlike the week's goal, two
    /// workouts on one day count two. `sessionCount` and `markedDays` are those of the period only.
    static func workoutCount(sessionCount: Int, markedDays: [String]) -> Int {
        sessionCount + Set(markedDays).count
    }

    /// Consecutive weeks, Monday to Sunday, that reached `goal`, counted back from the current week:
    /// `weekCounts[0]` is the current week, `[1]` the one before it, and so on. The current week counts
    /// once it reaches the goal; until then it does not break the sequence. The count stops at the first
    /// earlier week below the goal. No goal, no sequence.
    static func streak(weekCounts: [Int], goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        var weeks = 0
        for (index, count) in weekCounts.enumerated() {
            if count >= goal {
                weeks += 1
            } else if index > 0 {
                break
            }
        }
        return weeks
    }

    /// Whether the weeks counted so far (`weekCounts`, from the current one back) can still go on: every
    /// earlier week reached `goal`, so the week before them has to be read too.
    static func streakContinues(weekCounts: [Int], goal: Int) -> Bool {
        goal > 0 && weekCounts.dropFirst().allSatisfy { $0 >= goal }
    }

    /// The change of the body weight: the latest record minus the oldest of `entries`, the records of
    /// the last 30 days; `nil` with fewer than two.
    static func weightChange(of entries: [(measuredAt: Date, weightKg: Double)]) -> Double? {
        guard entries.count >= 2,
              let oldest = entries.min(by: { $0.measuredAt < $1.measuredAt }),
              let latest = entries.max(by: { $0.measuredAt < $1.measuredAt }) else { return nil }
        return latest.weightKg - oldest.weightKg
    }

    // MARK: - Workout indicators

    /// "Treinos no mês": card "8" / "Treinos em out", line "8 treinos em outubro". `month` is 1 to 12.
    static func monthWorkouts(count: Int, month: Int) -> IndicatorValue {
        let name = SessionFormatting.monthName(month)
        let line = count == 1
            ? String(localized: "1 treino em \(name)")
            : String(localized: "\(count) treinos em \(name)")
        return IndicatorValue(
            value: count.formatted(.number.locale(locale)),
            unit: nil,
            caption: String(localized: "Treinos em \(SessionFormatting.monthAbbreviation(month))"),
            line: line,
            spoken: line
        )
    }

    /// The notice of a tap on "Treinos no mês": "Treinos concluídos em outubro".
    static func monthWorkoutsExplanation(month: Int) -> String {
        String(localized: "Treinos concluídos em \(SessionFormatting.monthName(month))")
    }

    /// "Sequência": card "4 sem." / "Na meta", line "4 semanas seguidas batendo a meta"; without a
    /// weekly plan (`weeks` is `nil`), "—" and what to do to have a goal.
    static func streak(weeks: Int?) -> IndicatorValue {
        let caption = String(localized: "Na meta")
        guard let weeks else {
            let line = String(localized: "Monte a Programação semanal para ter uma meta")
            return IndicatorValue(value: nil, unit: nil, caption: caption, line: line, spoken: line)
        }
        let line = weeks == 1
            ? String(localized: "1 semana seguida batendo a meta")
            : String(localized: "\(weeks) semanas seguidas batendo a meta")
        return IndicatorValue(
            value: String(localized: "\(weeks) sem."),
            unit: nil,
            caption: caption,
            line: line,
            spoken: line
        )
    }

    /// "Kg na semana": card "14.250" / "kg na semana"; the line says which sets count.
    static func weekVolume(kg: Double) -> IndicatorValue {
        let number = Int(max(0, kg).rounded()).formatted(.number.locale(locale))
        return IndicatorValue(
            value: number,
            unit: nil,
            caption: String(localized: "kg na semana"),
            line: String(localized: "Só séries válidas e de falha"),
            spoken: String(localized: "\(number) kg na semana")
        )
    }

    /// "Tempo na semana": card "1h43" / "Treinando", line "1 h 43 min treinando esta semana". The time
    /// is rounded to minutes only once, for the whole week.
    static func weekTime(seconds: TimeInterval) -> IndicatorValue {
        let minutes = Int((max(0, seconds) / 60).rounded())
        let hours = minutes / 60
        let rest = minutes % 60
        let duration: String
        if hours == 0 {
            duration = String(localized: "\(rest) min")
        } else if rest == 0 {
            duration = String(localized: "\(hours) h")
        } else {
            duration = String(localized: "\(hours) h \(rest) min")
        }
        let line = String(localized: "\(duration) treinando esta semana")
        return IndicatorValue(
            value: "\(hours)h\(String(format: "%02ld", rest))",
            unit: nil,
            caption: String(localized: "Treinando"),
            line: line,
            spoken: line
        )
    }

    /// "Último treino": card "Pernas" / "ontem", line "Pernas · ontem"; the day is "hoje", "ontem" or
    /// the date ("14 out"). Without a finished workout, "—" and "Nenhum treino concluído ainda".
    static func lastWorkout(name: String?, startedAt: Date?, now: Date, calendar: Calendar) -> IndicatorValue {
        guard let name, let startedAt else {
            let line = String(localized: "Nenhum treino concluído ainda")
            return IndicatorValue(value: nil, unit: nil, caption: String(localized: "Último treino"), line: line, spoken: line)
        }
        let day = dayText(startedAt, now: now, calendar: calendar)
        return IndicatorValue(
            value: name,
            unit: nil,
            caption: day,
            line: "\(name) · \(day)",
            spoken: "\(name), \(day)"
        )
    }

    /// "hoje", "ontem" or the date as the history shows it ("14 out", "14 out 2025").
    static func dayText(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "hoje")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "ontem")
        }
        return SessionFormatting.shortDateText(date, now: now, calendar: calendar)
    }

    // MARK: - Body indicators

    /// "Peso": card "80" kg / "Peso", line "80 kg · o último registro"; without a record, "Adicionar" and
    /// "Nenhum registro ainda".
    static func bodyWeight(_ weightKg: Double?) -> IndicatorValue {
        let caption = String(localized: "Peso")
        guard let weightKg else {
            return IndicatorValue(value: nil, unit: nil, caption: caption, line: String(localized: "Nenhum registro ainda"), spoken: String(localized: "Adicionar"))
        }
        let text = HomeSummary.weightText(weightKg)
        return IndicatorValue(
            value: HomeSummary.number(weightKg),
            unit: "kg",
            caption: caption,
            line: String(localized: "\(text) · o último registro"),
            spoken: text
        )
    }

    /// "Altura": card "180" cm / "Altura", line "180 cm"; without one, "Adicionar" and "Não informada".
    static func height(_ heightCm: Int?) -> IndicatorValue {
        let caption = String(localized: "Altura")
        guard let heightCm else {
            return IndicatorValue(value: nil, unit: nil, caption: caption, line: String(localized: "Não informada"), spoken: String(localized: "Adicionar"))
        }
        let text = HomeSummary.heightText(heightCm)
        return IndicatorValue(
            value: heightCm.formatted(.number.locale(locale)),
            unit: "cm",
            caption: caption,
            line: text,
            spoken: text
        )
    }

    /// "Meta de calorias": card "2.300" / "kcal / dia", line "2.300 kcal por dia"; without one,
    /// "Adicionar" and "Não informada".
    static func calorieGoal(_ kcal: Int?) -> IndicatorValue {
        let caption = String(localized: "kcal / dia")
        guard let kcal else {
            return IndicatorValue(value: nil, unit: nil, caption: caption, line: String(localized: "Não informada"), spoken: String(localized: "Adicionar"))
        }
        let number = kcal.formatted(.number.locale(locale))
        return IndicatorValue(
            value: number,
            unit: nil,
            caption: caption,
            line: String(localized: "\(number) kcal por dia"),
            spoken: HomeSummary.calorieText(kcal)
        )
    }

    /// "TMB": card "1.780" / "TMB (kcal)", line "1.780 kcal · o que o corpo gasta parado"; without a
    /// result, "—" / "TMB · calcular" and the calculator's message of what is missing.
    static func bmr(_ estimate: Result<BMRCalculator.Estimate, BMRCalculator.Missing>) -> IndicatorValue {
        switch estimate {
        case .success(let values):
            let number = HomeSummary.number(Double(values.bmrKcal))
            return IndicatorValue(
                value: number,
                unit: nil,
                caption: String(localized: "TMB (kcal)"),
                line: String(localized: "\(number) kcal · o que o corpo gasta parado"),
                spoken: String(localized: "\(number) kcal")
            )
        case .failure(let missing):
            let line = String(localized: missing.message)
            return IndicatorValue(value: nil, unit: nil, caption: String(localized: "TMB · calcular"), line: line, spoken: line)
        }
    }

    /// "Variação do peso": card "−1,2" kg / "Peso em 30 dias", line "−1,2 kg nos últimos 30 dias";
    /// with fewer than two records, "—" and what to do to see it.
    static func weightChange(_ changeKg: Double?) -> IndicatorValue {
        let caption = String(localized: "Peso em 30 dias")
        guard let changeKg else {
            let line = String(localized: "Registre o peso mais vezes para ver a variação")
            return IndicatorValue(value: nil, unit: nil, caption: caption, line: line, spoken: line)
        }
        let number = HomeSummary.signedNumber(changeKg)
        let line = String(localized: "\(number) kg nos últimos 30 dias")
        return IndicatorValue(value: number, unit: "kg", caption: caption, line: line, spoken: line)
    }

    /// The app is in Brazilian Portuguese only.
    private static let locale = Locale(identifier: "pt_BR")
}
