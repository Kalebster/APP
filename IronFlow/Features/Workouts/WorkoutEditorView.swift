import SwiftData
import SwiftUI

/// A planned workout: its exercises in plan order, with adding, removing and reordering,
/// renaming and deleting. Every change is saved immediately.
struct WorkoutEditorView: View {
    let workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
    @State private var isPickingExercises = false
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    @State private var isConfirmingRemoval = false
    @State private var itemPendingRemoval: WorkoutExercise?
    /// Set right before the workout is deleted, so the view stops reading it.
    @State private var isDeleted = false
    @State private var errorMessage: String?

    private var service: WorkoutService {
        WorkoutService(context: context)
    }

    var body: some View {
        if isDeleted {
            Theme.Colors.screenBackground.ignoresSafeArea()
        } else {
            editor
        }
    }

    private var editor: some View {
        let items = workout.orderedExercises

        return List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                WorkoutExerciseRow(position: index + 1, item: item)
                    .cardStyle()
                    .cardListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Remover") {
                            confirmRemoval(of: item)
                        }
                        .tint(.red)
                    }
            }
            .onMove(perform: moveExercises)

            if !items.isEmpty && !editMode.isEditing {
                Button {
                    isPickingExercises = true
                } label: {
                    Label("Adicionar exercícios", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .cardStyle()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workout.addExercises")
                .cardListRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Adicione exercícios ao treino", systemImage: "dumbbell")
                } actions: {
                    Button("Adicionar exercícios") {
                        isPickingExercises = true
                    }
                    .accessibilityIdentifier("workout.addExercises")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("workout.empty")
            }
        }
        .screenBackground()
        .environment(\.editMode, $editMode)
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if items.count > 1 {
                    Button {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        if editMode.isEditing {
                            Text("Concluir")
                        } else {
                            Text("Ordenar")
                        }
                    }
                    .accessibilityIdentifier("workout.reorder")
                }
                Menu {
                    Button("Renomear", systemImage: "pencil") {
                        isRenaming = true
                    }
                    Button("Excluir treino", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } label: {
                    Label("Opções", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("workout.menu")
            }
        }
        .onChange(of: items.count) { _, count in
            if count < 2 {
                editMode = .inactive
            }
        }
        .confirmationDialog(
            "Remover este exercício?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible,
            presenting: itemPendingRemoval
        ) { item in
            Button("Remover exercício", role: .destructive) {
                removeExercise(item)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text("As séries planejadas deste exercício também serão removidas.")
        }
        .confirmationDialog(
            Text("Excluir “\(workout.name)”?"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive, action: deleteWorkout)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O histórico de treinos realizados será mantido.")
        }
        .sheet(isPresented: $isPickingExercises) {
            ExercisePickerView(workoutExerciseIDs: Set(workout.exercises.compactMap { $0.exercise?.id })) { exercises in
                try service.addExercises(exercises, to: workout)
            }
        }
        .sheet(isPresented: $isRenaming) {
            WorkoutNameSheet(title: "Renomear treino", initialName: workout.name) { name in
                try service.rename(workout, to: name)
            }
        }
        .errorAlert($errorMessage)
    }

    private func confirmRemoval(of item: WorkoutExercise) {
        itemPendingRemoval = item
        isConfirmingRemoval = true
    }

    private func removeExercise(_ item: WorkoutExercise) {
        itemPendingRemoval = nil
        do {
            try service.removeExercise(item)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        do {
            try service.moveExercises(in: workout, fromOffsets: source, toOffset: destination)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func deleteWorkout() {
        isDeleted = true
        do {
            try service.delete(workout)
            dismiss()
        } catch {
            isDeleted = false
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// An exercise of the workout: position, name, muscle group and number of planned sets.
private struct WorkoutExerciseRow: View {
    let position: Int
    let item: WorkoutExercise

    var body: some View {
        let exercise = item.exercise
        HStack(spacing: 12) {
            Text(position.formatted())
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 20)
            VStack(alignment: .leading, spacing: 4) {
                if let exercise {
                    Text(exercise.name)
                } else {
                    Text("Exercício removido")
                }
                HStack(spacing: 4) {
                    if let exercise {
                        Text(exercise.muscleGroup.displayName)
                        Text(verbatim: "·")
                    }
                    Text("\(item.plannedSets.count) séries")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if exercise?.isArchived == true {
                Text("Arquivado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workout.exercise")
    }
}
