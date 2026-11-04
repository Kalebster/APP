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
    @ScaledMetric(relativeTo: .subheadline) private var removeHeight: CGFloat = 46

    var body: some View {
        // As tall as what it shows, as the other sheets.
        FittedSheet {
            // 8 between the blocks, as in the model's sheets.
            VStack(alignment: .leading, spacing: 8) {
                Text("Tipo da série \(number)")
                    .scaledFont(17, weight: .heavy)
                    .foregroundStyle(Theme.Colors.brightText)
                    .accessibilityAddTraits(.isHeader)
                types
                removeButton
                if let removalUnavailableReason {
                    Text(verbatim: removalUnavailableReason)
                        .scaledFont(13, lineHeight: 1.4)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("setType.removeHint")
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, SheetStyle.topPadding)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
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
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func typeRow(_ type: SetType) -> some View {
        let isSelected = type == selected
        return Button {
            dismiss()
            if !isSelected {
                onChoose(type)
            }
        } label: {
            HStack(spacing: 12) {
                SetNumberSquare(number: number, type: type, side: 28, fontSize: 13)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .scaledFont(15, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                    Text(type.explanation)
                        .scaledFont(11, lineHeight: 1.35)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AppIcon(.check, size: 13)
                    .foregroundStyle(Theme.Colors.lightAccent)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 20)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
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
            HStack(spacing: 8) {
                AppIcon(.menuClose, size: 18)
                Text("Remover série")
            }
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
