import SwiftUI

/// "Tipo da série N": the four set types, each with the number in its colors, its name and what it
/// means, the chosen one with a blue check, and "Remover série" below. Choosing a type saves it and
/// closes the sheet. Used by the workout editor and by the session in progress.
struct SetTypeSheet: View {
    let number: Int
    let selected: SetType
    /// Why "Remover série" is unavailable ("O exercício precisa ter pelo menos 1 série."); `nil` when
    /// the set can be removed.
    let removalUnavailableReason: String?
    let onChoose: @MainActor (SetType) -> Void
    /// Called once the sheet starts closing.
    let onRemove: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var removeHeight: CGFloat = 50

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tipo da série \(number)")
                    .scaledFont(20, weight: .heavy)
                    .accessibilityAddTraits(.isHeader)
                types
                removeButton
                if let removalUnavailableReason {
                    Text(verbatim: removalUnavailableReason)
                        .scaledFont(12)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("setType.removeHint")
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.cardBackground)
    }

    /// The four types in one block, a line between them.
    private var types: some View {
        VStack(spacing: 0) {
            ForEach(Array(SetType.allCases.enumerated()), id: \.element) { index, type in
                if index > 0 {
                    Theme.Colors.rowSeparator
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                typeRow(type)
            }
        }
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func typeRow(_ type: SetType) -> some View {
        let isSelected = type == selected
        return Button {
            dismiss()
            if !isSelected {
                onChoose(type)
            }
        } label: {
            HStack(spacing: 14) {
                SetNumberSquare(number: number, type: type, side: 28, fontSize: 13)
                VStack(alignment: .leading, spacing: 3) {
                    Text(type.displayName)
                        .scaledFont(15, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                    Text(type.explanation)
                        .scaledFont(11)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .scaledFont(14, weight: .bold)
                        .foregroundStyle(Theme.Colors.lightAccent)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: type.displayName)), \(String(localized: type.explanation))"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("setType.\(type.rawValue)")
    }

    /// "Remover série" in red, unavailable when the exercise has only this set.
    private var removeButton: some View {
        let isEnabled = removalUnavailableReason == nil
        return Button {
            dismiss()
            onRemove()
        } label: {
            Label("Remover série", systemImage: "xmark")
                .scaledFont(15, weight: .bold)
                .foregroundStyle(Theme.Colors.failureSet)
                .frame(maxWidth: .infinity, minHeight: removeHeight)
                .background(Theme.Colors.setFieldBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("setType.remove")
    }
}
