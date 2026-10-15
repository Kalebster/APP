import SwiftData
import SwiftUI

/// The Histórico tab: finished sessions, the most recent first. Read-only; a session opens its
/// detail, built from the session's own records only.
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
                    NavigationLink(value: session) {
                        HistorySessionCard(session: session)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("history.session")
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
        .navigationDestination(for: Session.self) { session in
            HistorySessionDetailView(detail: HistorySessionDetail(session))
        }
    }
}

/// A finished session: name, date and time, duration with what was completed, and a disclosure chevron.
private struct HistorySessionCard: View {
    let session: Session

    var body: some View {
        let completedPerExercise = session.exercises.map { performed in
            performed.setLogs.filter(\.isCompleted).count
        }
        HStack(spacing: 12) {
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
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .cardStyle()
    }
}
