import SwiftUI
import UIKit

/// Keeps the system's swipe from the left edge going back on a pushed screen that hides the navigation
/// bar and draws its own back button: UIKit turns that swipe off together with the bar. Put it in the
/// screen's background; it draws nothing.
struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    /// While its screen is on top, answers for the navigation controller's swipe back: it may begin
    /// whenever there is a screen to go back to. The previous answerer is restored when the screen goes.
    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        private weak var previousDelegate: (any UIGestureRecognizerDelegate)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            if recognizer.delegate !== self {
                previousDelegate = recognizer.delegate
            }
            recognizer.delegate = self
            recognizer.isEnabled = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let recognizer = navigationController?.interactivePopGestureRecognizer,
                  recognizer.delegate === self else { return }
            recognizer.delegate = previousDelegate
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}
