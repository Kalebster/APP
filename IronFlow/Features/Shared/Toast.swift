import SwiftUI

/// A short notice ("Peso salvo"). Each one is new, so the same text shown twice is shown again.
struct ToastMessage: Equatable {
    let id = UUID()
    let text: String

    init(_ text: String) {
        self.text = text
    }

    /// How long the notice stays on screen: 2,5 s, or 4 s for a text of more than 40 characters, which
    /// takes longer to read.
    var duration: Duration {
        text.count > 40 ? .seconds(4) : .seconds(2.5)
    }
}

extension View {
    /// Shows `message` at the top of the screen for a moment and then clears it. The notice draws over
    /// the top of the screen, away from the cards and rows that change below, never takes a touch, and
    /// VoiceOver reads it as an announcement.
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    Text(verbatim: message.text)
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(Theme.Colors.brightText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.setFieldBackground, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
                        .padding(.horizontal, Theme.Metrics.screenPadding)
                        .padding(.top, 8)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("toast")
                        .id(message.id)
                }
            }
            .task(id: message?.id) {
                guard let current = message else { return }
                AccessibilityNotification.Announcement(current.text).post()
                do {
                    try await Task.sleep(for: current.duration)
                } catch {
                    // A newer notice replaced it and is cleared by its own task.
                    return
                }
                withAnimation {
                    if message?.id == current.id {
                        message = nil
                    }
                }
            }
    }
}
