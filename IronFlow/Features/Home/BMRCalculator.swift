import Foundation

/// The basal metabolic rate ("TMB") by the Mifflin-St Jeor formula, the energy spent in a day and the
/// daily calorie goal it suggests. Pure logic: no UI and no store access.
///
/// BMR = 10 × kg + 6,25 × cm − 5 × age, plus 5 for men or minus 161 for women. The energy spent is the
/// BMR times the factor of the activity level, and the goal is that energy with the adjustment of the
/// weight goal, kept within the limits of a calorie goal. The three are rounded to the nearest ten only
/// at the end: the energy spent comes from the BMR before rounding, and the goal from the energy before
/// rounding.
enum BMRCalculator {
    /// The ages, in full years, the formula is used for.
    static let ageRange = 15...100

    /// The data the formula reads.
    struct Inputs: Equatable, Sendable {
        var weightKg: Double?
        var heightCm: Int?
        var sex: BiologicalSex?
        var birthDate: BirthDate
        var activityLevel: ActivityLevel
        var weightGoal: WeightGoal
    }

    /// The result, in kilocalories per day, each rounded to the nearest ten.
    struct Estimate: Equatable, Sendable {
        let bmrKcal: Int
        let expenditureKcal: Int
        let goalKcal: Int
    }

    /// Why there is no result yet.
    enum Missing: Error, Equatable, Sendable {
        /// No body weight or no height recorded.
        case bodyData
        /// Neither the sex nor the whole date of birth chosen.
        case sexAndBirthDate
        case sex
        /// The day, the month or the year of birth not chosen.
        case birthDate
        /// The date of birth gives an age outside `ageRange`.
        case ageOutOfRange

        /// What the calculator says instead of the result.
        var message: LocalizedStringResource {
            switch self {
            case .bodyData: "Registre o seu peso e a sua altura para calcular."
            case .sexAndBirthDate: "Escolha o sexo e a data de nascimento para ver o resultado."
            case .sex: "Falta escolher o sexo."
            case .birthDate: "Falta escolher a data de nascimento completa."
            case .ageOutOfRange: "Confira a data de nascimento: a calculadora vale de 15 a 100 anos."
            }
        }
    }

    /// The inputs of `profile`, with the latest body weight.
    static func inputs(profile: UserProfile?, weightKg: Double?) -> Inputs {
        Inputs(
            weightKg: weightKg,
            heightCm: profile?.heightCm,
            sex: profile?.sex,
            birthDate: profile?.birthDate ?? BirthDate(),
            activityLevel: profile?.activityLevel ?? .moderate,
            weightGoal: profile?.weightGoal ?? .maintain
        )
    }

    /// The BMR, the energy spent and the goal of `inputs` on the day of `now` in `calendar`, or what is
    /// missing to compute them.
    static func estimate(_ inputs: Inputs, now: Date, calendar: Calendar) -> Result<Estimate, Missing> {
        guard let weightKg = inputs.weightKg, let heightCm = inputs.heightCm else { return .failure(.bodyData) }
        guard let sex = inputs.sex else {
            return .failure(inputs.birthDate.isComplete ? .sex : .sexAndBirthDate)
        }
        guard let age = Self.age(of: inputs.birthDate, on: now, calendar: calendar) else { return .failure(.birthDate) }
        guard ageRange.contains(age) else { return .failure(.ageOutOfRange) }

        let rate = Self.bmr(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
        let expenditure = rate * inputs.activityLevel.factor
        let limits = Validation.dailyCalorieGoalRangeKcal
        let goal = min(max(expenditure + inputs.weightGoal.adjustmentKcal, Double(limits.lowerBound)), Double(limits.upperBound))
        return .success(Estimate(
            bmrKcal: roundedToTen(rate),
            expenditureKcal: roundedToTen(expenditure),
            goalKcal: roundedToTen(goal)
        ))
    }

    /// The BMR in kilocalories per day, not rounded.
    static func bmr(weightKg: Double, heightCm: Int, age: Int, sex: BiologicalSex) -> Double {
        let base = 10 * weightKg + 6.25 * Double(heightCm) - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// The full years of someone born on `birthDate` on the day of `now` in `calendar` (the device's
    /// time zone); `nil` while the date is incomplete. A day beyond its month counts as the month's last
    /// day; someone born on 29 February has a birthday on 1 March in the other years.
    static func age(of birthDate: BirthDate, on now: Date, calendar: Calendar) -> Int? {
        let birth = birthDate.keepingDayInMonth()
        guard let day = birth.day, let month = birth.month, let year = birth.year else { return nil }
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        guard let todayYear = today.year, let todayMonth = today.month, let todayDay = today.day else { return nil }
        let hadBirthday = (todayMonth, todayDay) >= (month, day)
        return todayYear - year - (hadBirthday ? 0 : 1)
    }

    /// `value` rounded to the nearest ten; a half ten goes up (1.785 is 1.790).
    static func roundedToTen(_ value: Double) -> Int {
        Int((value / 10).rounded(.toNearestOrAwayFromZero)) * 10
    }
}
