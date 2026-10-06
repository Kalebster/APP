import SwiftData
import SwiftUI

/// Chooses library exercises to add to a workout: search, sections by muscle group and
/// multiple selection. Exercises already in the workout are shown but cannot be chosen.
/// `onAdd` receives the chosen exercises in selection order; when it throws, the picker
/// stays open and shows the error.
struct ExercisePickerView: View {
    let onAdd: @MainActor ([Exercise]) throws -> Void

    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    @State private var selection: ExerciseSelection
    @State private var searchText = ""
    @State private var errorMessage: String?
    /// Set once the exercises were added, so a second tap while the picker closes adds nothing.
    @State private var isAdded = false

    init(workoutExerciseIDs: Set<UUID>, onAdd: @escaping @MainActor ([Exercise]) throws -> Void) {
        self.onAdd = onAdd
        _selection = State(initialValue: ExerciseSelection(workoutExerciseIDs: workoutExerciseIDs))
    }

    var body: some View {
        let sections = ExerciseListFilter.sections(from: exercises, search: searchText, group: nil)

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
                    ForEach(sections) { section in
                        ExerciseSectionHeader(group: section.group)
                        ForEach(section.exercises) { exercise in
                            PickerRow(
                                exercise: exercise,
                                isInWorkout: selection.isInWorkout(exercise),
                                isSelected: selection.isSelected(exercise)
                            ) {
                                selection.toggle(exercise)
                            }
                        }
                    }
                }
                .padding(Theme.Metrics.screenPadding)
            }
            .overlay {
                if sections.isEmpty {
                    emptyState
                }
            }
            // At the bottom so it stays reachable while searching (the navigation bar hides then).
            .safeAreaInset(edge: .bottom) {
                Button(action: add) {
                    Group {
                        if selection.count == 0 {
                            Text("Adicionar")
                        } else {
                            Text("Adicionar (\(selection.count))")
                        }
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selection.count == 0 || isAdded)
                .accessibilityIdentifier("picker.add")
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.vertical, 8)
                // Opaque, so the list never shows through the button.
                .background(Theme.Colors.screenBackground)
            }
            .screenBackground()
            .navigationTitle("Adicionar exercícios")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Buscar exercício")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .accessibilityIdentifier("picker.cancel")
                }
            }
            .errorAlert($errorMessage)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            ContentUnavailableView("Nenhum exercício", systemImage: "dumbbell")
        } else {
            ContentUnavailableView.search(text: trimmedSearch)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("picker.empty.search")
        }
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

/// An exercise in the picker: a selection mark, or "No treino" when it is already in the workout.
private struct PickerRow: View {
    let exercise: Exercise
    let isInWorkout: Bool
    let isSelected: Bool
    let toggle: @MainActor () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Text(exercise.name)
                    .foregroundStyle(isInWorkout ? Color.secondary : Color.primary)
                Spacer(minLength: 0)
                if isInWorkout {
                    Text("No treino")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary, in: Capsule())
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .disabled(isInWorkout)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
