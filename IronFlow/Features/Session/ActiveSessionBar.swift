import SwiftUI

/// Shown above the tab bar while a session is in progress (the Início offers "Continuar" instead), in
/// the highlight's dark blue: a blue dot that pulses, the session's name and, below it, "Descanso 1:23"
/// while a rest runs or "12:05 · 3 de 15 séries" otherwise, and "Abrir ˄". Tapping it opens the session
/// again. VoiceOver reads it as one button.
///
/// It takes plain values, not the session itself, so its clock never reads a session that was just
/// finished or discarded. Like the session's header, it stops growing at the first accessibility text
/// size, so it never takes the screen.
struct ActiveSessionBar: View {
    /// What the bar shows of the session in progress.
    struct Status: Equatable {
        let name: String
        let startedAt: Date
        /// "3 de 15 séries" (`SessionProgress.setsText`).
        let setsText: String
        /// When the session's rest ends; `nil` without one.
        let restEndsAt: Date?
    }

    let status: Status
    let onOpen: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var openHeight: CGFloat = 30

    var body: some View {
        TimelineView(.periodic(from: status.startedAt, by: 1)) { timeline in
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    PulsingDot(isAnimated: !reduceMotion)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: status.name)
                            .scaledFont(14, weight: .bold)
                            .foregroundStyle(Theme.Colors.highlightText)
                        Text(verbatim: Self.detailText(status, at: timeline.date))
                            .scaledFont(12)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.highlightSecondaryText)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Text("Abrir")
                        Image(systemName: "chevron.up")
                    }
                    .scaledFont(13, weight: .semibold)
                    .foregroundStyle(Theme.Colors.highlightText)
                    .padding(.horizontal, 12)
                    .frame(minHeight: openHeight)
                    .background(Theme.Colors.highlightBadge, in: Capsule())
                }
                .highlightStyle(padding: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 10), cornerRadius: 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: Self.accessibilityText(status, at: timeline.date)))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("session.bar")
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 8)
    }

    /// The rest still to go, or `nil`: none, or one already over (it ended while the session was
    /// minimized, and the session screen ends it when it opens again).
    private static func restLeft(_ status: Status, at now: Date) -> TimeInterval? {
        guard let endsAt = status.restEndsAt, endsAt > now else { return nil }
        return endsAt.timeIntervalSince(now)
    }

    /// "Descanso 1:23" while the rest runs; otherwise "12:05 · 3 de 15 séries".
    static func detailText(_ status: Status, at now: Date) -> String {
        if let left = restLeft(status, at: now) {
            return String(localized: "Descanso \(SessionFormatting.restText(left))")
        }
        return "\(SessionFormatting.elapsedText(from: status.startedAt, to: now)) · \(status.setsText)"
    }

    /// "Treino em andamento, Push, 12:05, 3 de 15 séries. Abrir"; while resting, "Treino em andamento,
    /// Push, Descanso 1:23. Abrir".
    static func accessibilityText(_ status: Status, at now: Date) -> String {
        var parts = [String(localized: "Treino em andamento"), status.name]
        if let left = restLeft(status, at: now) {
            parts.append(String(localized: "Descanso \(SessionFormatting.restText(left))"))
        } else {
            parts.append(SessionFormatting.elapsedText(from: status.startedAt, to: now))
            parts.append(status.setsText)
        }
        return String(localized: "\(parts.joined(separator: ", ")). Abrir")
    }
}

/// The blue dot of the bar: it pulses while the session is in progress, and stays still with Reduce
/// Motion. Decorative, so VoiceOver skips it.
private struct PulsingDot: View {
    let isAnimated: Bool

    @State private var isDimmed = false
    @ScaledMetric(relativeTo: .footnote) private var side: CGFloat = 8

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: side, height: side)
            .opacity(isAnimated && isDimmed ? 0.3 : 1)
            .animation(isAnimated ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : nil, value: isDimmed)
            .onAppear {
                isDimmed = true
            }
            .accessibilityHidden(true)
    }
}
