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

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        profile = ProfileService(context: container.mainContext, now: clock.now)
    }

    @Test("There is no weight and no profile at first")
    func emptyAtFirst() throws {
        #expect(try profile.latestWeight() == nil)
        #expect(try profile.profile() == nil)
    }

    @Test("Each weight is a new measurement; the latest is the most recent")
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

    @Test("An invalid weight is rejected and saves nothing")
    func invalidWeight() throws {
        try profile.recordWeight(80)
        for invalid in [19.99, 300.01, 80.123, .nan] {
            #expect(throws: ValidationError.invalidBodyWeight) { try profile.recordWeight(invalid) }
        }
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

    @Test("Body data survives closing and reopening the store")
    func bodyDataSurvivesReopening() throws {
        try roundTripThroughDisk { context in
            let service = ProfileService(context: context)
            try service.recordWeight(79.5)
            try service.recordWeight(80.25)
            try service.setHeight(180)
            try service.setDailyCalorieGoal(2_300)
        } read: { context in
            let service = ProfileService(context: context)
            let weightCount = try count(BodyWeightEntry.self, in: context)
            let profile = try #require(try service.profile())
            #expect(weightCount == 2)
            #expect(try service.latestWeight()?.weightKg == 80.25)
            #expect(profile.heightCm == 180)
            #expect(profile.dailyCalorieGoalKcal == 2_300)
        }
    }
}
