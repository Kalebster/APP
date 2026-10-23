import Foundation
import Testing
@testable import IronFlow

struct SetTypeTests {
    @Test("Four types in the approved order with their Portuguese names and explanations")
    func approvedTypesNamesAndExplanations() {
        #expect(SetType.allCases.map { String(localized: $0.displayName) } == ["Aquecimento", "Preparatória", "Válida", "Falha"])
        #expect(SetType.allCases.map { String(localized: $0.explanation) } == [
            "Leve, para aquecer. Não conta nos kg levantados.",
            "Mais pesada, para chegar pronto na carga. Não conta nos kg levantados.",
            "A série de trabalho. Conta nos kg levantados.",
            "Até não conseguir mais repetições. Conta nos kg levantados.",
        ])
    }

    /// Storage keys are written to the database: changing one would break existing data.
    @Test("Storage keys are stable and unique")
    func storageKeysAreStable() {
        let keys = SetType.allCases.map(\.rawValue)
        #expect(keys == ["warmup", "feeder", "working", "failure"])
        #expect(Set(keys).count == keys.count)
    }

    @Test("Known keys map to their type and unknown keys to Válida")
    func storageKeyDecoding() {
        for type in SetType.allCases {
            #expect(SetType(storageKey: type.rawValue) == type)
        }
        #expect(SetType(storageKey: "dropset") == .working)
        #expect(SetType(storageKey: "") == .working)
    }

    @Test("Only working and failure sets count in the load lifted")
    func liftedLoad() {
        #expect(SetType.allCases.filter(\.countsTowardLiftedLoad) == [.working, .failure])
    }

    @Test("A copy of a warm-up or feeder set is a working set; the others keep their type")
    func typeOfCopy() {
        #expect(SetType.allCases.map(\.typeOfCopy) == [.working, .working, .working, .failure])
    }
}
