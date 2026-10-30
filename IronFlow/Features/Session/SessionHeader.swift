import SwiftUI

/// The top of the session screen, kept in place while the sets scroll: minimize, the workout's name
/// with its clock and the load lifted, the ⋯ menu (with "Descartar treino") and "Concluir"; then the
/// progress bar with the sets done and the current exercise.
///
/// Like the system's bars, the session screen keeps it from growing past the first accessibility text
/// size; a long press on a button shows it larger (Large Content Viewer).
struct SessionHeader: View {
    let name: String
    let startedAt: Date
    let volumeKg: Double
    let progress: SessionProgress
    let onMinimize: @MainActor () -> Void
    let onDiscard: @MainActor () -> Void
    let onFinish: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var buttonSide: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Side by side when they fit; with the largest text sizes the name goes below the buttons.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    minimizeButton
                    titles
                    Spacer(minLength: 4)
                    moreMenu
                    finishButton
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        minimizeButton
                        Spacer(minLength: 4)
                        moreMenu
                        finishButton
                    }
                    titles
                }
            }
            progressView
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(Theme.Colors.screenBackground, ignoresSafeAreaEdges: .top)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: name)
                .scaledFont(20, weight: .heavy)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("session.name")
            HStack(spacing: 8) {
                TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
                    Label {
                        Text(verbatim: SessionFormatting.elapsedText(from: startedAt, to: timeline.date))
                    } icon: {
                        Image(systemName: "stopwatch")
                    }
                    .labelStyle(TightLabelStyle())
                    .scaledFont(11, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                }
                .accessibilityIdentifier("session.elapsed")
                Text(verbatim: SessionFormatting.volumeText(volumeKg))
                    .scaledFont(10)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("session.volume")
            }
        }
    }

    private var progressView: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Theme.Colors.ringTrack)
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: proxy.size.width * progress.fraction)
                    }
                }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: progress.setsText)
                Spacer(minLength: 8)
                if let exerciseText = progress.exerciseText {
                    Text(verbatim: exerciseText)
                        .multilineTextAlignment(.trailing)
                }
            }
            .scaledFont(10)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: [progress.setsText, progress.exerciseText].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityIdentifier("session.progress")
    }

    /// A round 32-point button on the card fill with the card border; it answers on 44 points.
    private func roundButton(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .scaledFont(13, weight: .bold)
            .foregroundStyle(.primary)
            .frame(width: buttonSide, height: buttonSide)
            .background(Theme.Colors.cardBackground, in: Circle())
            .overlay(Circle().strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
            .frame(width: max(44, buttonSide), height: max(44, buttonSide))
            .contentShape(Rectangle())
    }

    /// What a 32-point control answers on around it, without taking that room in the layout.
    private var touchExtra: CGFloat {
        max(0, 44 - buttonSide) / 2
    }

    private var minimizeButton: some View {
        Button(action: onMinimize) {
            roundButton("chevron.down")
        }
        .buttonStyle(.plain)
        .padding(-touchExtra)
        .accessibilityShowsLargeContentViewer()
        .accessibilityLabel(Text("Minimizar"))
        .accessibilityIdentifier("session.minimize")
    }

    private var moreMenu: some View {
        Menu {
            Button("Descartar treino", systemImage: "trash", role: .destructive, action: onDiscard)
                .accessibilityIdentifier("session.discard")
        } label: {
            roundButton("ellipsis")
        }
        .padding(-touchExtra)
        .accessibilityShowsLargeContentViewer()
        .accessibilityLabel(Text("Mais opções do treino"))
        .accessibilityIdentifier("session.more")
    }

    private var finishButton: some View {
        Button(action: onFinish) {
            Text("Concluir")
                .scaledFont(12, weight: .bold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .frame(minHeight: buttonSide)
                .background(Color.accentColor, in: Capsule())
                .padding(.vertical, touchExtra)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -touchExtra)
        .fixedSize()
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier("session.finish")
    }
}
