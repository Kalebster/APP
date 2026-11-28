import Foundation

/// The muscles of a library exercise, and its kind of machine when it is done on one: library data
/// only, never stored, found by the exercise's stable key (`Exercise.libraryKey`), like the equipment
/// and the focus of `DefaultExerciseLibrary`. Every key of the library has exactly one entry, in the
/// library's order; the values are those of the approved base list (design/lista-base-dados.json), where a
/// new combination has the muscles and the kind of machine of the same variation on another equipment.
///
/// Rules (checked by the tests): at least one main muscle; no muscle both main and secondary; a kind of
/// machine only on an exercise whose equipment is `Equipment.machine`.
struct DefaultExerciseMuscles: Equatable, Sendable {
    let key: String
    /// The muscles the exercise works the most, in the order shown.
    let primary: [Muscle]
    /// The muscles that help, in the order shown; often none.
    let secondary: [Muscle]
    /// The kind of machine, for an exercise done on one.
    var machine: MachineType?

    /// The entry of the library exercise with `key`.
    static let byKey: [String: DefaultExerciseMuscles] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })

    /// Whether the exercise is done on a Graviton (counterweight) machine, whose kg is the help of the
    /// machine: its sets never count in the kg lifted, and its evolution reads less kg as better. True for
    /// the 4 Graviton exercises of the library and for an exercise of the user's own whose kind of machine
    /// is Graviton.
    static func isAssisted(_ exercise: Exercise?) -> Bool {
        guard let exercise else { return false }
        return machine(of: exercise) == .graviton
    }

    /// The muscles shown for an exercise: those of its library entry, those an exercise of the user's own
    /// chose (none included, for "Corpo inteiro"), or the muscles of its group (none for "Corpo inteiro"
    /// and "Outro") for one of the user's own that `showsGroupMuscles`.
    static func muscles(of exercise: Exercise) -> (primary: [Muscle], secondary: [Muscle]) {
        if exercise.isCustom {
            if showsGroupMuscles(of: exercise) {
                return (muscles(of: exercise.muscleGroup), [])
            }
            return (exercise.primaryMuscles, exercise.secondaryMuscles)
        }
        if let key = exercise.libraryKey, let entry = byKey[key] {
            return (entry.primary, entry.secondary)
        }
        return (muscles(of: exercise.muscleGroup), [])
    }

    /// Whether the body figure shows the muscles of the exercise's group: an exercise of the user's own from
    /// before version 8, whose muscles were never chosen, or one whose stored muscles are all unknown to this
    /// version (written by a newer one). One saved with none chosen shows none.
    static func showsGroupMuscles(of exercise: Exercise) -> Bool {
        guard exercise.isCustom else { return false }
        guard exercise.hasChosenMuscles else { return true }
        let stored = (exercise.primaryMuscleKeys ?? []) + (exercise.secondaryMuscleKeys ?? [])
        return !stored.isEmpty && exercise.primaryMuscles.isEmpty && exercise.secondaryMuscles.isEmpty
    }

    /// The kind of machine: the library's for a built-in exercise, the one chosen for an exercise of the
    /// user's own (only when its equipment is the machine).
    static func machine(of exercise: Exercise) -> MachineType? {
        if exercise.isCustom {
            return exercise.equipment == .machine ? exercise.machineType : nil
        }
        guard let key = exercise.libraryKey else { return nil }
        return byKey[key]?.machine
    }

    /// The equipment: the library's for a built-in exercise, the one chosen for an exercise of the user's
    /// own; `nil` is "Outro".
    static func equipment(of exercise: Exercise) -> Equipment? {
        if exercise.isCustom {
            return exercise.equipment
        }
        return exercise.libraryKey.flatMap { DefaultExerciseLibrary.byKey[$0] }?.equipment
    }

    /// The muscles of a muscle group, for an exercise of the user's own, as in the prototype.
    static func muscles(of group: MuscleGroup) -> [Muscle] {
        switch group {
        case .chest: [.chest]
        case .back: [.lats]
        case .upperBack: [.upperBack]
        case .traps: [.traps]
        case .lowerBack: [.lowerBack]
        case .shoulders: [.frontDelts, .sideDelts, .rearDelts]
        case .biceps: [.biceps]
        case .triceps: [.triceps]
        case .forearms: [.forearms]
        case .abs: [.abs]
        case .quadriceps: [.quadriceps]
        case .hamstrings: [.hamstrings]
        case .glutes: [.glutes]
        case .adductors: [.adductors]
        case .calves: [.calves]
        case .fullBody, .other: []
        }
    }

    /// The entries, read once from `ExerciseLibrary.json` with the combinations (`ExerciseLibraryFile`).
    static let all: [DefaultExerciseMuscles] = ExerciseLibraryFile.entries.map { entry in
        DefaultExerciseMuscles(key: entry.key, primary: entry.primary, secondary: entry.secondary, machine: entry.machine)
    }
}
