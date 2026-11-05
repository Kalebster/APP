import SwiftUI

/// "Descanso entre séries": the rest of one exercise of the workout. The explanation names the exercise;
/// below it, the choices in three columns (1:30 with "PADRÃO" below), "Sem timer" across the whole row,
/// and "Cancelar" at the bottom. The chosen one is on the highlight's blue. Choosing closes the sheet and
/// saves the choice.
struct RestPickerSheet: View {
    let exerciseName: String
    let selected: Int
    /// Called with the chosen rest, in seconds (0 is "Sem timer"), once the sheet starts closing.
    let onChoose: @MainActor (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var optionHeight: CGFloat = 48

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(
                    Text("Descanso entre séries"),
                    explanation: Text("\(exerciseName). O timer começa quando você marca uma série. No treino, o −15 e o +15 ajustam na hora."),
                    explanationIdentifier: "rest.explanation"
                )
                VStack(spacing: 8) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(RestDuration.choices, id: \.self) { seconds in
                            option(seconds)
                        }
                    }
                    option(RestDuration.noTimer)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Descanso entre séries"))
                .accessibilityIdentifier("rest.options")
            }
            .sheetContentPadding()
        } bottom: {
            SheetButton(Text("Cancelar"), kind: .secondary) {
                dismiss()
            }
            .accessibilityIdentifier("rest.cancel")
            .sheetButtonBar()
        }
    }

    private func option(_ seconds: Int) -> some View {
        let isSelected = seconds == selected
        let isDefault = seconds == RestDuration.defaultSeconds
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            dismiss()
            if !isSelected {
                onChoose(seconds)
            }
        } label: {
            VStack(spacing: 1) {
                Text(verbatim: RestDuration.text(seconds))
                    .scaledFont(seconds == RestDuration.noTimer ? 14 : 16, weight: .bold)
                    .monospacedDigit()
                if isDefault {
                    Text("Padrão")
                        .scaledFont(9, weight: .bold)
                        .tracking(0.6)
                        .textCase(.uppercase)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isSelected ? Theme.Colors.highlightText : Theme.Colors.mediumText)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: optionHeight)
            .background(isSelected ? Theme.Colors.highlightBadge : Theme.Colors.screenBackground, in: shape)
            .overlay {
                if isSelected {
                    shape.strokeBorder(Theme.Colors.highlightLine, lineWidth: 1)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: isDefault
            ? String(localized: "\(RestDuration.spokenText(seconds)), padrão")
            : RestDuration.spokenText(seconds)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("rest.option.\(seconds)")
    }
}
