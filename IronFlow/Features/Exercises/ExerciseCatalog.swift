import Foundation

/// The Exercícios tab: each exercise as it is shown (with the equipment and focus the library knows of a
/// built-in one, and the equipment an exercise of the user's own chose), the group and equipment filters,
/// the search and the archived exercises of the user's own. Pure logic: no UI and no store access.
enum ExerciseCatalog {
    /// What the tab reads of a stored exercise.
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

    /// An exercise as the tab shows it.
    struct Item: Identifiable, Equatable {
        let id: UUID
        let name: String
        let group: MuscleGroup
        /// From the library, found by the exercise's key, or the one an exercise of the user's own chose;
        /// `nil` is "Outro".
        let equipment: Equipment?
        /// From the library; `nil` for an exercise of the user's own.
        let focus: String?
        let isCustom: Bool
        var isArchived = false
        /// What the search compares, computed once (`Validation.comparisonKey`): the name, and the name of its
        /// equipment after it, as the equipment filter shows it ("halteres"); "Outro" is not searched.
        let searchKey: String
    }

    /// The exercises of the tab: the active ones, and the archived exercises of the user's own, each in
    /// alphabetical order.
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

    /// The active exercises, in alphabetical order (Portuguese, ignoring case and diacritics).
    static func items(from sources: [Source]) -> [Item] {
        lists(from: sources).active
    }

    /// The active exercises and the archived exercises of the user's own, each in alphabetical order
    /// (Portuguese, ignoring case and diacritics). An archived built-in exercise left the library and is
    /// in neither.
    static func lists(from sources: [Source]) -> Lists {
        // The equipment names as the search compares them, read once for all the items.
        let equipmentKeys = Dictionary(uniqueKeysWithValues: Equipment.allCases.map { equipment in
            (equipment, Validation.comparisonKey(forName: String(localized: equipment.displayName)))
        })
        var lists = Lists()
        for source in sources where !source.isArchived || source.isCustom {
            let entry = source.isCustom ? nil : source.libraryKey.flatMap { DefaultExerciseLibrary.byKey[$0] }
            let equipment = source.isCustom ? source.equipmentKey.flatMap(Equipment.init(rawValue:)) : entry?.equipment
            var searchKey = Validation.comparisonKey(forName: source.name)
            if let equipment, let equipmentKey = equipmentKeys[equipment] {
                // A space between them: a word typed never has one, so it never runs from the name into
                // the equipment.
                searchKey += " " + equipmentKey
            }
            let item = Item(
                id: source.id,
                name: source.name,
                group: source.group,
                equipment: equipment,
                focus: entry?.focus,
                isCustom: source.isCustom,
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
    /// in the Exercícios tab, an archived one: `hasArchivedCustom`), and the groups that have an active
    /// exercise, in the group order.
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

    /// The equipment of the exercises of the group, in the equipment order.
    static func equipment(for group: GroupFilter, in items: [Item]) -> [Equipment] {
        let used = Set(items.filter { matches($0, group: group) }.compactMap(\.equipment))
        return Equipment.allCases.filter(used.contains)
    }

    /// The equipment in use: the one chosen, or none when the group has no exercise with it.
    static func equipment(_ chosen: Equipment?, for group: GroupFilter, in items: [Item]) -> Equipment? {
        guard let chosen, equipment(for: group, in: items).contains(chosen) else { return nil }
        return chosen
    }

    /// The items of the group, with the equipment, that have every word of the search, in the order given.
    ///
    /// The search is split into words at any whitespace, so extra spaces do not count, and each word may
    /// be any part of the name, in any order ("barra supino" finds "Supino Reto (Barra)"), ignoring case
    /// and diacritics. An exercise is also found by the name of its equipment, as the equipment filter
    /// shows it ("supino halteres" finds "Supino Reto (Halter)", "peso do corpo" the exercises done with the
    /// body only); an exercise of the user's own with "Outro" only by its name. An empty search keeps every
    /// item. An exercise of the user's own with "Outro" has no equipment, so choosing one leaves it out.
    static func filtered(_ items: [Item], group: GroupFilter, equipment: Equipment?, search: String) -> [Item] {
        let words = Validation.comparisonKey(forName: search).split(whereSeparator: \.isWhitespace)
        return items.filter { item in
            guard matches(item, group: group) else { return false }
            if let equipment, item.equipment != equipment { return false }
            return words.allSatisfy { item.searchKey.contains($0) }
        }
    }

    /// Whether a group other than "Todos", or an equipment, narrows the list.
    static func isFiltering(group: GroupFilter, equipment: Equipment?) -> Bool {
        group != .all || equipment != nil
    }

    /// "420 exercícios", "1 exercício", "0 exercícios". The Portuguese plural rules treat 0 as singular,
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

/// Keeps the items built from the stored exercises until those change, so typing a search or choosing
/// a filter neither normalizes nor sorts the names again.
final class ExerciseCatalogCache {
    private var sources: [ExerciseCatalog.Source]?
    private var lists = ExerciseCatalog.Lists()
    /// How many times the items were built.
    private(set) var builds = 0

    /// The active exercises.
    func items(for exercises: [Exercise]) -> [ExerciseCatalog.Item] {
        lists(for: exercises).active
    }

    /// The active exercises and the archived exercises of the user's own.
    func lists(for exercises: [Exercise]) -> ExerciseCatalog.Lists {
        let current = exercises.map { ExerciseCatalog.Source($0) }
        if current != sources {
            sources = current
            lists = ExerciseCatalog.lists(from: current)
            builds += 1
        }
        return lists
    }
}
