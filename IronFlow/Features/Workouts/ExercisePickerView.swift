import SwiftData
import SwiftUI

/// Chooses exercises, full screen: "Cancelar", the search and the filters of the Exercícios tab, and one card
/// per base exercise and per exercise of the user's own, with a selection circle.
///
/// - To add to a workout or to the session in progress ("Adicionar exercícios" and "Adicionar (N)"): tapping a
///   base opens the choice sheet (equipment and grip or variation), where its combinations are chosen; with
///   an equipment filter on, a base without a second row that has one common combination of it chooses it at
///   once. A card says which combinations are chosen, or already in the workout. An exercise of the user's
///   own is chosen at once, or shown at half opacity with "NO TREINO" when the workout has it.
/// - To build a workout from the Exercícios tab ("Montar treino" and "Continuar (N)"): nothing is in a workout
///   yet, and "Continuar" opens "Adicionar a um treino" over the picker; once it adds or creates, the picker
///   closes too, and "Cancelar" there comes back to the picker with the exercises still chosen.
///
/// When the search finds nothing, "+ Criar "texto"" opens the form of a new exercise over the picker; once
/// created, the picker comes back with every filter off, the search with the new name and the new exercise
/// chosen. The button at the bottom is off, at 35 %, while nothing is chosen, and acts once.
struct ExercisePickerView: View {
    enum Purpose {
        /// "Adicionar (N)": `onAdd` receives the chosen exercises in the order they were chosen; when it throws,
        /// the picker stays open and shows the error.
        case add(onAdd: @MainActor ([Exercise]) throws -> Void)
        /// "Continuar (N)": "Adicionar a um treino"; `onFinish` receives what it did, once the picker closed.
        case build(onFinish: @MainActor (AddToWorkoutOutcome) -> Void)
    }

    let purpose: Purpose

