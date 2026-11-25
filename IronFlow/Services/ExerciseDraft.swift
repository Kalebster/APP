import Foundation

/// The equipment chosen for an exercise of the user's own: one of the library's, or "Outro" (none).
enum EquipmentChoice: Hashable, Sendable {
    case equipment(Equipment)
    case other

    /// The choice as the exercise stores it: "Outro" is no equipment.
    init(_ equipment: Equipment?) {
        self = equipment.map(EquipmentChoice.equipment) ?? .other
    }

    /// The equipment stored; `nil` for "Outro".
    var equipment: Equipment? {
        switch self {
        case .equipment(let equipment): equipment
        case .other: nil
        }
    }

    /// The choices in the order of the form: the library's equipment, then "Outro".
    static let all: [EquipmentChoice] = Equipment.allCases.map(EquipmentChoice.equipment) + [.other]
}

/// What an exercise of the user's own is made of, as the form fills it and the service stores it: the
/// name, the muscle group, the equipment, the kind of machine and the main and secondary muscles. Pure
/// data; the rules are checked by `ExerciseService`.
struct ExerciseDraft: Equatable, Sendable {
    var name = ""
    /// `nil` until chosen.
    var group: MuscleGroup?
    /// `nil` until chosen; "Outro" is a choice.
    var equipment: EquipmentChoice?
    /// The kind of machine; it only counts with `Equipment.machine` (see `storedMachine`).
    var machine: MachineType?
    /// In the order of the body (`Muscle.bodyOrder`).
    var primary: [Muscle] = []
    var secondary: [Muscle] = []

    /// The kind of machine as it is stored: only an exercise done on a machine has one.
    var storedMachine: MachineType? {
        equipment == .equipment(.machine) ? machine : nil
    }

    /// Whether the group needs a main muscle: every group but "Corpo inteiro".
    var needsPrimaryMuscle: Bool {
        group != .fullBody
    }
}

extension ExerciseDraft {
    /// What `exercise` is made of: for an exercise of the user's own, what it stored (with the muscles of
    /// its group when it has none of its own, as the exercise screen shows it); for one of the library,
    /// the library's equipment, kind of machine and muscles.
    init(_ exercise: Exercise) {
        let muscles = DefaultExerciseMuscles.muscles(of: exercise)
        self.init(
            name: exercise.name,
            group: exercise.muscleGroup,
            equipment: EquipmentChoice(DefaultExerciseMuscles.equipment(of: exercise)),
            machine: DefaultExerciseMuscles.machine(of: exercise),
            primary: muscles.primary,
            secondary: muscles.secondary
        )
    }
}
