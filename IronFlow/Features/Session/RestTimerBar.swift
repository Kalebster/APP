import SwiftUI

/// The floating rest bar, above the bottom of the session screen while a rest runs: a ring with the
/// time left, "−15", "+15" and "Pular". Its clock ticks once a second only while the bar is on screen.
/// Ending the rest when it reaches zero is the session screen's job, so it happens on time even when
/// the bar is hidden.
struct RestTimerBar: View {
    let timer: RestTimer
    let onAdd: @MainActor (TimeInterval) -> Void
    let onSkip: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var ringSide: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var buttonMinWidth: CGFloat = 40

    var body: some View {
        // Ticks on the seconds of the end, so the time shown changes right on each second.
        let ticks = (timer.endsAt ?? .now).addingTimeInterval(-86_400)
        TimelineView(.periodic(from: ticks, by: 1)) { context in
            bar(at: context.date)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 8)
        .padding(.top, 4)
    }

    private func bar(at now: Date) -> some View {
        let remaining = timer.remaining(at: now)
        let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                clock(remaining: remaining, at: now)
                Spacer(minLength: 6)
                buttons
            }
            // With the largest text sizes, the buttons go below the time.
            VStack(alignment: .leading, spacing: 8) {
                clock(remaining: remaining, at: now)
                buttons
            }
        }
        .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 7))
        .background(Theme.Colors.restBarBackground, in: shape)
        .overlay(shape.strokeBorder(Theme.Colors.controlBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    private func clock(remaining: TimeInterval, at now: Date) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.cardBorder, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: timer.fractionLeft(at: now))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(2)
            .frame(width: ringSide, height: ringSide)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Descanso")
                    .scaledFont(8, weight: .bold)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(verbatim: SessionFormatting.restText(remaining))
                    .scaledFont(16, weight: .heavy)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("session.rest.time")
        }
    }

    /// What each button answers on above and below its 30 points, for a 44-point touch area that takes
    /// no more room in the bar.
    private var touchExtra: CGFloat {
        max(0, 44 - buttonHeight) / 2
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            stepButton("−15", label: Text("Menos 15 segundos"), identifier: "session.rest.minus") {
                onAdd(-RestTimer.step)
            }
            stepButton("+15", label: Text("Mais 15 segundos"), identifier: "session.rest.plus") {
                onAdd(RestTimer.step)
            }
            Button(action: onSkip) {
                Text("Pular")
                    .scaledFont(11, weight: .bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(minWidth: buttonMinWidth, minHeight: buttonHeight)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.vertical, touchExtra)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -touchExtra)
            .accessibilityLabel(Text("Pular descanso"))
            .accessibilityIdentifier("session.rest.skip")
        }
    }

    private func stepButton(
        _ title: String,
        label: Text,
        identifier: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .scaledFont(11, weight: .bold)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.mediumText)
                .padding(.horizontal, 8)
                .frame(minWidth: buttonMinWidth, minHeight: buttonHeight)
                .background(Theme.Colors.cardBorder, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.vertical, touchExtra)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -touchExtra)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
