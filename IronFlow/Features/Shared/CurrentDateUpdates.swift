import Combine
import SwiftUI

/// Keeps `date` at the present moment while a screen is open: when the day changes with the app
/// open (midnight), when the time or the time zone changes (also while the app was in the
/// background), and when the app comes back to the foreground.
private struct CurrentDateUpdates: ViewModifier {
    @Binding var date: Date
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
                date = .now
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                date = .now
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    date = .now
                }
            }
    }
}

extension View {
    /// Sets `date` to the present moment when the day, the time or the time zone changes, and when
    /// the app comes back to the foreground.
    func updatingCurrentDate(_ date: Binding<Date>) -> some View {
        modifier(CurrentDateUpdates(date: date))
    }
}
