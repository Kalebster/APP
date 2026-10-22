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
    @FocusState private var isSearchFocused: Bool

    @ScaledMetric(relativeTo: .subheadline) private var searchHeight: CGFloat = 40
    @ScaledMetric(relativeTo: .subheadline) private var searchIconSide: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var groupChipHeight: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var equipmentChipHeight: CGFloat = 30
    @ScaledMetric(relativeTo: .caption) private var chipIconSide: CGFloat = 14

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
                searchField
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 14)
                groupChips(items: items, selected: group)
                    .padding(.top, 14)
                // "Meus" has no equipment to choose.
                if !equipmentChoices.isEmpty {
                    equipmentChips(equipmentChoices, selected: equipment)
                        .padding(.top, 8)
                }
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

    /// "Todos", "Meus" when there is a custom exercise, and the groups with exercises.
    private func groupChips(items: [ExerciseCatalog.Item], selected: ExerciseCatalog.GroupFilter) -> some View {
        FilterChipRow(chipHeight: groupChipHeight) {
            ForEach(ExerciseCatalog.groupFilters(in: items), id: \.self) { (filter: ExerciseCatalog.GroupFilter) in
                GroupFilterChip(
                    title: title(of: filter),
                    isSelected: filter == selected,
                    height: groupChipHeight,
                    identifier: identifier(of: filter)
                ) {
                    choose(filter, in: items)
                }
            }
        }
    }

    /// The equipment of the chosen group: a tap chooses one, a second tap unchooses it.
    private func equipmentChips(_ choices: [Equipment], selected: Equipment?) -> some View {
        FilterChipRow(chipHeight: equipmentChipHeight) {
            ForEach(choices, id: \.self) { (choice: Equipment) in
                EquipmentFilterChip(
                    equipment: choice,
                    isSelected: choice == selected,
                    height: equipmentChipHeight,
                    iconSide: chipIconSide
                ) {
                    chosenEquipment = choice == selected ? nil : choice
                }
            }
        }
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

    /// The search, in a field of its own: the magnifying glass, the text and, with text, the button that
    /// clears it. A tap anywhere in the field starts typing.
    private var searchField: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: searchIconSide, weight: .medium))
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityHidden(true)
            TextField("Buscar exercício", text: $searchText, prompt: Text("Buscar exercício").foregroundStyle(Theme.Colors.dimText))
                .scaledFont(14)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
                .accessibilityIdentifier("exercises.search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: searchIconSide))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -12)
                .padding(.trailing, -10)
                .accessibilityLabel(Text("Limpar busca"))
                .accessibilityIdentifier("exercises.search.clear")
            }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: searchHeight)
        .background(Theme.Colors.cardBackground, in: shape)
        .overlay(shape.strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture {
            isSearchFocused = true
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

    /// Chooses a group; the equipment chosen stays only if the group has exercises with it.
    private func choose(_ filter: ExerciseCatalog.GroupFilter, in items: [ExerciseCatalog.Item]) {
        chosenGroup = filter
        chosenEquipment = ExerciseCatalog.equipment(chosenEquipment, for: filter, in: items)
    }

    private func title(of filter: ExerciseCatalog.GroupFilter) -> LocalizedStringResource {
        switch filter {
        case .all: "Todos"
        case .mine: "Meus"
        case .group(let group): group.displayName
        }
    }

    private func identifier(of filter: ExerciseCatalog.GroupFilter) -> String {
        switch filter {
        case .all: "exercises.filter.all"
        case .mine: "exercises.filter.mine"
        case .group(let group): "exercises.filter.\(group.rawValue)"
        }
    }
}
