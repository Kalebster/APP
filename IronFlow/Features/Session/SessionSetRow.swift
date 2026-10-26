import SwiftUI

/// A text field of a set row, so its value is saved when it loses focus.
enum SetField: Hashable {
    case weight(UUID)
    case reps(UUID)

    var logID: UUID {
        switch self {
        case .weight(let id), .reps(let id): id
        }
    }
}

/// Column widths shared by the set rows and their header, in points of the default text size; they
/// grow with the text. The load and the repetitions share the rest of the row.
enum SetRowMetrics {
    static let numberWidth: CGFloat = 22
    static let previousWidth: CGFloat = 54
    static let checkWidth: CGFloat = 32
    static let spacing: CGFloat = 6
    /// The rows sit 4 points inside the card padding, so the current set's highlight has room around them.
    static let innerPadding: CGFloat = 4
}

/// The header of the set columns: "#", "ÚLTIMA", "KG" and "REPS". With the accessibility text sizes
/// only the load and the repetitions, over the second line of each set.
struct SessionSetColumns: View {
    @ScaledMetric(relativeTo: .caption) private var numberWidth = SetRowMetrics.numberWidth
    @ScaledMetric(relativeTo: .caption2) private var previousWidth = SetRowMetrics.previousWidth
    @ScaledMetric(relativeTo: .body) private var checkWidth = SetRowMetrics.checkWidth
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: SetRowMetrics.spacing) {
                    Text(verbatim: "kg")
                        .frame(maxWidth: .infinity)
                    Text("Reps")
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: SetRowMetrics.spacing) {
                    Text(verbatim: "#")
                        .frame(width: numberWidth)
                    Text("Última")
                        .frame(width: previousWidth, alignment: .leading)
                    Text(verbatim: "kg")
                        .frame(maxWidth: .infinity)
                    Text("Reps")
                        .frame(maxWidth: .infinity)
                    Color.clear
                        .frame(width: checkWidth, height: 1)
                }
            }
        }
        .scaledFont(8, weight: .bold)
        .tracking(1)
        .textCase(.uppercase)
        .foregroundStyle(Theme.Colors.futureDayText)
        .lineLimit(1)
        .padding(.horizontal, SetRowMetrics.innerPadding)
        .accessibilityHidden(true)
    }
}

/// One set of the session: its number, what it did the last time ("ÚLTIMA"), its load and repetitions
/// and the completion mark. An empty field shows the suggestion in gray, which checking the set records.
/// A set done shows its number in light blue and its values in white; the current set (the first not
/// done of the current exercise) is highlighted. A warm-up, feeder or failure set shows its number in the
/// colors of its type; a tap on the number opens the set type sheet. In one line, or in two with the
/// accessibility text sizes.
struct SessionSetRow: View {
    let number: Int
    let log: SetLog
    let previous: PreviousSet?
    let suggestion: SetSuggestion
    let isCurrent: Bool
    @Binding var draft: SetDraft
    let focusedField: FocusState<SetField?>.Binding
    let onToggle: @MainActor () -> Void
    let onChooseType: @MainActor () -> Void

