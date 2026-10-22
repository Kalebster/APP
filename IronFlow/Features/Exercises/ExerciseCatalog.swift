import Foundation

/// The Exercícios tab: each active exercise as it is shown (with the equipment and focus the library
/// knows of a built-in one), the group and equipment filters, and the search. Pure logic: no UI and no
/// store access.
enum ExerciseCatalog {
    /// What the tab reads of a stored exercise.
    struct Source: Equatable {
        let id: UUID
        let name: String
        let group: MuscleGroup
        let libraryKey: String?
        let isCustom: Bool
        let isArchived: Bool
    }

    /// An active exercise as the tab shows it.
    struct Item: Identifiable, Equatable {
        let id: UUID
        let name: String
        let group: MuscleGroup
        /// From the library, found by the exercise's key; `nil` for a custom exercise.
        let equipment: Equipment?
        let focus: String?
        let isCustom: Bool
        /// The name as the search compares it (`Validation.comparisonKey`), computed once.
        let searchKey: String
    }

    /// The group filter: every exercise, the user's own ("Meus") or one muscle group.
    enum GroupFilter: Hashable {
        case all
        case mine
        case group(MuscleGroup)
    }

    /// The active exercises, in alphabetical order (Portuguese, ignoring case and diacritics).
    static func items(from sources: [Source]) -> [Item] {
        sources
            .filter { !$0.isArchived }
            .map { source in
                let entry = source.isCustom ? nil : source.libraryKey.flatMap { DefaultExerciseLibrary.byKey[$0] }
                return Item(
                    id: source.id,
                    name: source.name,
                    group: source.group,
                    equipment: entry?.equipment,
                    focus: entry?.focus,
                    isCustom: source.isCustom,
                    searchKey: Validation.comparisonKey(forName: source.name)
                )
            }
            .sorted { lhs, rhs in
                switch lhs.name.localizedStandardCompare(rhs.name) {
                case .orderedAscending: true
                case .orderedDescending: false
                case .orderedSame: lhs.id < rhs.id
                }
            }
    }

    /// The group filters offered: "Todos", "Meus" when there is a custom exercise, and the groups that
    /// have an exercise, in the group order.
    static func groupFilters(in items: [Item]) -> [GroupFilter] {
        let groups = Set(items.map(\.group))
        let mine: [GroupFilter] = items.contains(where: \.isCustom) ? [.mine] : []
        return [.all] + mine + MuscleGroup.allCases.filter(groups.contains).map(GroupFilter.group)
    }

    /// The group filter in use: the one chosen, or "Todos" when it is no longer offered (its last
    /// exercise was archived).
    static func groupFilter(_ chosen: GroupFilter, in items: [Item]) -> GroupFilter {
        groupFilters(in: items).contains(chosen) ? chosen : .all
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

    /// The items of the group, with the equipment, whose name contains the search, in the order given.
    ///
    /// The search matches any part of the name, ignoring case, diacritics and leading or trailing
    /// whitespace. A custom exercise has no equipment, so choosing one leaves it out.
    static func filtered(_ items: [Item], group: GroupFilter, equipment: Equipment?, search: String) -> [Item] {
        let query = Validation.comparisonKey(forName: search.trimmingCharacters(in: .whitespacesAndNewlines))
        return items.filter { item in
            guard matches(item, group: group) else { return false }
            if let equipment, item.equipment != equipment { return false }
            return query.isEmpty || item.searchKey.contains(query)
        }
    }

    /// Whether a group other than "Todos", or an equipment, narrows the list.
    static func isFiltering(group: GroupFilter, equipment: Equipment?) -> Bool {
        group != .all || equipment != nil
    }

    /// "157 exercícios", "1 exercício".
    static func countText(_ count: Int) -> String {
        String(localized: "\(count) exercícios")
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
            isArchived: exercise.isArchived
        )
    }
}

/// Keeps the items built from the stored exercises until those change, so typing a search or choosing
/// a filter neither normalizes nor sorts the names again.
final class ExerciseCatalogCache {
    private var sources: [ExerciseCatalog.Source]?
    private var items: [ExerciseCatalog.Item] = []
    /// How many times the items were built.
    private(set) var builds = 0

    func items(for exercises: [Exercise]) -> [ExerciseCatalog.Item] {
        let current = exercises.map { ExerciseCatalog.Source($0) }
        if current != sources {
            sources = current
            items = ExerciseCatalog.items(from: current)
            builds += 1
        }
        return items
    }
}
