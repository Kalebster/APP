import SwiftData
import SwiftUI

/// The Treinos tab: the header with "Criar treino", the weekly plan row, the grid of planned workouts
/// ("Meus treinos"), the free workout and the latest finished sessions ("Treinos recentes").
/// Creating a workout opens its editor; ▶ starts a session from a workout.
struct WorkoutListView: View {
    /// Starts a session from a workout (▶) or a free one ("Treino livre").
    let sessionActions: SessionActions

    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    /// The weekly plan: at most seven records, so all of them are read.
    @Query private var weeklyPlan: [WeeklyPlanDay]
    /// The latest finished sessions: the query itself is limited to `SessionService.recentSessionsLimit`.
    @Query(SessionService.recentSessionsDescriptor) private var recentSessions: [Session]
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShowingPlan = false
    @State private var isCreating = false
    /// Workout created in the name sheet, opened once the sheet is dismissed.
    @State private var createdWorkout: Workout?
    @State private var openedWorkout: Workout?
    @State private var renamingWorkout: Workout?
    @State private var pendingDeletion: PendingDeletion?
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    /// The workout the user asked to delete, with its name taken when the question was asked, so the
    /// confirmation never reads the workout itself.
    private struct PendingDeletion {
        let workout: Workout
        let name: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    // Without workouts there is nothing to plan.
                    if !workouts.isEmpty {
                        planRow
                    }
                }
                myWorkouts
                freeWorkout
                // Without finished sessions the section is not shown.
                if !recentSessions.isEmpty {
                    recent
                }
            }
            .padding(Theme.Metrics.screenPadding)
            .padding(.top, 8)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isCreating, onDismiss: openCreatedWorkout) {
            WorkoutNameSheet(title: "Novo treino") { name in
                createdWorkout = try WorkoutService(context: context).createWorkout(name: name)
            }
        }
        .sheet(item: $renamingWorkout) { workout in
            WorkoutNameSheet(title: "Renomear treino", initialName: workout.name) { name in
                try WorkoutService(context: context).rename(workout, to: name)
            }
        }
        .confirmationDialog(
            Text("Excluir “\(pendingDeletion?.name ?? "")”?"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive, action: deletePendingWorkout)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O histórico de treinos realizados será mantido.")
        }
        .navigationDestination(item: $openedWorkout) { workout in
            WorkoutEditorView(workout: workout)
        }
        .navigationDestination(isPresented: $isShowingPlan) {
            WeeklyPlanView()
        }
        .navigationDestination(for: Session.self) { session in
            HistorySessionDetailView(detail: HistorySessionDetail(session))
        }
        .errorAlert($errorMessage)
    }

    // MARK: - Sections

    /// The title, how many workouts are in the plan, and the button that creates one.
    private var header: some View {
        let titles = VStack(alignment: .leading, spacing: 4) {
            Text("Treinos")
                .font(.largeTitle.weight(.heavy))
                .accessibilityAddTraits(.isHeader)
            Text(WorkoutListSummary.planSubtitle(workouts.count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        let createButton = Button {
            isCreating = true
        } label: {
            Label("Criar treino", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("workouts.add")

        // Side by side when they fit; with the largest text sizes the button goes below the title.
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                titles
                Spacer(minLength: 8)
                createButton
            }
            VStack(alignment: .leading, spacing: 12) {
                titles
                createButton
            }
        }
    }

    private var planRow: some View {
        Button {
            isShowingPlan = true
        } label: {
            WeeklyPlanRow(
                summary: WeeklyPlanSummary.summaryText(
                    WeeklyPlanSummary.plannedDayCount(plan: weeklyPlan, workouts: workouts)
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workouts.plan")
    }

    private var myWorkouts: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Meus treinos")
            if workouts.isEmpty {
                EmptyWorkoutsCard {
                    isCreating = true
                }
            } else {
                LazyVGrid(columns: columns, spacing: Theme.Metrics.cardSpacing) {
                    ForEach(workouts) { workout in
                        WorkoutGridCard(workout: workout) {
                            openedWorkout = workout
                        } onStart: {
                            sessionActions.start(workout)
                        } onRename: {
                            renamingWorkout = workout
                        } onDelete: {
                            pendingDeletion = PendingDeletion(workout: workout, name: workout.name)
                            isConfirmingDelete = true
                        }
                    }
                }
            }
        }
    }

    private var freeWorkout: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Treino livre")
            FreeWorkoutCard {
                sessionActions.startFree()
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Treinos recentes")
            VStack(spacing: Theme.Metrics.cardSpacing) {
                ForEach(recentSessions) { session in
                    NavigationLink(value: session) {
                        RecentSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workouts.recent")
                }
            }
        }
    }

    /// Two columns; one with the accessibility text sizes, so names and counts are never cut.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Theme.Metrics.cardSpacing, alignment: .top),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    // MARK: - Actions

    private func openCreatedWorkout() {
        guard let createdWorkout else { return }
        self.createdWorkout = nil
        openedWorkout = createdWorkout
    }

    /// Deletes the workout the user confirmed; the history of performed workouts is kept.
    private func deletePendingWorkout() {
        guard let workout = pendingDeletion?.workout else { return }
        // Cleared first, so nothing reads the workout once it is deleted.
        pendingDeletion = nil
        do {
            try WorkoutService(context: context).delete(workout)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// The weekly plan row: its name, how many days are planned and a disclosure chevron.
private struct WeeklyPlanRow: View {
    let summary: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Programação semanal")
                    .font(.headline)
                Text(summary)
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
        .accessibilityElement(children: .combine)
    }
}
