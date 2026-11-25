import Foundation
import Testing
@testable import IronFlow

struct MuscleTests {
    /// The keys are stored in the exercises of the user's own: they never change, whatever the names shown.
    @Test("Muscle keys are stable and unique")
    func stableMuscleKeys() {
        let keys = Muscle.allCases.map(\.rawValue)
        #expect(keys == [
            "chest", "frontDelts", "sideDelts", "rearDelts", "biceps", "triceps", "forearms", "abs", "obliques",
            "quadriceps", "adductors", "tibialis", "traps", "upperBack", "rotatorCuff", "lats", "lowerBack", "glutes",
            "gluteusMedius", "hamstrings", "calves",
        ])
        #expect(Set(keys).count == keys.count)
    }

    @Test("Kind of machine keys are stable and unique")
    func stableMachineTypeKeys() {
        let keys = MachineType.allCases.map(\.rawValue)
        #expect(keys == ["plates", "lever", "track", "graviton", "ghd"])
        #expect(Set(keys).count == keys.count)
    }

    @Test("The choices go from the top of the body down, with every muscle once")
    func bodyOrder() {
        #expect(Muscle.bodyOrder.count == Muscle.allCases.count)
        #expect(Set(Muscle.bodyOrder) == Set(Muscle.allCases))
        #expect(Muscle.bodyOrder.map { String(localized: $0.displayName) } == [
            "Trapézio", "Deltoide anterior", "Deltoide lateral", "Deltoide posterior", "Manguito rotador", "Peitoral",
            "Costas superiores", "Dorsais", "Bíceps", "Tríceps", "Antebraços", "Abdômen", "Oblíquos", "Lombar",
            "Glúteos", "Glúteo médio", "Adutores", "Quadríceps", "Posteriores de coxa", "Tibial anterior", "Panturrilhas",
        ])
    }

    @Test("An unknown key, written by a newer version, is read as nothing, never as another value")
    func unknownKeys() {
        #expect(Muscle(rawValue: "neck") == nil)
        #expect(MachineType(rawValue: "hydraulic") == nil)
        let exercise = Exercise(name: "Meu", muscleGroup: .back, isCustom: true)
        exercise.primaryMuscleKeys = ["lats", "neck"]
        exercise.equipmentRaw = "sled"
        exercise.machineTypeRaw = "hydraulic"
        #expect(exercise.primaryMuscles == [.lats])
        #expect(exercise.equipment == nil)
        #expect(exercise.machineType == nil)
    }
}
