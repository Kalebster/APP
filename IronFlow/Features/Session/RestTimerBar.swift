import SwiftUI

/// The floating rest bar, above the bottom of the session screen while a rest runs: a ring with the
/// time left, "−15", "+15" and "Pular". Its clock ticks once a second only while the bar is on screen
/// and the rest runs. When the rest reaches zero it shows "PRÓXIMA SÉRIE" and "Pronto" for a moment
/// (`isReady`), with the ring empty and the same buttons. Ending the rest when it reaches zero is the
/// root's job (`RestController`), so it happens on time even when the bar is hidden. Like the session header, the screen keeps it from growing past the first
/// accessibility text size; a long press on a button shows it larger (Large Content Viewer).
struct RestTimerBar: View {
    let timer: RestTimer
    /// The rest just reached zero: "Próxima série", "Pronto".
    var isReady = false
    let onAdd: @MainActor (TimeInterval) -> Void
    let onSkip: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var ringSide: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var buttonMinWidth: CGFloat = 40

    var body: some View {
        // Ticks on the seconds of the end, so the time shown changes right on each second.
        Group {
            if isReady {
                bar(at: .now)
            } else {
                let ticks = (timer.endsAt ?? .now).addingTimeInterval(-86_400)
                TimelineView(.periodic(from: ticks, by: 1)) { context in
                    bar(at: context.date)
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        // 20 above the bottom of the safe area, as in the model.
        .padding(.bottom, 20)
        .padding(.top, 4)
    }

    private func bar(at now: Date) -> some View {
        let remaining = isReady ? 0 : timer.remaining(at: now)
        let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                clock(remaining: remaining, at: now)
                Spacer(minLength: 0)
                buttons
            }
            // With the largest text sizes, the buttons go below the time; the bar keeps the full width.
            VStack(alignment: .leading, spacing: 8) {
                clock(remaining: remaining, at: now)
                buttons
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 7))
        .background(Theme.Colors.restBarBackground, in: shape)
        .overlay(shape.strokeBorder(Theme.Colors.controlBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    private func clock(remaining: TimeInterval, at now: Date) -> some View {
        // As in the model's ring, drawn on 40 × 40: a line 4 wide on a circle of radius 16.
        let lineWidth = ringSide * 4 / 40
        return HStack(spacing: 8) {
            ZStack {
                let fractionLeft = isReady ? 0 : timer.fractionLeft(at: now)
                Circle()
                    .stroke(Theme.Colors.cardBorder, lineWidth: lineWidth)
                // Nothing at 0: a line cut to no length still draws a dot with its round ends.
                if fractionLeft > 0 {
                    Circle()
                        .trim(from: 0, to: fractionLeft)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .padding(ringSide * 4 / 40)
            .frame(width: ringSide, height: ringSide)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                (isReady ? Text("Próxima série") : Text("Descanso"))
                    .scaledFont(8, weight: .bold)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Text(verbatim: isReady ? String(localized: "Pronto") : SessionFormatting.restText(remaining))
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
        HStack(spacing: 8) {
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
                    .padding(.horizontal, 9)
                    .frame(minWidth: buttonMinWidth, minHeight: buttonHeight)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.vertical, touchExtra)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -touchExtra)
            .accessibilityShowsLargeContentViewer()
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
                .padding(.horizontal, 9)
                .frame(minWidth: buttonMinWidth, minHeight: buttonHeight)
                .background(Theme.Colors.cardBorder, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.vertical, touchExtra)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -touchExtra)
        .accessibilityShowsLargeContentViewer()
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
