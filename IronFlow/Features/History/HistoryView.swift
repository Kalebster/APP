import SwiftData
import SwiftUI

/// The Histórico tab: finished sessions, the most recent first. Read-only.
struct HistoryView: View {
    @Query(
        filter: #Predicate<Session> { $0.endedAt != nil },
        sort: [SortDescriptor(\Session.startedAt, order: .reverse), SortDescriptor(\Session.createdAt, order: .reverse)]
    )
    private var sessions: [Session]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Metrics.cardSpacing) {
                ForEach(sessions) { session in
                    HistorySessionCard(session: session)
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "Nenhum treino realizado",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Seus treinos concluídos aparecerão aqui.")
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("history.empty")
            }
        }
        .screenBackground()
    }
}

/// A finished session: name, date and time, and duration with what was completed.
private struct HistorySessionCard: View {
    let session: Session

    var body: some View {
        let completedPerExercise = session.exercises.map { performed in
            performed.setLogs.filter(\.isCompleted).count
        }
        VStack(alignment: .leading, spacing: 4) {
            Text(SessionFormatting.name(session.workoutNameSnapshot))
                .font(.headline)
                .lineLimit(2)
            Text(SessionFormatting.dateText(session.startedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(SessionFormatting.summaryText(
                duration: session.duration,
                exercises: completedPerExercise.filter { $0 > 0 }.count,
                sets: completedPerExercise.reduce(0, +)
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.session")
    }
}
