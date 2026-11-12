import Foundation
import Testing
@testable import IronFlow

struct MuscleGroupTests {
    @Test("Seventeen groups in the approved filter order with their Portuguese names")
    func approvedGroupsAndNames() {
        let names = MuscleGroup.allCases.map { String(localized: $0.displayName) }
        #expect(names == [
            "Peito", "Dorsais", "Costas superiores", "Trapézio", "Lombar", "Ombros", "Bíceps", "Tríceps",
            "Antebraços", "Abdômen", "Quadríceps", "Posteriores de coxa", "Glúteos", "Adutores", "Panturrilhas",
            "Corpo inteiro", "Outro",
        ])
    }

    /// Storage keys are written to the database: changing one would break existing data.
    /// The order of the cases is the order of the filters (checked with the names above); the keys are
    /// checked without it.
    @Test("Storage keys are stable and unique: the thirteen first ones as they were, and the four added")
    func storageKeysAreStable() {
        let keys = MuscleGroup.allCases.map(\.rawValue)
        #expect(Set(keys).count == keys.count)
        let firstKeys: Set = [
            "chest", "back", "shoulders", "biceps", "triceps", "forearms", "quadriceps",
            "hamstrings", "glutes", "calves", "abs", "fullBody", "other",
        ]
        let addedKeys: Set = ["upperBack", "traps", "lowerBack", "adductors"]
        #expect(Set(keys) == firstKeys.union(addedKeys))
    }

    @Test("A group stored as back, as every back exercise was before, reads as Dorsais")
    func backReadsAsDorsais() {
        #expect(MuscleGroup(storageKey: "back") == .back)
        #expect(String(localized: MuscleGroup.back.displayName) == "Dorsais")
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
