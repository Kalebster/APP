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

/// Column widths shared by the set rows and their header, scaled with the text size.
enum SetRowMetrics {
    static let numberWidth: CGFloat = 24
    static let weightWidth: CGFloat = 68
    static let repsWidth: CGFloat = 56
    static let checkWidth: CGFloat = 44
}

/// One set of the session: number, target, load, repetitions and the completion mark, in one line, or
/// in two with the accessibility text sizes.
struct SessionSetRow: View {
    let number: Int
    let log: SetLog
    @Binding var draft: SetDraft
    let focusedField: FocusState<SetField?>.Binding
    let onToggle: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var weightWidth = SetRowMetrics.weightWidth
    @ScaledMetric(relativeTo: .body) private var repsWidth = SetRowMetrics.repsWidth
    @ScaledMetric(relativeTo: .body) private var checkWidth = SetRowMetrics.checkWidth
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // With the accessibility text sizes the five columns do not fit the screen: the load and
                // the repetitions go to a second line and share its width.
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        numberText
                        targetText
                        checkButton
                    }
                    HStack(spacing: 8) {
                        weightField
                            .frame(maxWidth: .infinity)
                        repsField
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    numberText
                    targetText
                    weightField
                        .frame(width: weightWidth)
                    repsField
                        .frame(width: repsWidth)
                    checkButton
                }
            }
        }
        .sensoryFeedback(.success, trigger: log.isCompleted) { wasCompleted, isCompleted in
            !wasCompleted && isCompleted
        }
    }

    private var numberText: some View {
        Text(number.formatted())
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .frame(minWidth: SetRowMetrics.numberWidth, alignment: .leading)
    }

    private var targetText: some View {
        let target = SessionFormatting.targetText(min: log.targetRepsMin, max: log.targetRepsMax)
        return Text(target ?? "—")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(target.map { Text("Meta: \($0)") } ?? Text("Sem meta"))
    }

    private var weightField: some View {
        TextField("kg", text: $draft.weight)
            .keyboardType(.decimalPad)
            .focused(focusedField, equals: .weight(log.id))
            .modifier(SetFieldStyle { focusedField.wrappedValue = .weight(log.id) })
            .accessibilityLabel(Text("Carga da série \(number)"))
            .accessibilityIdentifier("session.set.weight")
    }

    private var repsField: some View {
        // Empty repetitions are filled with the target when the set is checked; it is shown as the hint.
        let repsHint = SessionFormatting.repsForCompletion(typed: nil, targetMin: log.targetRepsMin, targetMax: log.targetRepsMax)
        return TextField("Reps", text: $draft.reps, prompt: repsHint.map { Text($0.formatted()) } ?? Text("Reps"))
            .keyboardType(.numberPad)
            .focused(focusedField, equals: .reps(log.id))
            .modifier(SetFieldStyle { focusedField.wrappedValue = .reps(log.id) })
            .accessibilityLabel(Text("Repetições da série \(number)"))
            .accessibilityIdentifier("session.set.reps")
    }

    private var checkButton: some View {
        Button(action: onToggle) {
            Image(systemName: log.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(log.isCompleted ? Color.accentColor : Color.secondary)
                .frame(width: checkWidth, height: checkWidth)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(log.isCompleted ? Text("Desmarcar série \(number)") : Text("Concluir série \(number)"))
        .accessibilityAddTraits(log.isCompleted ? .isSelected : [])
        .accessibilityIdentifier("session.set.check")
    }
}

/// A compact, centered field on a light fill, at least 44 points tall so it is easy to hit during a
/// workout. The whole fill responds: a tap beside the text gives the field the focus (`focus`).
private struct SetFieldStyle: ViewModifier {
    let focus: @MainActor () -> Void

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        content
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(minHeight: 44)
            .background(.fill.tertiary, in: shape)
            .contentShape(shape)
            .onTapGesture {
                focus()
            }
    }
}