    /// The exercises of the user's own, and the hidden library exercises (their name is taken).
    @Query(filter: #Predicate<Exercise> { $0.isCustom || $0.isArchived }) private var stored: [Exercise]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// The rows built from the exercises of the user's own, kept until one of them changes.
    @State private var cache = ExerciseCatalogCache()
    /// The library exercises of the store and when each exercise was last done, read once.
    @State private var records = LibraryRecords()
    @State private var lastDone = ExerciseLastDone()
    @State private var selection: ExerciseSelection
    @State private var searchText = ""
    @State private var chosenGroup: ExerciseCatalog.GroupFilter = .all
    @State private var chosenEquipment: Equipment?
    @State private var errorMessage: String?
    /// Set once the exercises were added, so a second tap while the picker closes adds nothing.
    @State private var isAdded = false
    /// The base whose choice sheet is open.
    @State private var choice: ChoiceRequest?
    /// "Adicionar a um treino", over the picker.
    @State private var addRequest: AddRequest?
    /// What "Adicionar a um treino" did, handed over once the picker has closed.
    @State private var outcome: AddToWorkoutOutcome?
    /// The form of a new exercise, open over the picker.
    @State private var newExerciseForm: NewExerciseForm?
    /// The exercise just created, chosen once the form has closed.
    @State private var createdExercise: Exercise?
    /// "Exercício criado e marcado".
    @State private var toast: ToastMessage?

    private struct ChoiceRequest: Identifiable {
        let id = UUID()
        let base: ExerciseBase
        let start: DefaultExercise
    }

    private struct AddRequest: Identifiable {
        let id = UUID()
        let exercises: [Exercise]
    }

    private struct NewExerciseForm: Identifiable {
        let id = UUID()
        let form: ExerciseForm
    }

    @ScaledMetric(relativeTo: .body) private var addButtonHeight: CGFloat = 46

    init(workoutExerciseIDs: Set<UUID>, onAdd: @escaping @MainActor ([Exercise]) throws -> Void) {
        purpose = .add(onAdd: onAdd)
        _selection = State(initialValue: ExerciseSelection(workoutExerciseIDs: workoutExerciseIDs))
    }

    /// "Montar treino": nothing is in a workout yet.
    init(buildingWorkout onFinish: @escaping @MainActor (AddToWorkoutOutcome) -> Void) {
        purpose = .build(onFinish: onFinish)
        _selection = State(initialValue: ExerciseSelection(workoutExerciseIDs: []))
    }

    private var isBuilding: Bool {
        if case .build = purpose { return true }
        return false
    }

    var body: some View {
        let items = cache.items(for: stored)
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
                cards(shown, group: group, equipment: equipment)
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
        .toast($toast, top: 8)
        .task {
            readTheLibrary()
        }
        .sheet(item: $choice) { request in
            ExerciseChoiceSheet(base: request.base, start: request.start, records: records, lastDone: lastDone, selection: $selection)
        }
        .sheet(item: $addRequest) { request in
            AddToWorkoutSheet(exercises: request.exercises) { done in
                outcome = done
                dismiss()
            }
        }
        .fullScreenCover(item: $newExerciseForm, onDismiss: chooseCreatedExercise) { request in
            ExerciseFormView(form: request.form) { exercise in
                createdExercise = exercise
            }
        }
        .onDisappear {
            if let outcome, case .build(let onFinish) = purpose {
                self.outcome = nil
                onFinish(outcome)
            }
        }
        .errorAlert($errorMessage)
    }

    /// The rows left, or the card that says none was found, with "+ Criar" for the search.
    private func cards(_ shown: [ExerciseCatalog.Item], group: ExerciseCatalog.GroupFilter, equipment: Equipment?) -> some View {
        LazyVStack(spacing: 8) {
            if shown.isEmpty {
                let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                ExerciseEmptyCard(identifier: "picker.empty", search: search) {
                    // A second tap while the form is opening would open it again.
                    guard newExerciseForm == nil else { return }
                    var muscleGroup: MuscleGroup?
                    if case .group(let chosen) = group {
                        muscleGroup = chosen
                    }
                    newExerciseForm = NewExerciseForm(form: ExerciseForm(name: search, group: muscleGroup, equipment: equipment))
                }
            } else {
                ForEach(shown) { (item: ExerciseCatalog.Item) in
                    if let base = item.base {
                        baseCard(item, base: base, equipment: equipment)
                    } else {
                        customCard(item)
                    }
                }
            }
        }
    }

    /// A base: the combinations chosen, or those already in the workout, on the line under its name.
    private func baseCard(_ item: ExerciseCatalog.Item, base: ExerciseBase, equipment: Equipment?) -> some View {
        let chosen = ExerciseChoiceSheet.chosen(of: base, in: selection, records: records)
        let inWorkout = (ExerciseBaseIndex.combinations[base.name] ?? []).filter { entry in
            records.byKey[entry.key].map { selection.isInWorkout($0.id) } ?? false
        }
        let subtitle: ExerciseCard.Subtitle = if !chosen.isEmpty {
            .chosen(chosen.map(ExerciseBaseIndex.optionText).joined(separator: ", "))
        } else if !inWorkout.isEmpty {
            .inWorkout(inWorkout.map(ExerciseBaseIndex.optionText).joined(separator: ", "))
        } else {
            .standard
        }
        let icon = chosen.first?.equipment
            ?? lastDone.openingCombination(of: base, hiddenKeys: records.hiddenKeys)?.equipment
        return Button {
            tap(base, equipment: equipment)
        } label: {
            ExerciseCard(
                item: item,
                selection: .selectable(isSelected: !chosen.isEmpty),
                subtitle: subtitle,
                iconEquipment: icon,
                identifier: "picker.card"
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen.isEmpty ? [] : .isSelected)
        .accessibilityIdentifier("picker.card")
    }

    private func customCard(_ item: ExerciseCatalog.Item) -> some View {
        let id = item.exerciseID ?? UUID()
        let isInWorkout = selection.isInWorkout(id)
        let isSelected = selection.isSelected(id)
        let state: ExerciseCard.Selection = isInWorkout ? .inWorkout : .selectable(isSelected: isSelected)
        return Button {
            selection.toggle(id)
        } label: {
            ExerciseCard(item: item, selection: state, identifier: "picker.card")
        }
        .buttonStyle(.plain)
        .disabled(isInWorkout)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("picker.card")
    }

    /// A tap on a base: its combination chosen or unchosen at once, or its choice sheet.
    private func tap(_ base: ExerciseBase, equipment: Equipment?) {
        switch Self.tapResult(of: base, equipment: equipment, selection: selection, records: records, lastDone: lastDone) {
        case .toggle(let id):
            selection.toggle(id)
        case .sheet(let start):
            guard choice == nil else { return }
            choice = ChoiceRequest(base: base, start: start)
        case nil:
            break
        }
    }

    /// What a tap on a base card does.
    enum BaseTap: Equatable {
        /// Chooses, or unchooses, this exercise at once.
        case toggle(UUID)
        /// Opens the choice sheet on this combination.
        case sheet(DefaultExercise)
    }

    /// A base without a second row, with the equipment filter on and exactly one common combination of it out
    /// of the workout (and not hidden), is chosen (or unchosen) at once. Any other opens the choice sheet: on
    /// the combination chosen last, or else the one the base opens on; with the equipment filter on, on a
    /// common combination of it that is not hidden, keeping the grip or variation. `nil` only for a base
    /// without combinations.
    static func tapResult(
        of base: ExerciseBase,
        equipment: Equipment?,
        selection: ExerciseSelection,
        records: LibraryRecords,
        lastDone: ExerciseLastDone
    ) -> BaseTap? {
        let combinations = ExerciseBaseIndex.combinations[base.name] ?? []
        let hidden = records.hiddenKeys
        if let equipment, base.secondRow == nil {
            let free = combinations.filter { entry in
                entry.isCommon && entry.equipment == equipment && !hidden.contains(entry.key)
                    && !(records.byKey[entry.key].map { selection.isInWorkout($0.id) } ?? true)
            }
            if free.count == 1, let id = records.byKey[free[0].key]?.id {
                return .toggle(id)
            }
        }
        let chosen = ExerciseChoiceSheet.chosen(of: base, in: selection, records: records)
        var start = chosen.last ?? lastDone.openingCombination(of: base, hiddenKeys: hidden) ?? combinations.first
        if let equipment, let current = start, current.equipment != equipment {
            let filtered = combinations.filter { $0.isCommon && $0.equipment == equipment && !hidden.contains($0.key) }
            start = filtered.first { $0.variation == current.variation } ?? filtered.first ?? current
        }
        return start.map(BaseTap.sheet)
    }

    /// "Cancelar" and the title, which stays centered: the space of "Cancelar" is kept on the other side too.
    private var topBar: some View {
        HStack(spacing: 8) {
            cancelButton
            Group {
                if isBuilding {
                    Text("Montar treino")
                } else {
                    Text("Adicionar exercícios")
                }
            }
            .scaledFont(16, weight: .heavy)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("picker.title")
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

    /// "Adicionar (N)" or "Continuar (N)" over a line, off at 35 % while nothing is chosen.
    private var addBar: some View {
        let isEnabled = selection.count > 0 && !isAdded
        return VStack(spacing: 0) {
            Theme.Colors.rowSeparator
                .frame(height: 1)
                .accessibilityHidden(true)
            Button(action: confirm) {
                Group {
                    switch (isBuilding, selection.count) {
                    case (true, 0): Text("Continuar")
                    case (true, let count): Text("Continuar (\(count))")
                    case (false, 0): Text("Adicionar")
                    case (false, let count): Text("Adicionar (\(count))")
                    }
                }
                .scaledFont(15, weight: .bold)
                .foregroundStyle(Theme.Colors.primaryButtonText)
                .frame(maxWidth: .infinity, minHeight: addButtonHeight)
                .background(Theme.Colors.primaryButton, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(PrototypeButtonStyle())
            .disabled(!isEnabled)
            .accessibilityIdentifier("picker.add")
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        // Opaque, so the list never shows through the button.
        .background(Theme.Colors.screenBackground)
    }

    /// The library exercises of the store and when each was last done, read once when the picker opens.
    private func readTheLibrary() {
        do {
            records = try LibraryRecords.read(in: context)
            lastDone = try ExerciseLastDone.read(in: context)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// The chosen exercises, in the order chosen, without the archived ones.
    private var chosenExercises: [Exercise] {
        selection.selectedExercises(from: stored + Array(records.byKey.values))
    }

    /// Back from the form with an exercise created: every filter off, the search with its name, and it chosen.
    private func chooseCreatedExercise() {
        guard let createdExercise else { return }
        self.createdExercise = nil
        chosenGroup = .all
        chosenEquipment = nil
        searchText = createdExercise.name
        if !selection.isSelected(createdExercise.id) {
            selection.toggle(createdExercise.id)
        }
        toast = ToastMessage(String(localized: "Exercício criado e marcado"))
    }

    private func confirm() {
        guard !isAdded, selection.count > 0 else { return }
        switch purpose {
        case .add(let onAdd):
            do {
                try onAdd(chosenExercises)
                isAdded = true
                dismiss()
            } catch {
                errorMessage = UserFacingError.message(for: error)
            }
        case .build:
            // A second tap while "Adicionar a um treino" opens does nothing.
            guard addRequest == nil else { return }
            addRequest = AddRequest(exercises: chosenExercises)
        }
    }
}
