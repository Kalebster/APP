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
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("persistence.error.title")

                Text("Seus dados não foram apagados. Feche e abra o app novamente. Se o problema continuar, atualize o app.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Tentar novamente", action: retry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("persistence.error.retry")

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
