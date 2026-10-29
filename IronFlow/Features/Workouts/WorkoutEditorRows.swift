import SwiftUI
import UIKit

/// The space between two exercise cards of the workout editor, below each card's last row.
let editorCardGap: CGFloat = 12

/// The first row of an exercise card in the workout editor: the equipment icon (the initial of a custom
/// exercise), the name, "Grupo · Foco", "Arquivado" when the exercise was archived, and the ⋯ menu with
/// "Ordenar exercícios" and "Remover do treino". The question before removing opens from the ⋯ itself,
/// so it points to the exercise it is about.
struct EditorExerciseHeader: View {
    let item: WorkoutExercise
    let canReorder: Bool
    /// Whether the question "Remover … ?" is open for this exercise.
    @Binding var isConfirmingRemoval: Bool
    /// The exercise's name in the question, taken when it was asked.
    let removalName: String
    let onReorder: @MainActor () -> Void
    /// Asks before removing: sets `isConfirmingRemoval`.
    let onRemove: @MainActor () -> Void
    /// Removes the exercise, once confirmed.
    let onConfirmRemoval: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var menuSide: CGFloat = 30

    var body: some View {
        let exercise = item.exercise
        let entry = EditorExerciseInfo.libraryEntry(of: exercise)
        HStack(spacing: 10) {
            EditorExerciseTile(exercise: exercise, equipment: entry?.equipment)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: EditorExerciseInfo.name(of: exercise))
                    .scaledFont(14, weight: .heavy)
                    .fixedSize(horizontal: false, vertical: true)
                if let exercise {
                    Text(EditorExerciseInfo.detail(group: exercise.muscleGroup, focus: entry?.focus))
                        .scaledFont(10)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if exercise?.isArchived == true {
                Text("Arquivado")
                    .scaledFont(10, weight: .semibold)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.unplannedDayBackground, in: Capsule())
            }
            Menu {
                if canReorder {
                    Button("Ordenar exercícios", systemImage: "arrow.up.arrow.down", action: onReorder)
                }
                Button("Remover do treino", systemImage: "trash", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis")
                    .scaledFont(13, weight: .bold)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(width: menuSide, height: menuSide)
                    .frame(width: max(44, menuSide), height: max(44, menuSide))
                    .contentShape(Rectangle())
            }
            .padding(min(0, (menuSide - 44) / 2))
            .accessibilityLabel(Text("Opções de \(EditorExerciseInfo.name(of: exercise))"))
            .accessibilityIdentifier("workout.exercise.menu")
            // On the ⋯ itself, so the confirmation points to the exercise it came from.
            .confirmationDialog(
                Text("Remover \(removalName)?"),
                isPresented: $isConfirmingRemoval,
                titleVisibility: .visible
            ) {
                Button("Remover do treino", role: .destructive, action: onConfirmRemoval)
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("As séries planejadas dele também saem deste treino. O histórico não muda.")
            }
        }
        .padding(.top, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout.exercise")
        .accessibilityLabel(Text(verbatim: EditorExerciseInfo.accessibilityText(of: item)))
    }
}

/// The equipment icon in light blue on the dark blue square, the initial of a custom exercise, or a
/// dumbbell for an exercise that no longer exists. 32 points at the default text size; it grows with the
/// text up to the largest standard size and stops there, so with the accessibility sizes the exercise's
/// name keeps the room it needs beside it.
struct EditorExerciseTile: View {
    let exercise: Exercise?
    let equipment: Equipment?

    var body: some View {
        Square(exercise: exercise, equipment: equipment)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityHidden(true)
    }

    /// The tile itself. Its sizes follow the text size it is given, which the tile limits above.
    private struct Square: View {
        let exercise: Exercise?
        let equipment: Equipment?

        @ScaledMetric(relativeTo: .body) private var side: CGFloat = 32
        @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 17

