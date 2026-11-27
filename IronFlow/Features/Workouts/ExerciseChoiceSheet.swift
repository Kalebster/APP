import SwiftUI

/// The choice sheet of the picker, for a base exercise: the same rows as its screen (EQUIPAMENTO and, when
/// it has one, PEGADA or VARIAÇÃO), the combination shown (its icon, "Polia · Triângulo", "Última vez:
/// dd/mm" or "Nunca feito" and the kind of machine), "Também escolhido: …" with the others of the base
/// already chosen, and "Escolher" (it closes), "Desmarcar" (it stays open) or "Já está no treino" (off),
/// with "Fechar". Every combination has its own history, evolution and records.
struct ExerciseChoiceSheet: View {
    let base: ExerciseBase
    let records: LibraryRecords
    let lastDone: ExerciseLastDone
    @Binding var selection: ExerciseSelection

    @Environment(\.dismiss) private var dismiss
    @State private var shown: DefaultExercise
    /// Set once "Escolher" closes the sheet, so a second tap while it closes does nothing.
    @State private var isClosing = false

    @ScaledMetric(relativeTo: .body) private var tileSide: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 18

    init(base: ExerciseBase, start: DefaultExercise, records: LibraryRecords, lastDone: ExerciseLastDone, selection: Binding<ExerciseSelection>) {
        self.base = base
        self.records = records
        self.lastDone = lastDone
        _selection = selection
        _shown = State(initialValue: start)
    }

    var body: some View {
        let id = records.byKey[shown.key]?.id
        let isInWorkout = id.map(selection.isInWorkout) ?? false
        let isChosen = id.map(selection.isSelected) ?? false
        let others = Self.chosen(of: base, in: selection, records: records).filter { $0.key != shown.key }

        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(Text(verbatim: base.name), explanation: Text(verbatim: explanation))
                    .padding(.bottom, 14)
                ExerciseOptionRows(
                    base: base,
                    selected: shown,
                    hiddenKeys: records.hiddenKeys,
                    captionTopPadding: 4,
                    identifierPrefix: "choice"
                ) { target in
                    shown = target
                }
                .padding(.bottom, 18)
                shownCombination
                if !others.isEmpty {
                    Text(verbatim: String(localized: "Também escolhido: \(others.map(ExerciseBaseIndex.optionText).joined(separator: ", "))"))
                        .scaledFont(12, lineHeight: 1.4, webKitLine: true)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                        .padding(.top, 8)
                        .accessibilityIdentifier("choice.also")
                }
            }
            .sheetContentPadding()
        } bottom: {
            VStack(spacing: 8) {
                if isInWorkout {
                    SheetButton(Text("Já está no treino"), kind: .secondary, usesPrototypeStyle: true) {}
                        .disabled(true)
                        .accessibilityIdentifier("choice.inWorkout")
                } else if isChosen {
                    SheetButton(Text("Desmarcar"), kind: .secondary, usesPrototypeStyle: true) {
                        toggle()
                    }
                    .accessibilityIdentifier("choice.unchoose")
                } else {
                    SheetButton(Text("Escolher"), kind: .primary, usesPrototypeStyle: true) {
                        choose()
                    }
                    // A hidden combination (its name is taken by an exercise of the user's own) cannot be chosen.
                    .disabled(id == nil || isClosing || records.hiddenKeys.contains(shown.key))
                    .accessibilityIdentifier("choice.choose")
                }
                SheetButton(Text("Fechar"), kind: .secondary, usesPrototypeStyle: true) {
                    dismiss()
                }
                .accessibilityIdentifier("choice.close")
            }
            .sheetButtonBar()
        }
    }

    private var explanation: String {
        let gray = String(localized: "Em cinza, os menos comuns neste exercício.")
        guard let secondRow = base.secondRow else {
            return String(localized: "Escolha o equipamento. Cada um tem a sua evolução e os seus recordes.") + " " + gray
        }
        let first = secondRow.kind == .grip
            ? String(localized: "Escolha o equipamento e a pegada. Cada combinação tem a sua evolução e os seus recordes.")
            : String(localized: "Escolha o equipamento e a variação. Cada combinação tem a sua evolução e os seus recordes.")
        return first + " " + gray
    }

    /// The combination shown: its icon, "Polia · Triângulo" and, below, "Última vez: dd/mm" or "Nunca feito"
    /// with the kind of machine (not Graviton, which the equipment already says).
    private var shownCombination: some View {
        HStack(spacing: 12) {
            EquipmentIcon(equipment: shown.equipment)
                .frame(width: iconSide, height: iconSide)
                .foregroundStyle(Theme.Colors.lightAccent)
                .frame(width: tileSide, height: tileSide)
                .background(Theme.Colors.iconTileBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ExerciseBaseIndex.optionText(of: shown))
                    .scaledFont(15, weight: .bold)
                    .foregroundStyle(Theme.Colors.brightText)
                Text(verbatim: info)
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("choice.shown")
    }

    private var info: String {
        var parts: [String] = []
        if let date = lastDone.byKey[shown.key] {
            parts.append(String(localized: "Última vez: \(Self.dayAndMonth(date))"))
        } else {
            parts.append(String(localized: "Nunca feito"))
        }
        if let machine = DefaultExerciseMuscles.byKey[shown.key]?.machine, machine != .graviton {
            parts.append(String(localized: machine.displayName))
        }
        return parts.joined(separator: " · ")
    }

    /// "05/11".
    static func dayAndMonth(_ date: Date) -> String {
        let parts = TrainingDay.calendar.dateComponents([.day, .month], from: date)
        return String(format: "%02ld/%02ld", parts.day ?? 0, parts.month ?? 0)
    }

    /// The combinations of `base` chosen, in the order they were chosen.
    static func chosen(of base: ExerciseBase, in selection: ExerciseSelection, records: LibraryRecords) -> [DefaultExercise] {
        let combinations = ExerciseBaseIndex.combinations[base.name] ?? []
        let byID = Dictionary(combinations.compactMap { entry in records.byKey[entry.key].map { ($0.id, entry) } }) { first, _ in first }
        return selection.selectedIDs.compactMap { byID[$0] }
    }

    /// "Escolher": chosen, and the sheet closes; once.
    private func choose() {
        guard !isClosing else { return }
        isClosing = true
        toggle()
        dismiss()
    }

    private func toggle() {
        guard let id = records.byKey[shown.key]?.id else { return }
        selection.toggle(id)
    }
}
