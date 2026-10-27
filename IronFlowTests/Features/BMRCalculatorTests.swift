import Foundation
import Testing
@testable import IronFlow

/// The Mifflin-St Jeor formula of the BMR calculator: its rounding, the ages it is used for, what is
/// missing without a result and the limits of the goal.
struct BMRCalculatorTests {
    static let saoPaulo: Calendar = calendar("America/Sao_Paulo")

    /// 27 October 2026, at noon in São Paulo.
    static let today = moment(2026, 10, 27, hour: 12, in: saoPaulo)

    /// 80 kg, 180 cm, a man born on 15 May 1996 (30 years old on `today`), moderately active.
    static let sample = BMRCalculator.Inputs(
        weightKg: 80,
        heightCm: 180,
        sex: .male,
        birthDate: BirthDate(day: 15, month: 5, year: 1996),
        activityLevel: .moderate,
        weightGoal: .lose
    )

    @Test("BMR, energy spent and goal of the sample: 1.780, 2.760 and 2.360 kcal to lose weight")
    func sampleEstimate() throws {
        // BMR 10 × 80 + 6,25 × 180 − 5 × 30 + 5 = 1.780; spent 1.780 × 1,55 = 2.759; goal 2.759 − 400.
        let estimate = try BMRCalculator.estimate(Self.sample, now: Self.today, calendar: Self.saoPaulo).get()
        #expect(estimate == BMRCalculator.Estimate(bmrKcal: 1_780, expenditureKcal: 2_760, goalKcal: 2_360))

        var keeping = Self.sample
        keeping.weightGoal = .maintain
        #expect(try BMRCalculator.estimate(keeping, now: Self.today, calendar: Self.saoPaulo).get().goalKcal == 2_760)
        var gaining = Self.sample
        gaining.weightGoal = .gain
        #expect(try BMRCalculator.estimate(gaining, now: Self.today, calendar: Self.saoPaulo).get().goalKcal == 3_060)
    }

    @Test("The formula adds 5 for men and subtracts 161 for women")
    func sexOfTheFormula() {
        #expect(BMRCalculator.bmr(weightKg: 80, heightCm: 180, age: 30, sex: .male) == 1_780)
        #expect(BMRCalculator.bmr(weightKg: 80, heightCm: 180, age: 30, sex: .female) == 1_614)
        #expect(BMRCalculator.bmr(weightKg: 62.5, heightCm: 165, age: 41, sex: .female) == 1_290.25)
    }

    @Test("The factors of the activity levels and the adjustments of the goals")
    func factorsAndAdjustments() {
        #expect(ActivityLevel.allCases.map(\.factor) == [1.2, 1.375, 1.55, 1.725, 1.9])
        #expect(ActivityLevel.allCases.map(\.rawValue) == ["sedentary", "light", "moderate", "intense", "veryIntense"])
        #expect(WeightGoal.allCases.map(\.adjustmentKcal) == [-400, 0, 300])
        #expect(WeightGoal.allCases.map(\.rawValue) == ["lose", "maintain", "gain"])
        #expect(BiologicalSex.allCases.map(\.rawValue) == ["male", "female"])
        #expect(ActivityLevel(storageKey: "unknown") == .moderate)
        #expect(WeightGoal(storageKey: "unknown") == .maintain)
    }

    @Test("Each value is rounded to the nearest ten only at the end; the energy spent comes from the BMR before rounding")
    func roundingAtTheEnd() throws {
        // A woman of 60 kg and 165 cm, 25 years old: BMR 1.345,25; lightly active, she spends 1.849,72.
        // Rounding the BMR first (1.350 × 1,375 = 1.856,25) would give 1.860.
        let inputs = BMRCalculator.Inputs(
            weightKg: 60,
            heightCm: 165,
            sex: .female,
            birthDate: BirthDate(day: 1, month: 1, year: 2001),
            activityLevel: .light,
            weightGoal: .maintain
        )
        let estimate = try BMRCalculator.estimate(inputs, now: Self.today, calendar: Self.saoPaulo).get()
        #expect(estimate == BMRCalculator.Estimate(bmrKcal: 1_350, expenditureKcal: 1_850, goalKcal: 1_850))

        #expect(BMRCalculator.roundedToTen(1_785) == 1_790)
        #expect(BMRCalculator.roundedToTen(1_784.99) == 1_780)
        #expect(BMRCalculator.roundedToTen(1_775) == 1_780)
        #expect(BMRCalculator.roundedToTen(1_349.9) == 1_350)
    }