        var body: some View {
            Group {
                if let equipment {
                    EquipmentIcon(equipment: equipment)
                        .frame(width: iconSide, height: iconSide)
                } else if let exercise, let initial = exercise.name.first {
                    // Inter Bold at a size fixed by the tile, which already follows Dynamic Type.
                    Text(verbatim: String(initial).uppercased())
                        .font(.custom(InterFont.bold, fixedSize: iconSide * 0.8))
                } else {
                    Image(systemName: "dumbbell")
                        .font(.system(size: iconSide * 0.75, weight: .semibold))
                }
            }
            .foregroundStyle(Theme.Colors.lightAccent)
            .frame(width: side, height: side)
            .background(Theme.Colors.iconTileBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

/// What the editor shows about an exercise of the workout. Pure logic.
enum EditorExerciseInfo {
    /// The built-in exercise's library entry, for its equipment and focus; `nil` for a custom exercise.
    static func libraryEntry(of exercise: Exercise?) -> DefaultExercise? {
        guard let exercise, !exercise.isCustom, let key = exercise.libraryKey else { return nil }
        return DefaultExerciseLibrary.byKey[key]
    }

    /// The exercise's name, or "Exercício removido" once it was deleted.
    static func name(of exercise: Exercise?) -> String {
        exercise?.name ?? String(localized: "Exercício removido")
    }

    /// "Peito" in gray and " · Peitoral médio" darker; only the group without a focus.
    static func detail(group: MuscleGroup, focus: String?) -> AttributedString {
        var text = AttributedString(String(localized: group.displayName))
        text.foregroundColor = Theme.Colors.secondaryText
        if let focus {
            var focusText = AttributedString(" · \(focus)")
            focusText.foregroundColor = Theme.Colors.dimText
            text += focusText
        }
        return text
    }

    /// "Supino Reto com Barra, Peito, Peitoral médio, 5 séries"; "Arquivado" when it was archived.
    static func accessibilityText(of item: WorkoutExercise) -> String {
        var parts = [name(of: item.exercise)]
        if let exercise = item.exercise {
            parts.append(String(localized: exercise.muscleGroup.displayName))
            if let focus = libraryEntry(of: exercise)?.focus {
                parts.append(focus)
            }
            if exercise.isArchived {
                parts.append(String(localized: "Arquivado"))
            }
        }
        parts.append(setCountText(item.plannedSets.count))
        return parts.joined(separator: ", ")
    }

    /// "5 séries", "1 série".
    static func setCountText(_ count: Int) -> String {
        String(localized: "\(count) séries")
    }
}

/// Column widths of the planned set rows and their header, in points of the default text size; they
/// grow with the text. The load and the repetitions share the rest of the row.
enum PlannedSetRowMetrics {
    static let numberWidth: CGFloat = 30
    static let spacing: CGFloat = 6
}

/// The header of the planned set columns: "#", "KG" and "REPS". With the accessibility text sizes only
/// "KG", since the repetitions go to a second line.
struct PlannedSetColumns: View {
    @ScaledMetric(relativeTo: .caption) private var numberWidth = PlannedSetRowMetrics.numberWidth
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: PlannedSetRowMetrics.spacing) {
            Text(verbatim: "#")
                .frame(width: numberWidth)
            Text(verbatim: "kg")
                .frame(maxWidth: .infinity)
            if !dynamicTypeSize.isAccessibilitySize {
                Text("Reps")
                    .frame(maxWidth: .infinity)
            }
        }
        .scaledFont(8, weight: .bold)
        .tracking(1)
        .textCase(.uppercase)
        .foregroundStyle(Theme.Colors.futureDayText)
        .lineLimit(1)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .accessibilityHidden(true)
    }
}

/// One planned set in the editor: its number in the colors of its type (a tap opens the set type sheet),
/// the load and the repetitions, minimum "a" maximum. In one line, or in two with the accessibility
/// text sizes. The typed values are kept by the editor (`text`), never here.
struct PlannedSetRow: View {
    let number: Int
    let plannedSet: PlannedSet
    let text: @MainActor (PlannedSetField) -> Binding<String>
    let focusedField: FocusState<PlannedSetField?>.Binding
    let onChooseType: @MainActor () -> Void

