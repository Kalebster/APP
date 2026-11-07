import SwiftUI

/// A short notice ("Peso salvo"). Each one is new, so the same text shown twice is shown again.
struct ToastMessage: Equatable {
    let id = UUID()
    let text: String

    init(_ text: String) {
        self.text = text
    }

    /// How long the notice stays on screen (`ToastDuration`): 2,5 s, or 4 s for a text of more than 40
    /// characters, which takes longer to read.
    var duration: Duration {
        ToastDuration.current(for: text)
    }
}

extension View {
    /// Shows `message` at the top of the screen for a moment and then clears it. The notice draws over
    /// the top of the screen, away from the cards and rows that change below, never takes a touch, and
    /// VoiceOver reads it as an announcement. It sits `top` points below the top of the view (of its
    /// safe area): 14, as in the model, unless the screen keeps it closer to a header of its own.
    func toast(_ message: Binding<ToastMessage?>, top: CGFloat = 14) -> some View {
        modifier(ToastModifier(message: message, top: top))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?
    let top: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    Text(verbatim: message.text)
                        .scaledFont(13, weight: .semibold, lineHeight: 1.35)
                        .foregroundStyle(Theme.Colors.brightText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.setFieldBackground, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
                        .padding(.horizontal, Theme.Metrics.screenPadding)
                        .padding(.top, top)
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
