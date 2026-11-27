#if DEBUG
import Foundation
import SwiftData

/// A test hook: in a Debug build launched with `-ui-testing` and `-ui-delete-tapped-session`, tapping a
/// session in the history of the exercise screen first deletes that session from the test's store, as a
/// session deleted elsewhere would be, so the test reaches "Esse treino não está mais no histórico." by
/// the app's own path. The app cannot delete a finished session yet (it comes with the full Histórico).
@MainActor
enum UITestDeletedSession {
    static func deleteIfAsked(id: UUID, in context: ModelContext, arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains("-ui-testing"), arguments.contains("-ui-delete-tapped-session") else { return }
        do {
            var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            guard let session = try context.fetch(descriptor).first else { return }
            context.delete(session)
            try context.save()
        } catch {
            assertionFailure("The test hook could not delete the session: \(error)")
        }
    }
}
#endif
