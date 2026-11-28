import SwiftUI

/// "Músculos principais" or "Músculos secundários": the system's sheet over the exercise form, with the
/// body figure that changes at every touch and the 21 muscles as chips, from the top of the body down. A
/// muscle of the other list is dashed, cannot be chosen and says "principal" or "secundário". "Concluir"
/// closes it; every touch already changed the form.
struct MusclesSheet: View {
    let kind: MusclesSheetKind
    @Binding var form: ExerciseForm

    @Environment(\.dismiss) private var dismiss

    /// The size of each body figure in the sheet.
    static let figureSize = CGSize(width: 58, height: 157)

    var body: some View {
        let isPrimary = kind == .primary
        let chosen = isPrimary ? form.draft.primary : form.draft.secondary
        let other = isPrimary ? form.draft.secondary : form.draft.primary
        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(
                    isPrimary ? Text("Músculos principais") : Text("Músculos secundários"),
                    explanation: isPrimary
                        ? Text("Os que o exercício mais trabalha. Pode marcar mais de um. Ficam em destaque no boneco.")
                        : Text("Os que ajudam no movimento. Pode marcar mais de um. Ficam num tom mais escuro no boneco. Opcional.")
                )
                HStack(spacing: 12) {
                    BodyFigure(side: .front, primary: Set(form.draft.primary), secondary: Set(form.draft.secondary), size: Self.figureSize)
                    BodyFigure(side: .back, primary: Set(form.draft.primary), secondary: Set(form.draft.secondary), size: Self.figureSize)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                FlowLayout(spacing: 8) {
                    ForEach(Muscle.bodyOrder, id: \.self) { muscle in
                        let isBlocked = other.contains(muscle)
                        FormChip(
                            title: String(localized: muscle.displayName),
                            isOn: chosen.contains(muscle),
                            isBlocked: isBlocked,
                            note: isBlocked ? (isPrimary ? String(localized: "secundário") : String(localized: "principal")) : nil,
                            fontSize: 13,
                            horizontalPadding: 12
                        ) {
                            form.toggle(muscle, primary: isPrimary)
                        }
                        .accessibilityIdentifier("muscles.chip.\(muscle.rawValue)")
                    }
                }
                .padding(.top, 14)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(isPrimary ? Text("Músculos principais") : Text("Músculos secundários"))
            }
            .sheetContentPadding()
        } bottom: {
            SheetButton(Text("Concluir"), kind: .primary) {
                dismiss()
            }
            .accessibilityIdentifier("muscles.done")
            .sheetButtonBar()
        }
    }
}