    @Test("The goal never goes below 800 or above 8.000 kcal")
    func goalWithinTheLimits() throws {
        // A woman of 20 kg and 100 cm, 100 years old, sedentary, losing weight: 196,8 − 400.
        let lowest = BMRCalculator.Inputs(
            weightKg: 20,
            heightCm: 100,
            sex: .female,
            birthDate: BirthDate(day: 1, month: 1, year: 1926),
            activityLevel: .sedentary,
            weightGoal: .lose
        )
        let low = try BMRCalculator.estimate(lowest, now: Self.today, calendar: Self.saoPaulo).get()
        #expect(low == BMRCalculator.Estimate(bmrKcal: 160, expenditureKcal: 200, goalKcal: 800))

        // A man of 300 kg and 250 cm, 15 years old, very intense, gaining mass: 8.535,75 + 300.
        let highest = BMRCalculator.Inputs(
            weightKg: 300,
            heightCm: 250,
            sex: .male,
            birthDate: BirthDate(day: 1, month: 1, year: 2011),
            activityLevel: .veryIntense,
            weightGoal: .gain
        )
        let high = try BMRCalculator.estimate(highest, now: Self.today, calendar: Self.saoPaulo).get()
        #expect(high == BMRCalculator.Estimate(bmrKcal: 4_490, expenditureKcal: 8_540, goalKcal: 8_000))
    }

    @Test("The calculator is used from 15 to 100 years old, in full years on the day")
    func agesFifteenToHundred() {
        func age(_ day: Int, _ month: Int, _ year: Int) -> Int? {
            BMRCalculator.age(of: BirthDate(day: day, month: month, year: year), on: Self.today, calendar: Self.saoPaulo)
        }
        func result(_ day: Int, _ month: Int, _ year: Int) -> Result<BMRCalculator.Estimate, BMRCalculator.Missing> {
            var inputs = Self.sample
            inputs.birthDate = BirthDate(day: day, month: month, year: year)
            return BMRCalculator.estimate(inputs, now: Self.today, calendar: Self.saoPaulo)
        }

        // 15 years old on the birthday, 14 the day before it.
        #expect(age(27, 10, 2011) == 15)
        #expect(age(28, 10, 2011) == 14)
        #expect(result(27, 10, 2011).isSuccess)
        #expect(result(28, 10, 2011) == .failure(.ageOutOfRange))

        // 100 years old until the 101st birthday.
        #expect(age(27, 10, 1926) == 100)
        #expect(age(28, 10, 1925) == 100)
        #expect(age(27, 10, 1925) == 101)
        #expect(result(28, 10, 1925).isSuccess)
        #expect(result(27, 10, 1925) == .failure(.ageOutOfRange))
    }

    @Test("The age is counted on the day of the device's time zone, and the date of birth never moves with it")
    func ageInTheDeviceTimeZone() {
        // 02:00 UTC on 27 October: still the 26th in São Paulo, already the 27th in Tokyo.
        let moment = Self.moment(2026, 10, 27, hour: 2, in: Self.calendar("UTC"))
        let birth = BirthDate(day: 27, month: 10, year: 2000)
        #expect(BMRCalculator.age(of: birth, on: moment, calendar: Self.saoPaulo) == 25)
        #expect(BMRCalculator.age(of: birth, on: moment, calendar: Self.calendar("Asia/Tokyo")) == 26)
    }

    @Test("Someone born on 29 February has a birthday on 1 March in the other years")
    func leapDayBirthday() {
        let birth = BirthDate(day: 29, month: 2, year: 2004)
        #expect(BMRCalculator.age(of: birth, on: Self.moment(2026, 2, 28, hour: 12, in: Self.saoPaulo), calendar: Self.saoPaulo) == 21)
        #expect(BMRCalculator.age(of: birth, on: Self.moment(2026, 3, 1, hour: 12, in: Self.saoPaulo), calendar: Self.saoPaulo) == 22)
        #expect(BMRCalculator.age(of: birth, on: Self.moment(2028, 2, 29, hour: 12, in: Self.saoPaulo), calendar: Self.saoPaulo) == 24)
    }

