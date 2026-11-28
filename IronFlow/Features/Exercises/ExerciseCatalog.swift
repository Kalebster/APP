import Foundation

/// The Exercícios tab and the picker: one row per base exercise of the library ("Supino Reto"), whose
/// equipment and grip or variation are chosen on its screen or in the choice sheet, and one per exercise of
/// the user's own; the group and equipment filters, the search and the archived exercises of the user's
/// own. Pure logic: no UI and no store access.
enum ExerciseCatalog {
    /// What the tab reads of a stored exercise of the user's own.
    struct Source: Equatable {
        let id: UUID
        let name: String
        let group: MuscleGroup
        let libraryKey: String?
        let isCustom: Bool
        let isArchived: Bool
        /// The equipment an exercise of the user's own chose (`Exercise.equipmentRaw`); `nil` is "Outro".
        var equipmentKey: String?
    }

    /// A row as the tab and the picker show it.
    struct Item: Identifiable, Equatable {
        /// "base:" and the base's name, or the id of the exercise of the user's own.
        let id: String
        let name: String
        let group: MuscleGroup
        /// The base exercise of a library row; `nil` for an exercise of the user's own.
        let base: ExerciseBase?
        /// The exercise of the user's own; `nil` for a base.
        let exerciseID: UUID?
        /// The icon: the equipment an exercise of the user's own chose (`nil` is "Outro"); for a base, that of
        /// the combination its screen opens on when none was done (the screens show the one done last).
        let equipment: Equipment?
        /// The equipment the filter finds the row by: the common ones of a base, the one of the user's own.
        let filterEquipment: Set<Equipment>
        /// After the group: a base's common equipment ("Barra, Halteres, Máquina +3"), or the equipment of an
        /// exercise of the user's own ("Outro" without one).
        let detail: String
        let isCustom: Bool
        var isArchived = false
        /// What the search compares, computed once (`Validation.comparisonKey`): for a base, `ExerciseBaseIndex.searchKeys`;
        /// for an exercise of the user's own, its name and the name of its equipment ("Outro" is not searched).
        let searchKey: String
    }

    /// The rows: the bases and the active exercises of the user's own, and the archived exercises of the
    /// user's own, each in alphabetical order.
    struct Lists: Equatable {
        var active: [Item] = []
        var archived: [Item] = []

        /// Whether "Meus" is offered in the Exercícios tab: an exercise of the user's own, active or archived.
        var hasCustom: Bool {
            !archived.isEmpty || active.contains(where: \.isCustom)
        }
    }

    /// The group filter: every exercise, the user's own ("Meus") or one muscle group.
    enum GroupFilter: Hashable {
        case all
        case mine
        case group(MuscleGroup)
    }

    /// The 103 bases as rows, built once.
    static let baseItems: [Item] = ExerciseBaseLibrary.all.map { base in
        Item(
            id: "base:\(base.name)",
            name: base.name,
            group: base.group,
            base: base,
            exerciseID: nil,
            equipment: ExerciseBaseIndex.combinations[base.name]?.first?.equipment,
            filterEquipment: ExerciseBaseIndex.filterEquipment[base.name] ?? [],
            detail: ExerciseBaseIndex.commonText(of: base),
            isCustom: false,
            searchKey: ExerciseBaseIndex.searchKeys[base.name] ?? Validation.comparisonKey(forName: base.name)
        )
    }

    /// The bases and the active exercises of the user's own, in alphabetical order.
    static func items(from sources: [Source]) -> [Item] {
        lists(from: sources).active
    }

    /// The bases with the active exercises of the user's own, and the archived exercises of the user's own,
    /// each in alphabetical order (Portuguese, ignoring case and diacritics). The library exercises among
    /// `sources` (hidden ones) are in neither: their base is.
    static func lists(from sources: [Source]) -> Lists {
        var lists = Lists(active: baseItems)
        for source in sources where source.isCustom {
            let equipment = source.equipmentKey.flatMap(Equipment.init(rawValue:))
            let equipmentName = equipment.map { String(localized: $0.displayName) }
            var searchKey = Validation.comparisonKey(forName: source.name)
            if let equipmentName {
                // A space between them: a word typed never has one, so it never runs from the name into
                // the equipment.
                searchKey += " " + Validation.comparisonKey(forName: equipmentName)
            }
            let item = Item(
                id: source.id.uuidString,
                name: source.name,
                group: source.group,
                base: nil,
                exerciseID: source.id,
                equipment: equipment,
                filterEquipment: equipment.map { [$0] } ?? [],
                detail: equipmentName ?? String(localized: "Outro"),
                isCustom: true,
                isArchived: source.isArchived,
                searchKey: searchKey
            )
            if source.isArchived {
                lists.archived.append(item)
            } else {
                lists.active.append(item)
            }
        }
        lists.active.sort(by: alphabetical)
        lists.archived.sort(by: alphabetical)
        return lists
    }

