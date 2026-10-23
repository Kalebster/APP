import SwiftData
import SwiftUI

/// The Exercícios tab: the active exercises in one alphabetical list, with a search, the group filters
/// ("Todos", "Meus" and the muscle groups) and the equipment of the chosen group. "Limpar filtros" goes
/// back to "Todos" without equipment and keeps the search. Read-only: the cards open nothing yet.
struct ExerciseListView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    /// The items built from the exercises, kept until one of them changes: typing a search or choosing a
    /// filter does not build them again.
    @State private var cache = ExerciseCatalogCache()
    @State private var searchText = ""
    @State private var chosenGroup: ExerciseCatalog.GroupFilter = .all
    @State private var chosenEquipment: Equipment?

    var body: some View {
        let items = cache.items(for: exercises)
        let group = ExerciseCatalog.groupFilter(chosenGroup, in: items)
        let equipmentChoices = ExerciseCatalog.equipment(for: group, in: items)
        let equipment = ExerciseCatalog.equipment(chosenEquipment, for: group, in: items)
        let shown = ExerciseCatalog.filtered(items, group: group, equipment: equipment, search: searchText)
        let isFiltering = ExerciseCatalog.isFiltering(group: group, equipment: equipment)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(total: items.count)
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                ExerciseFilterBar(
                    items: items,
                    group: group,
                    equipmentChoices: equipmentChoices,
                    equipment: equipment,
                    searchText: $searchText,
                    chosenGroup: $chosenGroup,
                    chosenEquipment: $chosenEquipment,
                    identifierPrefix: "exercises"
                )
                .padding(.top, 14)
                if isFiltering {
                    countRow(shown.count)
                        .padding(.horizontal, Theme.Metrics.screenPadding)
                        .padding(.top, 10)
                }
                cards(shown)
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, isFiltering ? 8 : 14)
            }
            .padding(.top, 21)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    /// The exercises left, or the card that says none was found.
    private func cards(_ shown: [ExerciseCatalog.Item]) -> some View {
        LazyVStack(spacing: 8) {
            if shown.isEmpty {
                ExerciseEmptyCard()
            } else {
                ForEach(shown) { (item: ExerciseCatalog.Item) in
                    ExerciseCard(item: item)
                }
            }
        }
    }

    /// "Exercícios" and how many active exercises there are.
    private func header(total: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Exercícios")
                .scaledFont(29, weight: .heavy)
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: ExerciseCatalog.countText(total))
                .scaledFont(13)
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityIdentifier("exercises.total")
        }
    }

    /// How many exercises the filters leave, and "Limpar filtros".
    private func countRow(_ count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: ExerciseCatalog.countText(count))
                .scaledFont(11)
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityIdentifier("exercises.count")
            Spacer(minLength: 8)
            Button {
                chosenGroup = .all
                chosenEquipment = nil
            } label: {
                Text("Limpar filtros")
                    .scaledFont(11, weight: .bold)
                    .foregroundStyle(Theme.Colors.lightAccent)
                    // The touch area grows to 44 points without taking room.
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -15)
            .accessibilityIdentifier("exercises.clearFilters")
        }
    }
}
