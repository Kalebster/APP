import SwiftUI

/// The search and the filters of the exercise lists (the Exercícios tab and the exercise picker): the
/// search field, the group chips ("Todos", "Meus" and the groups with exercises) and the equipment of the
/// chosen group, 14 points apart and 8 between the two rows of chips. A tap on an equipment chooses it,
/// a second tap unchooses it; choosing a group keeps the equipment only if the group has it.
struct ExerciseFilterBar: View {
    let items: [ExerciseCatalog.Item]
    /// The group shown (`ExerciseCatalog.groupFilter`), which may differ from the one chosen.
    let group: ExerciseCatalog.GroupFilter
    let equipmentChoices: [Equipment]
    /// The equipment shown (`ExerciseCatalog.equipment(_:for:in:)`).
    let equipment: Equipment?
    @Binding var searchText: String
    @Binding var chosenGroup: ExerciseCatalog.GroupFilter
    @Binding var chosenEquipment: Equipment?
    /// The first part of the accessibility identifiers ("exercises", "picker").
    let identifierPrefix: String

    @ScaledMetric(relativeTo: .footnote) private var groupChipHeight: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var equipmentChipHeight: CGFloat = 30
    @ScaledMetric(relativeTo: .caption) private var chipIconSide: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExerciseSearchField(text: $searchText, identifierPrefix: identifierPrefix)
                .padding(.horizontal, Theme.Metrics.screenPadding)
            groupChips
                .padding(.top, 14)
            // "Meus" has no equipment to choose.
            if !equipmentChoices.isEmpty {
                equipmentChips
                    .padding(.top, 8)
            }
        }
    }

    /// "Todos", "Meus" when there is a custom exercise, and the groups with exercises.
    private var groupChips: some View {
        FilterChipRow(chipHeight: groupChipHeight) {
            ForEach(ExerciseCatalog.groupFilters(in: items), id: \.self) { (filter: ExerciseCatalog.GroupFilter) in
                GroupFilterChip(
                    title: title(of: filter),
                    isSelected: filter == group,
                    height: groupChipHeight,
                    identifier: identifier(of: filter)
                ) {
                    choose(filter)
                }
            }
        }
    }

    /// The equipment of the chosen group: a tap chooses one, a second tap unchooses it.
    private var equipmentChips: some View {
        FilterChipRow(chipHeight: equipmentChipHeight) {
            ForEach(equipmentChoices, id: \.self) { (choice: Equipment) in
                EquipmentFilterChip(
                    equipment: choice,
                    isSelected: choice == equipment,
                    height: equipmentChipHeight,
                    iconSide: chipIconSide,
                    identifier: "\(identifierPrefix).equipment.\(choice.rawValue)"
                ) {
                    chosenEquipment = choice == equipment ? nil : choice
                }
            }
        }
    }

    /// Chooses a group; the equipment chosen stays only if the group has exercises with it.
    private func choose(_ filter: ExerciseCatalog.GroupFilter) {
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
        case .all: "\(identifierPrefix).filter.all"
        case .mine: "\(identifierPrefix).filter.mine"
        case .group(let group): "\(identifierPrefix).filter.\(group.rawValue)"
        }
    }
}

/// The search of an exercise list, in a field of its own: the magnifying glass, the text and, with text,
/// the button that clears it. A tap anywhere in the field starts typing.
struct ExerciseSearchField: View {
    @Binding var text: String
    /// The first part of the accessibility identifiers ("exercises", "picker").
    let identifierPrefix: String

    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 40
    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 15

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: iconSide, weight: .medium))
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityHidden(true)
            TextField("Buscar exercício", text: $text, prompt: Text("Buscar exercício").foregroundStyle(Theme.Colors.dimText))
                .scaledFont(14)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .accessibilityIdentifier("\(identifierPrefix).search")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: iconSide))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -12)
                .padding(.trailing, -10)
                .accessibilityLabel(Text("Limpar busca"))
                .accessibilityIdentifier("\(identifierPrefix).search.clear")
            }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: height)
        .background(Theme.Colors.cardBackground, in: shape)
        .overlay(shape.strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture {
            isFocused = true
        }
    }
}
