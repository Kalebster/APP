import SwiftUI

/// "Avisar quando o descanso acabar?": shown once, at the first rest, while the rest runs behind it,
/// before the iPhone's own question is ever asked. It shows what the notice looks like on the lock
/// screen, with the session's real next set. "Ativar aviso" closes it and then asks the iPhone's
/// question; "Agora não", or closing it otherwise, leaves the notice off.
struct RestAlertOfferSheet: View {
    /// "Próxima: Supino Reto com Barra · série 2 de 5".
    let nextSet: String?
    /// "Ativar aviso"; the sheet closes first.
    let onAccept: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(
                    Text("Avisar quando o descanso acabar?"),
                    explanation: Text("O Iron Flow avisa a hora da próxima série mesmo com o celular bloqueado ou com o app fechado. Fica assim:")
                )
                LockScreenPreview(nextSet: nextSet)
            }
            .sheetContentPadding()
        } bottom: {
            VStack(spacing: 8) {
                SheetButton(Text("Ativar aviso"), kind: .primary) {
                    onAccept()
                    dismiss()
                }
                .accessibilityIdentifier("restAlert.accept")
                SheetButton(Text("Agora não"), kind: .secondary) {
                    dismiss()
                }
                .accessibilityIdentifier("restAlert.decline")
            }
            .sheetButtonBar()
        }
    }
}

/// The lock screen with the notice, an illustration only: hidden from VoiceOver. The date and the time
/// are now's; the notice has the real texts.
private struct LockScreenPreview: View {
    let nextSet: String?

    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 34

    private static let locale = Locale(identifier: "pt_BR")

    var body: some View {
        let now = Date.now
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 0) {
            Text(verbatim: now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Self.locale)))
                .scaledFont(13, weight: .semibold)
                .foregroundStyle(Theme.Colors.lightAccent)
                .padding(.top, 20)
            Text(verbatim: SessionFormatting.timeText(now))
                .scaledFont(52, weight: .bold)
                .monospacedDigit()
                .padding(.bottom, 10)
            notice
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
        }
        .foregroundStyle(Theme.Colors.brightText)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .background {
            // The model's radial-gradient(120% 90% at 50% 0%): an ellipse from the top center, 1,2 times
            // as wide and 0,9 times as tall as the picture, lighter at the top.
            GeometryReader { proxy in
                let size = proxy.size
                let radius = max(size.height * 0.9, 1)
                RadialGradient(
                    stops: [
                        .init(color: Theme.Colors.lockScreenTop, location: 0),
                        .init(color: Theme.Colors.lockScreenMiddle, location: 0.55),
                        .init(color: Theme.Colors.screenBackground, location: 1),
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: radius
                )
                .scaleEffect(x: max(size.width * 1.2 / radius, 1), y: 1, anchor: .top)
            }
            .background(Theme.Colors.screenBackground)
            .clipShape(shape)
        }
        .accessibilityHidden(true)
    }

    private var notice: some View {
        HStack(alignment: .top, spacing: 10) {
            AppIcon(.logo, size: 19)
                .foregroundStyle(.white)
                .frame(width: iconSide, height: iconSide)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: RestAlertText.title)
                        .scaledFont(13, weight: .bold)
                    Spacer(minLength: 0)
                    Text("agora")
                        .scaledFont(12)
                        .foregroundStyle(Theme.Colors.noticeSecondaryText)
                }
                if let nextSet {
                    Text(verbatim: nextSet)
                        .scaledFont(13, lineHeight: 1.3)
                        .foregroundStyle(Theme.Colors.noticeText)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Theme.Colors.noticeBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
