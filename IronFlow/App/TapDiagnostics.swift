#if DEBUG
import SwiftUI
import UIKit

/// TEMPORARY, for the investigation of the lost first tap on the filters of Exercícios: records, with the
/// time since launch, every touch that reaches the window (and the view it lands on), each filter's
/// action and each scroll phase of the list and of the rows of chips. Debug only, and only with
/// `-ui-testing` and `-ui-tap-diagnostics`. The events are read by the diagnostic interface test through
/// an invisible accessibility element. Removed before the stage's pull request.
@MainActor
@Observable
final class TapDiagnostics {
    static let shared = TapDiagnostics()

    static let isEnabled: Bool = {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-ui-testing") && arguments.contains("-ui-tap-diagnostics")
    }()

    private let start = Date.now
    private(set) var events: [String] = []

    func record(_ event: String) {
        guard Self.isEnabled else { return }
        events.append(String(format: "%.3f ", Date.now.timeIntervalSince(start)) + event)
    }
}

/// Installs the touch recorder on the window and shows the events to the interface test.
struct TapDiagnosticsOverlay: View {
    var body: some View {
        if TapDiagnostics.isEnabled {
            ZStack {
                TouchRecorderInstaller()
                Color.clear
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("diagnostics.events")
                    .accessibilityLabel(Text(verbatim: "diagnostics"))
                    .accessibilityValue(Text(verbatim: TapDiagnostics.shared.events.joined(separator: " | ")))
            }
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
        }
    }
}

private struct TouchRecorderInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView {
        InstallerView()
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, !(window.gestureRecognizers ?? []).contains(where: { $0 is TouchRecorder }) else { return }
            let recorder = TouchRecorder(target: nil, action: nil)
            recorder.cancelsTouchesInView = false
            recorder.delaysTouchesBegan = false
            recorder.delaysTouchesEnded = false
            recorder.delegate = recorder
            window.addGestureRecognizer(recorder)
        }
    }
}

/// Never recognizes and never delays or cancels a touch: it only writes down what arrives.
private final class TouchRecorder: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private func describe(_ touches: Set<UITouch>, _ phase: String) {
        for touch in touches {
            let point = touch.location(in: view)
            let target = touch.view.map { String(describing: type(of: $0)) } ?? "nil"
            TapDiagnostics.shared.record("touch \(phase) (\(Int(point.x)),\(Int(point.y))) on \(target)")
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        describe(touches, "began")
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        describe(touches, "ended")
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        describe(touches, "cancelled")
        state = .failed
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

extension View {
    /// Records the scroll phases of a scroll view under `name`, for the investigation.
    func tapDiagnosticsScrollPhases(_ name: String) -> some View {
        onScrollPhaseChange { old, new in
            TapDiagnostics.shared.record("scroll \(name) \(old) -> \(new)")
        }
    }
}
#endif
