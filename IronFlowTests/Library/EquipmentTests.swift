import Foundation
import Testing
@testable import IronFlow

struct EquipmentTests {
    @Test("Nine kinds of equipment in the approved order, which is the order of the filters, with their Portuguese names")
    func approvedOrderAndNames() {
        let names = Equipment.allCases.map { String(localized: $0.displayName) }
        #expect(names == ["Barra", "Halteres", "Máquina", "Polia", "Smith", "Peso do corpo", "Kettlebell", "Elástico", "Anilha"])
    }

    /// The keys belong to the library: a later version may store them, so they never change.
    @Test("Keys are stable and unique")
    func stableKeys() {
        let keys = Equipment.allCases.map(\.rawValue)
        #expect(keys == ["barbell", "dumbbell", "machine", "cable", "smith", "bodyweight", "kettlebell", "band", "plate"])
        #expect(Set(keys).count == keys.count)
    }
}
