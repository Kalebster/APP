import Foundation

/// A value of the user's body data that the Início summary edits: body weight, height or daily
/// calorie goal.
enum BodyMetric: String, CaseIterable, Identifiable, Sendable {
    case bodyWeight
    case height
    case dailyCalorieGoal

    var id: String { rawValue }

    /// The title of its editor.
    var editorTitle: LocalizedStringResource {
        switch self {
        case .bodyWeight: "Peso corporal"
        case .height: "Altura"
        case .dailyCalorieGoal: "Meta diária de calorias"
        }
    }

    /// The unit beside the value.
    var unit: String {
        switch self {
        case .bodyWeight: "kg"
        case .height: "cm"
        case .dailyCalorieGoal: "kcal"
        }
    }

    /// The line under the value; none for the height.
    var help: LocalizedStringResource? {
        switch self {
        case .bodyWeight: "Cada novo peso fica registrado com a data de hoje."
        case .height: nil
        case .dailyCalorieGoal: "Quantas calorias você quer comer por dia."
        }
    }

    /// The notice shown once the value is saved.
    var savedMessage: LocalizedStringResource {
        switch self {
        case .bodyWeight: "Peso salvo"
        case .height: "Altura salva"
        case .dailyCalorieGoal: "Meta salva"
        }
    }
}

/// The − and + of the body data editor: their steps, the limits they never pass and the value they
/// start from. Pure logic: no UI and no store access.
enum MetricEditing {
    enum Direction: Sendable {
        case down
        case up
    }

    /// 0,1 kg, 1 cm and 50 kcal.
    static func step(of metric: BodyMetric) -> Double {
        switch metric {
        case .bodyWeight: 0.1
        case .height: 1
        case .dailyCalorieGoal: 50
        }
    }

    /// The values that can be saved: 20–300 kg, 100–250 cm and 800–8.000 kcal (`Validation`).
    static func range(of metric: BodyMetric) -> ClosedRange<Double> {
        switch metric {
        case .bodyWeight: Validation.bodyWeightRangeKg
        case .height: Double(Validation.heightRangeCm.lowerBound)...Double(Validation.heightRangeCm.upperBound)
        case .dailyCalorieGoal:
            Double(Validation.dailyCalorieGoalRangeKcal.lowerBound)...Double(Validation.dailyCalorieGoalRangeKcal.upperBound)
        }
    }

    /// Where − and + start when nothing is typed or saved: 70,0 kg, 170 cm and 2.000 kcal.
    static func referenceValue(of metric: BodyMetric) -> Double {
        switch metric {
        case .bodyWeight: 70
        case .height: 170
        case .dailyCalorieGoal: 2_000
        }
    }

    /// The value − and + start from: the number typed in the field, even beyond the limits; with the
    /// field empty or unreadable, the saved value; without one, `referenceValue(of:)`.
    static func base(of metric: BodyMetric, text: String, saved: Double?) -> Double {
        HomeSummary.typedNumber(text, for: metric) ?? saved ?? referenceValue(of: metric)
    }

    /// `value` one step up or down, kept within the limits. Counted in hundredths, so a step never
    /// leaves the remainder of binary arithmetic (80,25 + 0,1 = 80,35).
    static func stepped(_ value: Double, metric: BodyMetric, direction: Direction) -> Double {
        let limits = range(of: metric)
        let hundredths = (value * 100).rounded()
        let step = (step(of: metric) * 100).rounded()
        let next = (direction == .up ? hundredths + step : hundredths - step) / 100
        return min(max(next, limits.lowerBound), limits.upperBound)
    }

    /// Whether a step from `value` changes it: not up at the upper limit or above, not down at the
    /// lower limit or below.
    static func canStep(_ value: Double, metric: BodyMetric, direction: Direction) -> Bool {
        let limits = range(of: metric)
        return direction == .up ? value < limits.upperBound : value > limits.lowerBound
    }
}
