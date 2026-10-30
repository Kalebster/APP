import SwiftUI

/// "Concluir treino?", before anything is saved: the sets done out of all of them, the duration and the
/// load lifted, and the sets that will not be saved. For a session left open it also asks for the end,
/// the time of the last record or now, and the duration follows the choice. "Concluir e salvar" hands
/// the end to `onFinish`; "Continuar treinando" only closes the sheet.
///
/// Without any set done there is nothing to save: "Nenhuma série marcada", with "Continuar treinando"
/// and "Descartar treino" (`onDiscard`). Every button closes the sheet first; the caller acts once it
/// is gone.
struct FinishSessionSheet: View {
    let summary: SessionFinishSummary
    let onFinish: @MainActor (SessionEnd) -> Void
    let onDiscard: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The end of a session left open; the time of the last record until another is chosen.
    @State private var end = SessionEnd.lastCompletedSet

    @ScaledMetric(relativeTo: .subheadline) private var segmentHeight: CGFloat = 38

    var body: some View {
        if summary.doneSets > 0 {
            finishSheet
        } else {
            nothingDoneSheet
        }
    }

    private var finishSheet: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(Text("Concluir treino?"))
                boxes
                if let notDoneText = summary.notDoneText {
                    Text(verbatim: notDoneText)
                        .scaledFont(13)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("finish.notDone")
                }
                if let suggestedEnd = summary.suggestedEnd {
                    endChoice(suggestedEnd)
                }
            }
            .sheetContentPadding()
        } bottom: {
            VStack(spacing: 10) {
                SheetButton(Text("Concluir e salvar"), kind: .primary) {
                    onFinish(summary.suggestedEnd == nil ? .now : end)
                    dismiss()
                }
                .accessibilityIdentifier("finish.save")
                continueButton
            }
            .sheetButtonBar()
        }
    }

    private var nothingDoneSheet: some View {
        FittedSheet {
            SheetHeader(
                Text("Nenhuma série marcada"),
                explanation: Text("Marque pelo menos uma série para salvar o treino.")
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheetContentPadding()
        } bottom: {
            VStack(spacing: 10) {
                continueButton
                SheetButton(Text("Descartar treino"), kind: .secondary) {
                    onDiscard()
                    dismiss()
                }
                .accessibilityIdentifier("finish.discard")
            }
            .sheetButtonBar()
        }
    }

    private var continueButton: some View {
        SheetButton(Text("Continuar treinando"), kind: .secondary) {
            dismiss()
        }
        .accessibilityIdentifier("finish.continue")
    }

    // MARK: - Summary

    /// The sets done, the duration and the load lifted, side by side; one below the other with the
    /// largest text sizes, so no number is cut. The duration up to now goes on while the sheet stays
    /// open, as finishing records the moment "Concluir e salvar" is tapped.
    private var boxes: some View {
        let layout = dynamicTypeSize >= .accessibility1 ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return TimelineView(.periodic(from: summary.now, by: 15)) { timeline in
            let duration = summary.duration(endingAt: summary.suggestedEnd == nil ? .now : end, at: timeline.date)
            boxRow(layout: layout, duration: duration)
        }
    }

    private func boxRow(layout: AnyLayout, duration: TimeInterval) -> some View {
        layout {
            box(
                value: summary.setsText,
                caption: "séries",
                spoken: summary.setsAccessibilityText,
                identifier: "finish.sets"
            )
            box(
                value: SessionFormatting.compactDurationText(duration),
                caption: "duração",
                spoken: String(localized: "duração \(SessionFormatting.spokenDurationText(duration))"),
                identifier: "finish.duration"
            )
            box(
                value: SessionFormatting.kilogramsText(summary.volumeKg),
                caption: "kg levantados",
                spoken: SessionFormatting.volumeText(summary.volumeKg),
                identifier: "finish.volume"
            )
        }
    }

    private func box(value: String, caption: LocalizedStringKey, spoken: String, identifier: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .scaledFont(19, weight: .heavy)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.brightText)
            Text(caption)
                .scaledFont(11)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spoken))
        .accessibilityIdentifier(identifier)
    }

    // MARK: - End of a session left open

    /// "Seu último registro foi às 18:05. Usar esse horário como fim?" and the two ends side by side,
    /// the chosen one in blue.
    private func endChoice(_ suggestedEnd: Date) -> some View {
        let calendar = TrainingDay.calendar
        let layout = dynamicTypeSize >= .accessibility1 ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 4))
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: SessionFormatting.lastRecordQuestion(suggestedEnd, now: summary.now, calendar: calendar))
                .scaledFont(13)
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("finish.question")
            layout {
                endOption(
                    .lastCompletedSet,
                    title: String(localized: "Usar \(SessionFormatting.timeText(suggestedEnd, calendar: calendar))"),
                    identifier: "finish.end.lastRecord"
                )
                endOption(.now, title: String(localized: "Usar agora"), identifier: "finish.end.now")
            }
            .padding(.horizontal, 3)
            .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func endOption(_ option: SessionEnd, title: String, identifier: String) -> some View {
        let isSelected = option == end
        return Button {
            end = option
        } label: {
            Text(verbatim: title)
                .scaledFont(14, weight: .semibold)
                .foregroundStyle(isSelected ? Theme.Colors.highlightText : Theme.Colors.mediumText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: segmentHeight)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Theme.Colors.highlightBadge)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(Theme.Colors.highlightLine, lineWidth: 1)
                            )
                    }
                }
                // The 3 points of the block around the segment answer too: 44 points to touch.
                .padding(.vertical, 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