    @ScaledMetric(relativeTo: .caption) private var numberWidth = PlannedSetRowMetrics.numberWidth
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 32
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let id = plannedSet.id
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PlannedSetRowMetrics.spacing) {
                    HStack(spacing: PlannedSetRowMetrics.spacing) {
                        numberButton
                        field(.weight(id), prompt: "kg", keyboard: .decimalPad, label: Text("Carga da série \(number)"), identifier: "workout.set.weight")
                    }
                    HStack(spacing: PlannedSetRowMetrics.spacing) {
                        Color.clear
                            .frame(width: numberWidth, height: 1)
                        reps
                    }
                }
            } else {
                HStack(spacing: PlannedSetRowMetrics.spacing) {
                    numberButton
                    field(.weight(id), prompt: "kg", keyboard: .decimalPad, label: Text("Carga da série \(number)"), identifier: "workout.set.weight")
                    reps
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout.set")
    }

    /// The number in the colors of the set's type; a tap opens the set type sheet.
    private var numberButton: some View {
        Button(action: onChooseType) {
            SetNumberSquare(number: number, type: plannedSet.setType, side: 26, fontSize: 12)
                .frame(width: numberWidth)
                .frame(minHeight: max(44, fieldHeight))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, min(0, (fieldHeight - 44) / 2))
        .accessibilityLabel(Text(verbatim: "\(String(localized: "Série \(number)")), \(String(localized: plannedSet.setType.displayName))"))
        .accessibilityHint(Text("Escolhe o tipo da série ou a remove."))
        .accessibilityIdentifier("workout.set.type")
    }

    /// Minimum "a" maximum.
    private var reps: some View {
        let id = plannedSet.id
        return HStack(spacing: 4) {
            field(.repsMin(id), prompt: String(localized: "mín"), keyboard: .numberPad, label: Text("Mínimo de repetições da série \(number)"), identifier: "workout.set.min")
            Text("a")
                .scaledFont(11)
                .foregroundStyle(Theme.Colors.dimText)
                .accessibilityHidden(true)
            field(.repsMax(id), prompt: String(localized: "máx"), keyboard: .numberPad, label: Text("Máximo de repetições da série \(number)"), identifier: "workout.set.max")
        }
        .frame(maxWidth: .infinity)
    }

    private func field(_ field: PlannedSetField, prompt: String, keyboard: UIKeyboardType, label: Text, identifier: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return TextField(text: text(field), prompt: Text(verbatim: prompt).foregroundStyle(Theme.Colors.suggestionText)) {
            label
        }
            .keyboardType(keyboard)
            .focused(focusedField, equals: field)
            .scaledFont(14, weight: .bold)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.Colors.brightText)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: fieldHeight)
            .background(Theme.Colors.setFieldBackground, in: shape)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
    }
}

/// "+ Adicionar série", the last row of an exercise card: a copy of the last set. The + sits next to
/// the text, and the whole row answers, 44 points tall.
struct EditorAddSetRow: View {
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Label("Adicionar série", systemImage: "plus")
                .labelStyle(TightLabelStyle())
                .scaledFont(12, weight: .semibold)
                .foregroundStyle(Theme.Colors.lightAccent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, editorCardGap)
        .accessibilityIdentifier("workout.addSet")
    }
}

/// An exercise while the exercises are reordered: its icon, its name and how many sets it has. The
/// list draws the drag handle.
struct EditorOrderingRow: View {
    let item: WorkoutExercise

    var body: some View {
        let exercise = item.exercise
        HStack(spacing: 12) {
            EditorExerciseTile(
                exercise: exercise,
                equipment: EditorExerciseInfo.libraryEntry(of: exercise)?.equipment
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: EditorExerciseInfo.name(of: exercise))
                    .scaledFont(14, weight: .heavy)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: EditorExerciseInfo.setCountText(item.plannedSets.count))
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(EditorExerciseInfo.name(of: exercise)), \(EditorExerciseInfo.setCountText(item.plannedSets.count))"))
        .accessibilityIdentifier("workout.ordering.exercise")
    }
}

/// A new workout without exercises: "Nenhum exercício ainda" and "+ Adicionar exercícios".
struct EditorEmptyCard: View {
    let onAdd: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("Nenhum exercício ainda")
                .scaledFont(15, weight: .bold)
            Text("Adicione os exercícios deste treino.")
                .scaledFont(12)
                .foregroundStyle(Theme.Colors.secondaryText)
            Button(action: onAdd) {
                Label("Adicionar exercícios", systemImage: "plus")
                    .scaledFont(14, weight: .bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 40)
                    .background(Color.accentColor, in: Capsule())
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .accessibilityIdentifier("workout.addExercises")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 14)
        .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout.empty")
    }
}
