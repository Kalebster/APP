import Foundation
import Testing
@testable import IronFlow

struct MuscleGroupTests {
    @Test("Thirteen groups in the approved order with their Portuguese names")
    func approvedGroupsAndNames() {
        let names = MuscleGroup.allCases.map { String(localized: $0.displayName) }
        #expect(names == [
            "Peito", "Costas", "Ombros", "Bíceps", "Tríceps", "Antebraços", "Quadríceps",
            "Posteriores de coxa", "Glúteos", "Panturrilhas", "Abdômen", "Corpo inteiro", "Outro",
        ])
    }

    /// Storage keys are written to the database: changing one would break existing data.
    @Test("Storage keys are stable and unique")
    func storageKeysAreStable() {
        let keys = MuscleGroup.allCases.map(\.rawValue)
        #expect(keys == [
            "chest", "back", "shoulders", "biceps", "triceps", "forearms", "quadriceps",
            "hamstrings", "glutes", "calves", "abs", "fullBody", "other",
        ])
        #expect(Set(keys).count == keys.count)
    }

    @Test("Known keys map to their group and unknown keys to Outro")
    func storageKeyDecoding() {
        for group in MuscleGroup.allCases {
            #expect(MuscleGroup(storageKey: group.rawValue) == group)
        }
        #expect(MuscleGroup(storageKey: "neck") == .other)
        #expect(MuscleGroup(storageKey: "") == .other)
    }
}