    @Test("Without a result, the calculator says what is missing: first the body data, then the sex and the date")
    func whatIsMissing() {
        func missing(_ change: (inout BMRCalculator.Inputs) -> Void) -> BMRCalculator.Missing? {
            var inputs = Self.sample
            change(&inputs)
            guard case .failure(let missing) = BMRCalculator.estimate(inputs, now: Self.today, calendar: Self.saoPaulo) else { return nil }
            return missing
        }

        #expect(missing { $0.weightKg = nil } == .bodyData)
        #expect(missing { $0.heightCm = nil } == .bodyData)
        #expect(missing { $0.weightKg = nil; $0.sex = nil; $0.birthDate = BirthDate() } == .bodyData)
        #expect(missing { $0.sex = nil; $0.birthDate = BirthDate() } == .sexAndBirthDate)
        #expect(missing { $0.sex = nil; $0.birthDate.year = nil } == .sexAndBirthDate)
        #expect(missing { $0.sex = nil } == .sex)
        #expect(missing { $0.birthDate = BirthDate() } == .birthDate)
        #expect(missing { $0.birthDate.day = nil } == .birthDate)
        #expect(missing { $0.birthDate.month = nil } == .birthDate)
        #expect(missing { $0.birthDate.year = nil } == .birthDate)
        #expect(missing { $0.birthDate.year = 2020 } == .ageOutOfRange)
        #expect(missing { _ in } == nil)
    }

    @Test("The messages instead of the result")
    func missingMessages() {
        #expect(String(localized: BMRCalculator.Missing.bodyData.message) == "Registre o seu peso e a sua altura para calcular.")
        #expect(String(localized: BMRCalculator.Missing.sexAndBirthDate.message) == "Escolha o sexo e a data de nascimento para ver o resultado.")
        #expect(String(localized: BMRCalculator.Missing.sex.message) == "Falta escolher o sexo.")
        #expect(String(localized: BMRCalculator.Missing.birthDate.message) == "Falta escolher a data de nascimento completa.")
        #expect(String(localized: BMRCalculator.Missing.ageOutOfRange.message) == "Confira a data de nascimento: a calculadora vale de 15 a 100 anos.")
    }

    @Test("A day beyond its month counts as the month's last day; February has 29 days while the year is unknown")
    func dayKeptInMonth() {
        #expect(BirthDate(day: 31, month: 4, year: 1990).keepingDayInMonth() == BirthDate(day: 30, month: 4, year: 1990))
        #expect(BirthDate(day: 31, month: 2, year: 1900).keepingDayInMonth() == BirthDate(day: 28, month: 2, year: 1900))
        #expect(BirthDate(day: 31, month: 2, year: 2000).keepingDayInMonth() == BirthDate(day: 29, month: 2, year: 2000))
        #expect(BirthDate(day: 31, month: 2, year: nil).keepingDayInMonth() == BirthDate(day: 29, month: 2, year: nil))
        #expect(BirthDate(day: 31, month: nil, year: 1990).keepingDayInMonth() == BirthDate(day: 31, month: nil, year: 1990))
        #expect(BirthDate(day: 15, month: 5, year: 1996).keepingDayInMonth() == BirthDate(day: 15, month: 5, year: 1996))
        #expect(BirthDate(day: 1, month: 1, year: 1990).isComplete)
        #expect(!BirthDate(day: 1, month: 1, year: nil).isComplete)
        // The age reads the day kept in the month: the 31st of April 2011 is the 30th.
        #expect(BMRCalculator.age(of: BirthDate(day: 31, month: 4, year: 2011), on: Self.moment(2026, 4, 30, hour: 12, in: Self.saoPaulo), calendar: Self.saoPaulo) == 15)
    }

    @Test("Without a profile, the inputs have only the weight, a moderate level and the goal of keeping the weight")
    func inputsWithoutAProfile() {
        let inputs = BMRCalculator.inputs(profile: nil, weightKg: 80)
        #expect(inputs == BMRCalculator.Inputs(
            weightKg: 80,
            heightCm: nil,
            sex: nil,
            birthDate: BirthDate(),
            activityLevel: .moderate,
            weightGoal: .maintain
        ))
    }

    // MARK: - Support

    static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .gmt
        return calendar
    }

    static func moment(_ year: Int, _ month: Int, _ day: Int, hour: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { true } else { false }
    }
}
