import Foundation
import SwiftData

typealias Exercise = SchemaV8.Exercise

extension SchemaV8 {
    /// An exercise in the library: built into the app or created by the user.
    @Model
    final class Exercise {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var name: String = ""
        /// Stable storage key of the muscle group; read and write it through `muscleGroup`.
        var muscleGroupRaw: String = MuscleGroup.other.rawValue
        var isCustom: Bool = false
        var isArchived: Bool = false
        /// Stable key of a built-in exercise; `nil` for custom exercises.
        var libraryKey: String?
        /// Stable key of the equipment of a custom exercise (`Equipment`); `nil` is "Outro". Read and write
        /// it through `equipment`. A built-in exercise leaves it empty: the library knows its equipment.
        /// Added in version 8; the custom exercises of older stores are migrated without one.
        var equipmentRaw: String?
        /// Stable key of the kind of machine of a custom exercise done on a machine (`MachineType`); read and
        /// write it through `machineType`. Added in version 8, empty for older exercises.
        var machineTypeRaw: String?
        /// Stable keys of the main muscles of a custom exercise (`Muscle`), in the order shown; read and write
        /// them through `primaryMuscles`. Added in version 8: `nil` for the custom exercises of older stores,
        /// which show the muscle of their group, and empty when none was chosen ("Corpo inteiro").
        var primaryMuscleKeys: [String]?
        /// Stable keys of the secondary muscles of a custom exercise, in the order shown; read and write them
        /// through `secondaryMuscles`. Added in version 8: `nil` for older exercises, as `primaryMuscleKeys`.
        var secondaryMuscleKeys: [String]?

        /// Planned uses of this exercise. Deleting the exercise only clears the reference.
        @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
        var workoutExercises: [WorkoutExercise] = []

        /// Performed uses of this exercise (history). Deleting the exercise only clears
        /// the reference; the history stays readable through its snapshots.
        @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
        var sessionExercises: [SessionExercise] = []

        init(name: String, muscleGroup: MuscleGroup, isCustom: Bool, libraryKey: String? = nil) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.name = name
            self.muscleGroupRaw = muscleGroup.rawValue
            self.isCustom = isCustom
            self.libraryKey = libraryKey
        }

        var muscleGroup: MuscleGroup {
            get { MuscleGroup(storageKey: muscleGroupRaw) }
            set { muscleGroupRaw = newValue.rawValue }
        }

        /// The equipment of a custom exercise; `nil` is "Outro". An unknown key, written by a newer version
        /// of the app, reads as `nil`.
        var equipment: Equipment? {
            get { equipmentRaw.flatMap(Equipment.init(rawValue:)) }
            set { equipmentRaw = newValue?.rawValue }
        }

        /// The kind of machine of a custom exercise; an unknown key reads as `nil`.
        var machineType: MachineType? {
            get { machineTypeRaw.flatMap(MachineType.init(rawValue:)) }
            set { machineTypeRaw = newValue?.rawValue }
        }

        /// The main muscles of a custom exercise; unknown keys are left out.
        var primaryMuscles: [Muscle] {
            get { (primaryMuscleKeys ?? []).compactMap(Muscle.init(rawValue:)) }
            set { primaryMuscleKeys = newValue.map(\.rawValue) }
        }

        /// The secondary muscles of a custom exercise; unknown keys are left out.
        var secondaryMuscles: [Muscle] {
            get { (secondaryMuscleKeys ?? []).compactMap(Muscle.init(rawValue:)) }
            set { secondaryMuscleKeys = newValue.map(\.rawValue) }
        }

        /// Whether the muscles of this custom exercise were chosen, none included: every exercise created or
        /// edited from version 8 on. One from an older store has none stored and shows the muscle of its group.
        var hasChosenMuscles: Bool {
            primaryMuscleKeys != nil || secondaryMuscleKeys != nil
        }
    }
}
