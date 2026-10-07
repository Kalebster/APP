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

/// One set of the session: number, target, load, repetitions and the completion mark.
struct SessionSetRow: View {
    let number: Int
    let log: SetLog
    @Binding var draft: SetDraft
    let focusedField: FocusState<SetField?>.Binding
    let onToggle: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var weightWidth = SetRowMetrics.weightWidth
    @ScaledMetric(relativeTo: .body) private var repsWidth = SetRowMetrics.repsWidth
    @ScaledMetric(relativeTo: .body) private var checkWidth = SetRowMetrics.checkWidth

    var body: some View {
        let target = SessionFormatting.targetText(min: log.targetRepsMin, max: log.targetRepsMax)
        // Empty repetitions are filled with the target when the set is checked; it is shown as the hint.
        let repsHint = SessionFormatting.repsForCompletion(typed: nil, targetMin: log.targetRepsMin, targetMax: log.targetRepsMax)

        HStack(spacing: 8) {
            Text(number.formatted())
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: SetRowMetrics.numberWidth, alignment: .leading)
            Text(target ?? "—")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(target.map { Text("Meta: \($0)") } ?? Text("Sem meta"))
            TextField("kg", text: $draft.weight)
                .keyboardType(.decimalPad)
                .focused(focusedField, equals: .weight(log.id))
                .modifier(SetFieldStyle())
                .frame(width: weightWidth)
                .accessibilityLabel(Text("Carga da série \(number)"))
                .accessibilityIdentifier("session.set.weight")
            TextField("Reps", text: $draft.reps, prompt: repsHint.map { Text($0.formatted()) } ?? Text("Reps"))
            .keyboardType(.numberPad)
            .focused(focusedField, equals: .reps(log.id))
            .modifier(SetFieldStyle())
            .frame(width: repsWidth)
            .accessibilityLabel(Text("Repetições da série \(number)"))
            .accessibilityIdentifier("session.set.reps")
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
        .sensoryFeedback(.success, trigger: log.isCompleted) { wasCompleted, isCompleted in
            !wasCompleted && isCompleted
        }
    }
}

/// A compact, centered field on a light fill.
private struct SetFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
