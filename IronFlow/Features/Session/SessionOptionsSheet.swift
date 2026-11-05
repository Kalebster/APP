import SwiftUI
import UIKit

/// "Opções do treino", from the ⋯ of the session in progress: "Manter a tela ligada" and "Aviso do fim
/// do descanso", kept for the next sessions; then "Descartar treino" (which asks the usual question once
/// the sheet has closed) and "Cancelar".
struct SessionOptionsSheet: View {
    let rest: RestController
    /// "Descartar treino"; the sheet closes first.
    let onDiscard: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 8) {
                Text("Opções do treino")
                    .scaledFont(17, weight: .heavy)
                    .foregroundStyle(Theme.Colors.brightText)
                    .accessibilityAddTraits(.isHeader)
                OptionGroup {
                    OptionRow(
                        title: Text("Manter a tela ligada"),
                        explanation: Text("A tela não apaga sozinha durante o treino")
                    ) {
                        OptionToggle(label: Text("Manter a tela ligada"), isOn: keepScreenOn)
                            .accessibilityIdentifier("options.keepScreenOn")
                    }
                    alertRow
                }
                .padding(.bottom, 2)
                SheetButton(Text("Descartar treino"), kind: .destructive) {
                    dismiss()
                    onDiscard()
                }
                .accessibilityIdentifier("session.discard")
                SheetButton(Text("Cancelar"), kind: .secondary) {
                    dismiss()
                }
                .accessibilityIdentifier("options.cancel")
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, SheetStyle.topPadding)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
    }

    /// "Aviso do fim do descanso": a switch, or, refused in the iPhone's Settings, "Ajustes".
    @ViewBuilder
    private var alertRow: some View {
        if rest.authorization == .denied {
            OptionRow(
                title: Text("Aviso do fim do descanso"),
                explanation: Text("Desligado nos Ajustes do iPhone")
            ) {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Text("Ajustes")
                        .scaledFont(14, weight: .semibold)
                        .foregroundStyle(Theme.Colors.lightAccent)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // The 44-point touch area takes no more room in the row.
                .padding(.vertical, -12)
                .accessibilityHint(Text("Abre os Ajustes do Iron Flow no iPhone"))
                .accessibilityIdentifier("options.alertSettings")
            }
        } else {
            OptionRow(
                title: Text("Aviso do fim do descanso"),
                explanation: rest.isAlertOn
                    ? Text("Avisa a próxima série mesmo com o celular bloqueado")
                    : Text("Desligado: o descanso só aparece na tela")
            ) {
                OptionToggle(label: Text("Aviso do fim do descanso"), isOn: alertOn)
                    .accessibilityIdentifier("options.restAlert")
            }
        }
    }

    private var keepScreenOn: Binding<Bool> {
        Binding(
            get: { rest.settings.keepScreenOn },
            set: { rest.settings.setKeepScreenOn($0) }
        )
    }

    private var alertOn: Binding<Bool> {
        Binding(
            get: { rest.isAlertOn },
            set: { wanted in
                Task { await rest.setAlertWanted(wanted) }
            }
        )
    }
}