    @ScaledMetric(relativeTo: .caption) private var numberWidth = SetRowMetrics.numberWidth
    @ScaledMetric(relativeTo: .caption2) private var previousWidth = SetRowMetrics.previousWidth
    @ScaledMetric(relativeTo: .body) private var checkWidth = SetRowMetrics.checkWidth
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var checkSide: CGFloat = 28
    @ScaledMetric(relativeTo: .caption) private var numberSide: CGFloat = 22
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isDone: Bool { log.isCompleted }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // With the accessibility text sizes the five columns do not fit the screen: the load and
                // the repetitions go to a second line and share its width.
                VStack(spacing: SetRowMetrics.spacing) {
                    HStack(spacing: SetRowMetrics.spacing) {
                        numberView
                        previousText
                            .frame(maxWidth: .infinity, alignment: .leading)
                        checkButton
                    }
                    HStack(spacing: SetRowMetrics.spacing) {
                        weightField
                        repsField
                    }
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: SetRowMetrics.spacing) {
                    numberView
                    previousText
                        .frame(width: previousWidth, alignment: .leading)
                    weightField
                    repsField
                    checkButton
                }
            }
        }
        .padding(.horizontal, SetRowMetrics.innerPadding)
        .frame(minHeight: rowHeight)
        .background {
            if isCurrent {
                let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
                shape
                    .fill(Theme.Colors.currentSetBackground)
                    .overlay(shape.strokeBorder(Color.accentColor, lineWidth: 1))
            }
        }
        .sensoryFeedback(.success, trigger: log.isCompleted) { wasCompleted, isCompleted in
            !wasCompleted && isCompleted
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session.set")
    }

    /// The number: a working set as before (in a blue circle when current, light blue once done); the
    /// other types in a circle of their color, filled when current. A tap opens the set type sheet; it
    /// answers on the whole height of the row.
    private var numberView: some View {
        let type = log.setType
        return Button(action: onChooseType) {
            Text(number.formatted())
                .scaledFont(12, weight: .bold)
                .monospacedDigit()
                .foregroundStyle(numberColor(type))
                .frame(width: numberSide, height: numberSide)
                .background {
                    if type == .working {
                        if isCurrent {
                            Circle().fill(Color.accentColor)
                        }
                    } else {
                        Circle().fill(isCurrent ? type.numberColor : type.numberBackground)
                    }
                }
                .frame(width: max(numberWidth, numberSide) + 8, height: rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -4)
        .accessibilityLabel(Text(verbatim: numberAccessibilityText(type)))
        .accessibilityHint(Text("Escolhe o tipo da série ou a remove."))
        .accessibilityIdentifier("session.set.type")
    }

    private func numberColor(_ type: SetType) -> Color {
        if type == .working {
            return isCurrent ? Color.white : isDone ? Theme.Colors.lightAccent : Color.secondary
        }
        return isCurrent ? Theme.Colors.screenBackground : type.numberColor
    }

    /// "Série 2", "Série 2, atual"; the other types say theirs: "Série 1, Aquecimento".
    private func numberAccessibilityText(_ type: SetType) -> String {
        var parts = [String(localized: "Série \(number)")]
        if type != .working {
            parts.append(String(localized: type.displayName))
        }
        if isCurrent {
            parts.append(String(localized: "atual"))
        }
        return parts.joined(separator: ", ")
    }

    private var previousText: some View {
        Text(verbatim: LastPerformance.text(of: previous))
            .scaledFont(10)
            .monospacedDigit()
            .foregroundStyle(Theme.Colors.futureDayText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel(Text(verbatim: LastPerformance.accessibilityText(of: previous)))
            .accessibilityIdentifier("session.set.previous")
    }

    private var weightField: some View {
        TextField("kg", text: $draft.weight, prompt: prompt(weightPrompt))
            .keyboardType(.decimalPad)
            .focused(focusedField, equals: .weight(log.id))
            .modifier(fieldStyle { focusedField.wrappedValue = .weight(log.id) })
            .accessibilityLabel(Text("Carga da série \(number)"))
            .modifier(DoneSetLoadValue(isDone: isDone, text: draft.weight))
            .accessibilityIdentifier("session.set.weight")
    }

    /// The gray text of an empty load field: the suggestion while the set is still to do. Once the set
    /// is done, an empty field means no load was recorded: "—", never a value it did not lift.
    private var weightPrompt: String {
        if isDone {
            return "—"
        }
        return suggestion.weightKg.map { PlannedSetFormatting.weightFieldText($0) } ?? "kg"
    }

    private var repsField: some View {
        let hint = suggestion.reps.map { $0.formatted() }
        return TextField("Reps", text: $draft.reps, prompt: prompt(hint ?? String(localized: "Reps")))
            .keyboardType(.numberPad)
            .focused(focusedField, equals: .reps(log.id))
            .modifier(fieldStyle { focusedField.wrappedValue = .reps(log.id) })
            .accessibilityLabel(Text("Repetições da série \(number)"))
            .accessibilityIdentifier("session.set.reps")
    }

    /// The gray text of an empty field: the suggestion, or the field's name when there is none.
    private func prompt(_ text: String) -> Text {
        Text(verbatim: text)
            .foregroundStyle(isCurrent ? Theme.Colors.currentSuggestionText : Theme.Colors.suggestionText)
    }

    private func fieldStyle(focus: @escaping @MainActor () -> Void) -> SetFieldStyle {
        SetFieldStyle(
            fill: isDone ? Color.clear : isCurrent ? Theme.Colors.currentFieldBackground : Theme.Colors.setFieldBackground,
            height: fieldHeight,
            touchHeight: rowHeight,
            focus: focus
        )
    }

    /// The completion mark: an outlined circle, light blue on the current set, filled once the set is
    /// done. It answers on the whole height of the row, and 6 points to each side of its column.
    private var checkButton: some View {
        Button(action: onToggle) {
            ZStack {
                if isDone {
                    Circle().fill(Color.accentColor)
                } else {
                    Circle().strokeBorder(isCurrent ? Color.accentColor : Theme.Colors.controlBorder, lineWidth: 1.5)
                }
                Image(systemName: "checkmark")
                    .scaledFont(12, weight: .bold)
                    .foregroundStyle(isDone ? Color.white : isCurrent ? Theme.Colors.lightAccent : Theme.Colors.dimText)
            }
            .frame(width: checkSide, height: checkSide)
            .frame(width: checkWidth + 12, height: rowHeight)
            .contentShape(Rectangle())
            // The checkmark symbol reads as "selected" on its own, even on a set not done: the button says
            // what it does, and is selected only once the set is done.
            .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -6)
        .accessibilityLabel(isDone ? Text("Desmarcar série \(number)") : Text("Concluir série \(number)"))
        .accessibilityAddTraits(isDone ? .isSelected : [])
        .accessibilityRemoveTraits(isDone ? [] : .isSelected)
        .accessibilityIdentifier("session.set.check")
    }
}

/// What VoiceOver reads as the load of a set done: the load, or "Sem carga" when none was recorded,
/// instead of the "—" on screen. A set still to do keeps the field's own reading (its suggestion when
/// empty). Changing between the two happens only when the set is checked or unchecked.
private struct DoneSetLoadValue: ViewModifier {
    let isDone: Bool
    let text: String

    func body(content: Content) -> some View {
        if isDone {
            content.accessibilityValue(text.isEmpty ? Text("Sem carga") : Text(verbatim: text))
        } else {
            content
        }
    }
}

/// A set's field: 36 points of fill with rounded corners and the value in bold, centered. The whole
/// height of the row answers: a tap beside the text gives the field the focus (`focus`).
private struct SetFieldStyle: ViewModifier {
    let fill: Color
    let height: CGFloat
    let touchHeight: CGFloat
    let focus: @MainActor () -> Void

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        content
            .scaledFont(14, weight: .bold)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: shape)
            .frame(minHeight: touchHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                focus()
            }
    }
}
