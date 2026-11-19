import SwiftUI

/// Shown when the data store cannot be opened.
///
/// Non-destructive by design: it never deletes, moves, replaces or recreates the
/// store. "Tentar novamente" only asks the app to open the same store again.
struct PersistenceErrorView: View {
    let error: any Error
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("Não foi possível abrir seus dados")
                    .scaledFont(22, weight: .bold)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("persistence.error.title")

                Text("Seus dados não foram apagados. Feche e abra o app novamente. Se o problema continuar, atualize o app.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // A main button of the app: white with black text, 34 high as the system's button it
                // replaces; 5 more points above and below answer, for a 44-point touch area.
                Button(action: retry) {
                    Text("Tentar novamente")
                        .scaledFont(17)
                        .foregroundStyle(Theme.Colors.primaryButtonText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                        .background(Theme.Colors.primaryButton, in: Capsule())
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -5)
                .accessibilityIdentifier("persistence.error.retry")

                // The technical detail stays in the system's fixed-width font until it gives way to a
                // friendly message (ROTEIRO, S10).
                Text(verbatim: String(describing: error))
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .padding(24)
            .padding(.top, 48)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    PersistenceErrorView(error: CocoaError(.fileReadCorruptFile)) {}
}
