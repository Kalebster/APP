import Foundation

/// One exercise of the built-in library: a combination of a base exercise with an equipment and, when the
/// base has one, a grip or variation ("Supino Reto (Barra)", "Puxada Alta Triângulo (Polia)"). Each
/// combination has its own history, evolution and records.
struct DefaultExercise: Equatable, Sendable {
    /// Stable business identity. Never changed, removed or reused.
    let key: String
    /// Fixed UUID, the same on every install. Never changed or reused.
    let id: String
    /// The name stored and shown in the workouts, the session and the history.
    let name: String
    let muscleGroup: MuscleGroup
    /// The name of its base exercise (`ExerciseBase.name`). Library data only, never stored, like the
    /// fields below: the app finds them through the stored `libraryKey` (`DefaultExerciseLibrary.byKey`).
    let base: String
    /// The button of the EQUIPAMENTO row.
    let option: LibraryEquipment
    /// The button of the PEGADA or VARIAÇÃO row; `nil` when the base has none.
    let variation: String?
    /// The muscles it works the most ("Peitoral superior").
    let focus: String
    /// Common in its base: a normal button. The others are grey, and can be chosen all the same.
    let isCommon: Bool

    /// What the exercise is done with, for the equipment filter and the icon.
    var equipment: Equipment {
        option.equipment
    }
}

/// The built-in exercise library, controlled by the app: the 1,525 combinations of the base list approved
/// by the owner on 26/11/2026 (design/lista-base-dados.json), base by base, in the order of the approved
/// list. The first combination of each base is the one its screen opens on when it was never done.
///
/// Rules: keys and ids are never changed, removed or reused. The 315 exercises of the library of 420 that
/// stay keep their key and id (283 with the same name, 32 renamed and the 4 junctions, which keep the key of
/// their first exercise); the 1,214 new combinations got theirs once, here. Name and muscle group may be
/// corrected in a later version. The exercises that left the list are in `RetiredExercises`.
///
/// Names: the base, then the grip or variation, then the equipment in parentheses ("Barra Fixa Fechada
/// (Graviton)"), as approved. They have up to `maxNameLength` characters.
enum DefaultExerciseLibrary {
    /// The longest a library name may be: 62, two more than a name typed by the person
    /// (`Validation.maxNameLength`), for "Elevação de Pernas Joelhos na Barra Fixa Iso-Lateral (Máquina)"
    /// (owner's decision, 27/11/2026).
    static let maxNameLength = 62

    /// The combinations, read once from `ExerciseLibrary.json` (`ExerciseLibraryFile`); empty when the file
    /// could not be read.
    static let all: [DefaultExercise] = ExerciseLibraryFile.entries.map { entry in
        DefaultExercise(
            key: entry.key,
            id: entry.id,
            name: entry.name,
            muscleGroup: entry.group,
            base: entry.base,
            option: entry.option,
            variation: entry.variation,
            focus: entry.focus,
            isCommon: entry.common
        )
    }

    /// The entries by key, built once: what the library says of a built-in exercise that the store does
    /// not keep (its base, equipment, variation and focus).
    static let byKey: [String: DefaultExercise] = Dictionary(all.map { ($0.key, $0) }) { first, _ in first }
}
