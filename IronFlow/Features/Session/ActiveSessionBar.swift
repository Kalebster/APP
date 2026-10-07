import SwiftUI

/// Shown above the tab bar while a session is in progress: its name and time, and tapping it
/// opens the session again.
///
/// It takes plain values, not the session itself, so its clock never reads a session that was
/// just finished or discarded.
struct ActiveSessionBar: View {
    let name: String
    let startedAt: Date
    let onOpen: @MainActor () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Treino em andamento")
                        .font(.caption.weight(.semibold))
                        .opacity(0.85)
                    TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
                        Text(verbatim: "\(name) · \(SessionFormatting.elapsedText(from: startedAt, to: timeline.date))")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text("Continuar")
                    .font(.subheadline.weight(.bold))
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("session.bar")
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 8)
    }
}
