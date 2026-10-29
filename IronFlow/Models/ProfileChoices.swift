import Foundation

// The choices of the BMR calculator, stored in `UserProfile`. Each raw value is the stable storage key
// and never depends on the interface language; the order of the cases is the order shown.

/// The sex the BMR formula asks for.
enum BiologicalSex: String, CaseIterable, Sendable {
    case male
    case female

    var displayName: LocalizedStringResource {
        switch self {
        case .male: "Masculino"
        case .female: "Feminino"
        }
    }
}

/// How active the user is: the factor that turns the BMR into the energy spent in a day.
enum ActivityLevel: String, CaseIterable, Sendable {
    case sedentary
    case light
    case moderate
    case intense
    case veryIntense

    /// Creates a level from its storage key. Unknown keys can only come from data written by a newer
    /// app version; they are read as `.moderate`, the level of every profile before it existed.
    init(storageKey: String) {
        self = ActivityLevel(rawValue: storageKey) ?? .moderate
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .sedentary: "Sedentário"
        case .light: "Leve"
        case .moderate: "Moderado"
        case .intense: "Intenso"
        case .veryIntense: "Muito intenso"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .sedentary: "Pouco ou nenhum exercício"
        case .light: "Exercício de 1 a 3 dias por semana"
        case .moderate: "Exercício de 3 a 5 dias por semana"
        case .intense: "Exercício de 6 a 7 dias por semana"
        case .veryIntense: "Treino pesado todo dia ou trabalho físico"
        }
    }

    /// The BMR times this factor is the energy spent in a day.
    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .intense: 1.725
        case .veryIntense: 1.9
        }
    }
}

/// What the user wants from the calorie goal.
enum WeightGoal: String, CaseIterable, Sendable {
    case lose
    case maintain
    case gain

    /// Creates a goal from its storage key. Unknown keys can only come from data written by a newer
    /// app version; they are read as `.maintain`, the goal of every profile before it existed.
    init(storageKey: String) {
        self = WeightGoal(rawValue: storageKey) ?? .maintain
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .lose: "Perder"
        case .maintain: "Manter"
        case .gain: "Ganhar"
        }
    }

    /// The kilocalories added to the energy spent in a day: −400 to lose weight, +300 to gain mass.
    var adjustmentKcal: Double {
        switch self {
        case .lose: -400
        case .maintain: 0
        case .gain: 300
        }
    }
}

/// A date of birth as chosen in the calculator's three menus: day, month (1 = January) and year, each
/// `nil` until chosen. Calendar numbers, never a moment, so the day never moves with the time zone.
struct BirthDate: Equatable, Sendable {
    var day: Int?
    var month: Int?
    var year: Int?

    /// Whether the day, the month and the year are all chosen.
    var isComplete: Bool {
        day != nil && month != nil && year != nil
    }

    /// The same date with `day` kept within its month: the 31st of a 30-day month is the 30th, and the
    /// 29th, 30th or 31st of February is its last day (the 29th while the year is not chosen).
    func keepingDayInMonth() -> BirthDate {
        guard let day, let month else { return self }
        var date = self
        date.day = min(day, Self.dayCount(month: month, year: year))
        return date
    }

    /// The days of `month` in `year`; February has 29 while the year is unknown.
    static func dayCount(month: Int, year: Int?) -> Int {
        switch month {
        case 2:
            guard let year else { return 29 }
            let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return isLeap ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
}
