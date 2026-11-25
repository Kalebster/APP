import SwiftUI

/// "Tipos de máquina": what each kind of machine is, with ESTE on the exercise's own, and "Entendi".
/// The system's sheet, as tall as its content. The line at the top depends on where it opens.
struct MachineTypesSheet: View {
    /// Where the sheet opens, for the line at its top.
    enum Context {
        /// The screen of a library exercise: the most common kind for it.
        case library
        /// The screen of an exercise of the user's own: the kind the person chose.
        case custom
        /// The exercise form, while choosing.
        case form
    }

    /// The kind of machine of the exercise.
    let current: MachineType?
    var context = Context.library

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(Text("Tipos de máquina"), explanation: explanation, explanationIdentifier: "machineTypes.explanation")
                VStack(spacing: 0) {
                    ForEach(Array(MachineType.allCases.enumerated()), id: \.element) { index, machine in
                        VStack(spacing: 0) {
                            row(machine)
                            // The line below each row but the last, 1 point of its own, as in the prototype.
                            if index < MachineType.allCases.count - 1 {
                                Theme.Colors.sheetListSeparator.frame(height: 1)
                            }
                        }
                    }
                }
                .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 14)
                Text("O kg de uma máquina não vale para outra: compare sua evolução sempre na mesma máquina.")
                    .scaledFont(13, lineHeight: 1.4)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .sheetContentPadding()
        } bottom: {
            SheetButton(Text("Entendi"), kind: .primary) {
                dismiss()
            }
            .accessibilityIdentifier("machineTypes.done")
            .sheetButtonBar()
        }
    }

    private var explanation: Text {
        switch context {
        case .library: Text("O mesmo exercício muda de academia para academia. Este é o tipo mais comum para ele.")
        case .custom: Text("Este é o tipo que você escolheu para este exercício.")
        case .form: Text("Escolha o tipo da máquina que você usa. Se não souber, deixe “Não sei”.")
        }
    }

    private func row(_ machine: MachineType) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(machine.displayName)
                    .scaledFont(15, weight: .semibold)
                    .foregroundStyle(Theme.Colors.brightText)
                if machine == current {
                    CapsuleBadge(
                        text: String(localized: "ESTE"),
                        weight: .heavy,
                        tracking: 0.8,
                        padding: EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7),
                        foreground: Theme.Colors.primaryButtonText,
                        background: Theme.Colors.primaryButton
                    )
                }
            }
            Text(machine.explanation)
                .scaledFont(13, lineHeight: 1.35)
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(machine == current ? "machineTypes.current" : "machineTypes.row")
    }
}
