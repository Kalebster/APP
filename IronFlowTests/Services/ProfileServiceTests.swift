import Foundation
import SwiftData
import Testing
@testable import IronFlow

@MainActor
struct ProfileServiceTests {
    let container: ModelContainer
    let clock = TestClock()
    let profile: ProfileService

    var context: ModelContext { container.mainContext }

    /// The days of the body weight, in a fixed time zone: the clock starts at 06:13 there.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        profile = ProfileService(context: container.mainContext, now: clock.now, calendar: Self.calendar)
    }

    @Test("There is no weight and no profile at first")
    func emptyAtFirst() throws {
        #expect(try profile.latestWeight() == nil)
        #expect(try profile.profile() == nil)
    }

    @Test("Each day's weight is a new measurement; the latest is the most recent")
    func weightHistory() throws {
        let first = try profile.recordWeight(80)
        #expect(first.measuredAt == clock.current)
        clock.advance(by: 86_400)
        let second = try profile.recordWeight(81.25)

        #expect(try profile.latestWeight()?.id == second.id)
        #expect(try profile.latestWeight()?.weightKg == 81.25)
        #expect(second.measuredAt == clock.current)
        #expect(try count(BodyWeightEntry.self, in: context) == 2)
        #expect(first.weightKg == 80)
        #expect(context.hasChanges == false)
    }

    @Test("A weight saved again the same day updates the day's record; the other days never change")
    func oneWeightPerDay() throws {
        let yesterday = try profile.recordWeight(81.2)
        clock.advance(by: 86_400)
        let today = try profile.recordWeight(80.6)
        clock.advance(by: 3 * 3_600)
        let again = try profile.recordWeight(80)

        #expect(again.id == today.id)
        #expect(today.weightKg == 80)
        #expect(today.measuredAt == clock.current)
        #expect(today.updatedAt == clock.current)
        #expect(yesterday.weightKg == 81.2)
        #expect(try count(BodyWeightEntry.self, in: context) == 2)
        #expect(try profile.latestWeight()?.id == today.id)
        #expect(context.hasChanges == false)

        // The next day is a new record again.
        clock.advance(by: 86_400)
        let tomorrow = try profile.recordWeight(79.8)
        #expect(tomorrow.id != today.id)
        #expect(try count(BodyWeightEntry.self, in: context) == 3)
        #expect(today.weightKg == 80)
    }

    @Test("Should a day hold two weights from before, saving again updates the latest of them only")
    func dayWithTwoOldRecords() throws {
        let timestamp = clock.current
        let older = BodyWeightEntry(weightKg: 81, measuredAt: timestamp)
        let newer = BodyWeightEntry(weightKg: 80.5, measuredAt: timestamp.addingTimeInterval(60))
        context.insert(older)
        context.insert(newer)
        try context.save()
        clock.advance(by: 120)

        let saved = try profile.recordWeight(80)
        #expect(saved.id == newer.id)
        #expect(newer.weightKg == 80)
        #expect(older.weightKg == 81)
        #expect(try count(BodyWeightEntry.self, in: context) == 2)
    }

    @Test("The editor's latest records: at most four, the newest first")
    func recentWeights() throws {
        for weight in [82.0, 81.5, 81.2, 80.6, 80.0] {
            try profile.recordWeight(weight)
            clock.advance(by: 86_400)
        }
        let recent = try context.fetch(ProfileService.recentWeightsDescriptor)
        #expect(recent.map(\.weightKg) == [80.0, 80.6, 81.2, 81.5])
    }

    @Test("An invalid weight is rejected and saves nothing")
    func invalidWeight() throws {
        try profile.recordWeight(80)
        for invalid in [19.99, 300.01, .nan] {
            #expect(throws: ValidationError.invalidBodyWeight) { try profile.recordWeight(invalid) }
        }
        #expect(throws: ValidationError.tooManyDecimals) { try profile.recordWeight(80.123) }
        #expect(try count(BodyWeightEntry.self, in: context) == 1)
        #expect(try profile.latestWeight()?.weightKg == 80)
        #expect(context.hasChanges == false)
    }

    @Test("Height and calorie goal are kept in a single profile")
    func singleProfile() throws {
        try profile.setHeight(180)
        let created = try #require(try profile.profile())
        #expect(created.createdAt == clock.current)
        clock.advance(by: 60)
        try profile.setDailyCalorieGoal(2_300)
        try profile.setHeight(181)

        #expect(try count(UserProfile.self, in: context) == 1)
        let stored = try #require(try profile.profile())
        #expect(stored.id == created.id)
        #expect(stored.heightCm == 181)
        #expect(stored.dailyCalorieGoalKcal == 2_300)
        #expect(stored.updatedAt == clock.current)
        #expect(context.hasChanges == false)
    }

    @Test("Invalid height or goal changes nothing, not even a new profile")
    func invalidHeightAndGoal() throws {
        #expect(throws: ValidationError.invalidHeight) { try profile.setHeight(99) }
        #expect(throws: ValidationError.invalidCalorieGoal) { try profile.setDailyCalorieGoal(8_001) }
        #expect(try count(UserProfile.self, in: context) == 0)

        try profile.setHeight(180)
        try profile.setDailyCalorieGoal(2_300)
        #expect(throws: ValidationError.invalidHeight) { try profile.setHeight(251) }
        #expect(throws: ValidationError.invalidCalorieGoal) { try profile.setDailyCalorieGoal(799) }
        #expect(try profile.profile()?.heightCm == 180)
        #expect(try profile.profile()?.dailyCalorieGoalKcal == 2_300)
        #expect(context.hasChanges == false)
    }

    @Test("The calculator's choices start empty, with a moderate level and the goal of keeping the weight")
    func calculatorDefaults() throws {
        try profile.setHeight(180)
        let saved = try #require(try profile.profile())
        #expect(saved.sex == nil)
        #expect(saved.birthDate == BirthDate())
        #expect(saved.activityLevel == .moderate)
        #expect(saved.weightGoal == .maintain)
    }

    @Test("Each choice of the calculator is saved at once, in the single profile, and keeps the other data")
    func calculatorChoices() throws {
        try profile.setHeight(180)
        clock.advance(by: 60)
        try profile.setSex(.male)
        #expect(try profile.profile()?.updatedAt == clock.current)
        try profile.setBirthDate(BirthDate(day: 12, month: nil, year: nil))
        try profile.setBirthDate(BirthDate(day: 12, month: 5, year: 1994))
        try profile.setActivityLevel(.light)
        try profile.setWeightGoal(.gain)

        let saved = try #require(try profile.profile())
        #expect(try count(UserProfile.self, in: context) == 1)
        #expect(saved.heightCm == 180)
        #expect(saved.sexRaw == "male")
        #expect(saved.birthDate == BirthDate(day: 12, month: 5, year: 1994))
        #expect(saved.activityLevelRaw == "light")
        #expect(saved.weightGoalRaw == "gain")
        #expect(context.hasChanges == false)
    }

    @Test("The first choice creates the profile, and a part of the date of birth is saved on its own")
    func firstChoiceCreatesTheProfile() throws {
        try profile.setBirthDate(BirthDate(day: nil, month: 2, year: nil))
        let saved = try #require(try profile.profile())
        #expect(saved.birthDate == BirthDate(day: nil, month: 2, year: nil))
        #expect(saved.createdAt == clock.current)
        #expect(saved.heightCm == nil)
    }

    @Test("A day beyond its month is saved as the month's last day")
    func birthDayKeptInMonth() throws {
        try profile.setBirthDate(BirthDate(day: 31, month: 4, year: 1990))
        #expect(try profile.profile()?.birthDate == BirthDate(day: 30, month: 4, year: 1990))
        try profile.setBirthDate(BirthDate(day: 31, month: 2, year: 1990))
        #expect(try profile.profile()?.birthDate == BirthDate(day: 28, month: 2, year: 1990))
        try profile.setBirthDate(BirthDate(day: 30, month: 2, year: 1992))
        #expect(try profile.profile()?.birthDate == BirthDate(day: 29, month: 2, year: 1992))
        // Without the year, February keeps the 29th; the year chosen later brings it to the 28th.
        try profile.setBirthDate(BirthDate(day: 31, month: 2, year: nil))
        #expect(try profile.profile()?.birthDate == BirthDate(day: 29, month: 2, year: nil))
        try profile.setBirthDate(BirthDate(day: 29, month: 2, year: 2001))
        #expect(try profile.profile()?.birthDate == BirthDate(day: 28, month: 2, year: 2001))
        try profile.setBirthDate(BirthDate(day: 29, month: 2, year: 2000))
        #expect(try profile.profile()?.birthDate == BirthDate(day: 29, month: 2, year: 2000))
    }

    @Test("Body data survives closing and reopening the store")
    func bodyDataSurvivesReopening() throws {
        try roundTripThroughDisk { context in
            let service = ProfileService(context: context, now: clock.now, calendar: Self.calendar)
            try service.recordWeight(79.5)
            clock.advance(by: 86_400)
            try service.recordWeight(80.25)
            try service.setHeight(180)
            try service.setDailyCalorieGoal(2_300)
            try service.setSex(.female)
            try service.setBirthDate(BirthDate(day: 1, month: 1, year: 1990))
            try service.setActivityLevel(.veryIntense)
            try service.setWeightGoal(.lose)
        } read: { context in
            let service = ProfileService(context: context)
            let weightCount = try count(BodyWeightEntry.self, in: context)
            let profile = try #require(try service.profile())
            #expect(weightCount == 2)
            #expect(try service.latestWeight()?.weightKg == 80.25)
            #expect(profile.heightCm == 180)
            #expect(profile.dailyCalorieGoalKcal == 2_300)
            #expect(profile.sex == .female)
            #expect(profile.birthDate == BirthDate(day: 1, month: 1, year: 1990))
            #expect(profile.activityLevel == .veryIntense)
            #expect(profile.weightGoal == .lose)
        }
    }
}