    private static func alphabetical(_ lhs: Item, _ rhs: Item) -> Bool {
        switch lhs.name.localizedStandardCompare(rhs.name) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: lhs.id < rhs.id
        }
    }

    /// The group filters offered: "Todos", "Meus" when there is an active exercise of the user's own (or,
    /// in the Exercícios tab, an archived one: `hasArchivedCustom`), and the groups that have a row, in the
    /// group order.
    static func groupFilters(in items: [Item], hasArchivedCustom: Bool = false) -> [GroupFilter] {
        let groups = Set(items.map(\.group))
        let mine: [GroupFilter] = hasArchivedCustom || items.contains(where: \.isCustom) ? [.mine] : []
        return [.all] + mine + MuscleGroup.allCases.filter(groups.contains).map(GroupFilter.group)
    }

    /// The group filter in use: the one chosen, or "Todos" when it is no longer offered (its last
    /// exercise was archived or deleted).
    static func groupFilter(_ chosen: GroupFilter, in items: [Item], hasArchivedCustom: Bool = false) -> GroupFilter {
        groupFilters(in: items, hasArchivedCustom: hasArchivedCustom).contains(chosen) ? chosen : .all
    }

    /// The archived exercises shown at the end of "Meus", only without a search and without an equipment.
    static func archivedShown(_ archived: [Item], group: GroupFilter, equipment: Equipment?, search: String) -> [Item] {
        guard group == .mine, equipment == nil,
              search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return archived
    }

    /// The equipment of the rows of the group (a base's common ones), in the equipment order.
    static func equipment(for group: GroupFilter, in items: [Item]) -> [Equipment] {
        var used = Set<Equipment>()
        for item in items where matches(item, group: group) {
            used.formUnion(item.filterEquipment)
        }
        return Equipment.allCases.filter(used.contains)
    }

    /// The equipment in use: the one chosen, or none when the group has no row with it.
    static func equipment(_ chosen: Equipment?, for group: GroupFilter, in items: [Item]) -> Equipment? {
        guard let chosen, equipment(for: group, in: items).contains(chosen) else { return nil }
        return chosen
    }

    /// The rows of the group, with the equipment (a base by its common equipment only), that have every
    /// word of the search, in the order given.
    ///
    /// The search is split into words at any whitespace, so extra spaces do not count, and each word may
    /// be any part of the row's search text, in any order ("barra supino" finds "Supino Reto"), ignoring
    /// case and diacritics. A base is found by its name, its extra words, the options of its second row,
    /// its common combinations and their equipment, and the old names of its combinations; an exercise of
    /// the user's own by its name and its equipment (with "Outro" only by its name). An empty search keeps
    /// every row. An exercise of the user's own with "Outro" has no equipment, so choosing one leaves it out.
    static func filtered(_ items: [Item], group: GroupFilter, equipment: Equipment?, search: String) -> [Item] {
        let words = Validation.comparisonKey(forName: search).split(whereSeparator: \.isWhitespace)
        return items.filter { item in
            guard matches(item, group: group) else { return false }
            if let equipment, !item.filterEquipment.contains(equipment) { return false }
            return words.allSatisfy { item.searchKey.contains($0) }
        }
    }

    /// Whether a group other than "Todos", or an equipment, narrows the list.
    static func isFiltering(group: GroupFilter, equipment: Equipment?) -> Bool {
        group != .all || equipment != nil
    }

    /// "103 exercícios", "1 exercício", "0 exercícios". The Portuguese plural rules treat 0 as singular,
    /// which would read "0 exercício", so 0 has a text of its own.
    static func countText(_ count: Int) -> String {
        count == 0 ? String(localized: "0 exercícios") : String(localized: "\(count) exercícios")
    }

    private static func matches(_ item: Item, group: GroupFilter) -> Bool {
        switch group {
        case .all: true
        case .mine: item.isCustom
        case .group(let muscleGroup): item.group == muscleGroup
        }
    }
}

extension ExerciseCatalog.Source {
    init(_ exercise: Exercise) {
        self.init(
            id: exercise.id,
            name: exercise.name,
            group: exercise.muscleGroup,
            libraryKey: exercise.libraryKey,
            isCustom: exercise.isCustom,
            isArchived: exercise.isArchived,
            equipmentKey: exercise.isCustom ? exercise.equipmentRaw : nil
        )
    }
}

/// Keeps the rows built from the stored exercises of the user's own until those change, so typing a search
/// or choosing a filter neither normalizes nor sorts the names again. The bases are built once for all.
final class ExerciseCatalogCache {
    private var sources: [ExerciseCatalog.Source]?
    private var lists = ExerciseCatalog.Lists()
    /// How many times the rows were built.
    private(set) var builds = 0

    /// The bases and the active exercises of the user's own.
    func items(for exercises: [Exercise]) -> [ExerciseCatalog.Item] {
        lists(for: exercises).active
    }

    /// The bases with the active exercises of the user's own, and the archived exercises of the user's own.
    func lists(for exercises: [Exercise]) -> ExerciseCatalog.Lists {
        let current = exercises.filter(\.isCustom).map { ExerciseCatalog.Source($0) }
        if current != sources {
            sources = current
            lists = ExerciseCatalog.lists(from: current)
            builds += 1
        }
        return lists
    }
}
