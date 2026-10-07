import Foundation
import Testing
@testable import IronFlow

@MainActor
struct HomeSummaryTests {
    @Test("Without a saved choice the three indicators are shown in the default order")
    func defaultMetrics() {
        #expect(HomeSummary.metrics(fromStored: nil) == [.bodyWeight, .height, .dailyCalorieGoal])
        #expect(HomeSummary.defaultMetrics == SummaryMetric.allCases)
    }

    @Test("A saved choice keeps its order; unknown and repeated entries are ignored")
    func savedChoice() {
        #expect(HomeSummary.metrics(fromStored: "") == [])
        #expect(HomeSummary.metrics(fromStored: "dailyCalorieGoal,bodyWeight") == [.dailyCalorieGoal, .bodyWeight])
        #expect(HomeSummary.metrics(fromStored: "height,height,unknown,bodyWeight") == [.height, .bodyWeight])
        let choice: [SummaryMetric] = [.height, .dailyCalorieGoal]
        #expect(HomeSummary.metrics(fromStored: HomeSummary.storedValue(for: choice)) == choice)
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
        #expect(HomeSummary.fieldText(nil) == "")
        #expect(HomeSummary.fieldText(80.5) == "80,5")
        #expect(HomeSummary.fieldText(2_300) == "2300")
    }

    @Test("Typed values are read and checked for each indicator; an empty field has no value")
    func typedValues() throws {
        #expect(try HomeSummary.value(for: .bodyWeight, text: "") == nil)
        #expect(try HomeSummary.value(for: .bodyWeight, text: "80,5") == 80.5)
        #expect(try HomeSummary.value(for: .bodyWeight, text: " 80.5 ") == 80.5)
        for invalid in ["19", "301", "abc", "80,123", "-80"] {
            #expect(throws: ValidationError.invalidBodyWeight) { try HomeSummary.value(for: .bodyWeight, text: invalid) }
        }
        #expect(try HomeSummary.value(for: .height, text: "180") == 180)
        for invalid in ["99", "251", "1,8", "abc"] {
            #expect(throws: ValidationError.invalidHeight) { try HomeSummary.value(for: .height, text: invalid) }
        }
        #expect(try HomeSummary.value(for: .dailyCalorieGoal, text: "2300") == 2_300)
        for invalid in ["2.300", "799", "8001", "99999999999999999999"] {
            #expect(throws: ValidationError.invalidCalorieGoal) { try HomeSummary.value(for: .dailyCalorieGoal, text: invalid) }
        }
    }

    @Test("Today's workout: a session in progress first, then whether workouts exist")
    func todayWorkoutState() {
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: false) == .noWorkouts)
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true) == .nothingPlanned)

        let older = Session(startedAt: Date(timeIntervalSinceReferenceDate: 1_000), workoutNameSnapshot: "Push")
        let newer = Session(startedAt: Date(timeIntervalSinceReferenceDate: 2_000), workoutNameSnapshot: "Pull")
        #expect(TodayWorkoutState.resolve(activeSessions: [older, newer], hasWorkouts: false)
            == .inProgress(name: "Pull", startedAt: Date(timeIntervalSinceReferenceDate: 2_000)))
    }
}
