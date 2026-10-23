import SwiftData
import SwiftUI

/// Chooses exercises to add to a workout or to the session in progress, full screen: "Cancelar", the
/// search and the filters of the Exercícios tab, and the same cards with a selection circle. Exercises
/// already in the workout are shown at half opacity with "NO TREINO" and cannot be chosen. "Adicionar (N)"
/// stays at the bottom. `onAdd` receives the chosen exercises in the order they were chosen; when it
/// throws, the picker stays open and shows the error.
struct ExercisePickerView: View {
    let onAdd: @MainActor ([Exercise]) throws -> Void

    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    /// The items built from the exercises, kept until one of them changes.
    @State private var cache = ExerciseCatalogCache()
    @State private var selection: ExerciseSelection
    @State private var searchText = ""
    @State private var chosenGroup: ExerciseCatalog.GroupFilter = .all
    @State private var chosenEquipment: Equipment?
    @State private var errorMessage: String?
    /// Set once the exercises were added, so a second tap while the picker closes adds nothing.
    @State private var isAdded = false

    @ScaledMetric(relativeTo: .body) private var addButtonHeight: CGFloat = 46

    init(workoutExerciseIDs: Set<UUID>, onAdd: @escaping @MainActor ([Exercise]) throws -> Void) {
        self.onAdd = onAdd
        _selection = State(initialValue: ExerciseSelection(workoutExerciseIDs: workoutExerciseIDs))
    }

    var body: some View {
        let items = cache.items(for: exercises)
        let group = ExerciseCatalog.groupFilter(chosenGroup, in: items)
        let equipmentChoices = ExerciseCatalog.equipment(for: group, in: items)
        let equipment = ExerciseCatalog.equipment(chosenEquipment, for: group, in: items)
        let shown = ExerciseCatalog.filtered(items, group: group, equipment: equipment, search: searchText)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ExerciseFilterBar(
                    items: items,
                    group: group,
                    equipmentChoices: equipmentChoices,
                    equipment: equipment,
                    searchText: $searchText,
                    chosenGroup: $chosenGroup,
                    chosenEquipment: $chosenEquipment,
                    identifierPrefix: "picker"
                )
                cards(shown)
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 14)
            }
            .padding(.top, 14)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        // At the bottom, so it stays reachable over the list.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addBar
        }
        .screenBackground()
        .errorAlert($errorMessage)
    }

    /// The exercises left, or the card that says none was found.
    private func cards(_ shown: [ExerciseCatalog.Item]) -> some View {
        LazyVStack(spacing: 8) {
            if shown.isEmpty {
                ExerciseEmptyCard(identifier: "picker.empty")
            } else {
                ForEach(shown) { (item: ExerciseCatalog.Item) in
                    card(item)
                }
            }
        }
    }

    private func card(_ item: ExerciseCatalog.Item) -> some View {
        let isInWorkout = selection.isInWorkout(item.id)
        let isSelected = selection.isSelected(item.id)
        let state: ExerciseCard.Selection = isInWorkout ? .inWorkout : .selectable(isSelected: isSelected)
        return Button {
            selection.toggle(item.id)
        } label: {
            ExerciseCard(item: item, selection: state, identifier: "picker.card")
        }
        .buttonStyle(.plain)
        .disabled(isInWorkout)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("picker.card")
    }

    /// "Cancelar" and the title, which stays centered: the space of "Cancelar" is kept on the other side too.
    private var topBar: some View {
        HStack(spacing: 8) {
            cancelButton
            Text("Adicionar exercícios")
                .scaledFont(16, weight: .bold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            cancelButton
                .hidden()
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .frame(minHeight: 44)
        .background(Theme.Colors.screenBackground)
    }

    private var cancelButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Cancelar")
                .scaledFont(15)
                .foregroundStyle(Theme.Colors.lightAccent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("picker.cancel")
    }

    /// "Adicionar (N)" over a line, unavailable while nothing is chosen.
    private var addBar: some View {
        let isEnabled = selection.count > 0 && !isAdded
        return VStack(spacing: 0) {
            Theme.Colors.rowSeparator
                .frame(height: 1)
                .accessibilityHidden(true)
            Button(action: add) {
                Group {
                    if selection.count == 0 {
                        Text("Adicionar")
                    } else {
                        Text("Adicionar (\(selection.count))")
                    }
                }
                .scaledFont(15, weight: .bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: addButtonHeight)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityIdentifier("picker.add")
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.vertical, 10)
        }
        // Opaque, so the list never shows through the button.
        .background(Theme.Colors.screenBackground)
    }

    private func add() {
        guard !isAdded else { return }
        do {
            try onAdd(selection.selectedExercises(from: exercises))
            isAdded = true
            dismiss()
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
