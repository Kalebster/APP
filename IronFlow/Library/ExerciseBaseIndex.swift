import Foundation

/// The library by base exercise, built once on first use: what the Exercícios tab, the picker, the
/// exercise screen and the choice sheet ask of it. Library data only, no store access.
enum ExerciseBaseIndex {
    /// The bases by name.
    static let bases: [String: ExerciseBase] = Dictionary(uniqueKeysWithValues: ExerciseBaseLibrary.all.map { ($0.name, $0) })

    /// The combinations of each base, in the library's order: the first is the one its screen opens on
    /// when none was done.
    static let combinations: [String: [DefaultExercise]] = Dictionary(grouping: DefaultExerciseLibrary.all, by: \.base)

    /// Each combination by its base, equipment and second-row option.
    private static let byChoice: [Choice: DefaultExercise] = Dictionary(
        DefaultExerciseLibrary.all.map { (Choice(base: $0.base, option: $0.option, variation: $0.variation), $0) }
    ) { first, _ in first }

    private struct Choice: Hashable {
        let base: String
        let option: LibraryEquipment
        let variation: String?
    }

    /// The combination of `base` done with `option` and, when the base has a second row, `variation`.
    static func combination(of base: String, option: LibraryEquipment, variation: String?) -> DefaultExercise? {
        byChoice[Choice(base: base, option: option, variation: variation)]
    }

    /// The base of a library exercise, by its key.
    static func base(ofKey key: String) -> ExerciseBase? {
        DefaultExerciseLibrary.byKey[key].flatMap { bases[$0.base] }
    }

    /// The equipment the equipment filter finds a base by: that of its common combinations.
    static let filterEquipment: [String: Set<Equipment>] = Dictionary(uniqueKeysWithValues: ExerciseBaseLibrary.all.map { base in
        (base.name, Set(base.common.map(\.equipment)))
    })

    /// The common equipment of a base as its row shows it: "Barra, Halteres, Máquina +3", or all of them
    /// when there are up to 3.
    static func commonText(of base: ExerciseBase) -> String {
        let names = base.common.map { String(localized: $0.displayName) }
        guard names.count > 3 else { return names.joined(separator: ", ") }
        return names.prefix(3).joined(separator: ", ") + " +\(names.count - 3)"
    }

    /// What the search compares for each base, computed once (`Validation.comparisonKey`): its name, the
    /// extra words (popular and old names), the options of its second row, the name of each common
    /// combination with the name of its equipment and of the equipment of the filter, and the old names of
    /// its combinations (those of the exercises renamed or merged into them). Separated by spaces, so a word
    /// typed never runs from one into the next.
    static let searchKeys: [String: String] = Dictionary(uniqueKeysWithValues: ExerciseBaseLibrary.all.map { base in
        (base.name, searchKey(of: base))
    })

    private static func searchKey(of base: ExerciseBase) -> String {
        var parts = [base.name, base.extraSearch]
        parts += base.secondRow?.options ?? []
        for combination in combinations[base.name] ?? [] {
            if combination.isCommon {
                parts.append(combination.name)
                parts.append(String(localized: combination.option.displayName))
                parts.append(String(localized: combination.equipment.displayName))
            }
            parts += RetiredExercises.oldNames[combination.key] ?? []
        }
        return Validation.comparisonKey(forName: parts.filter { !$0.isEmpty }.joined(separator: " "))
    }

    /// The text after the equipment of a combination, when its second-row option says something: "Polia ·
    /// Triângulo", "Barra · Alternada"; "Normal", "Reto" and "Convencional" are left out ("Supino Reto (Barra)"
    /// is "Barra").
    static func optionText(of combination: DefaultExercise) -> String {
        let equipment = String(localized: combination.option.displayName)
        guard let variation = combination.variation, !plainVariations.contains(variation) else { return equipment }
        return "\(equipment) · \(variation)"
    }

    /// The second-row options that only say "the usual one".
    private static let plainVariations: Set<String> = ["Normal", "Reto", "Convencional"]
}
