import SwiftData
import SwiftUI

/// The Treinos tab: the header with "Criar treino", the weekly plan row, the grid of planned workouts
/// ("Meus treinos", today's workout highlighted), the free workout and the latest finished sessions
/// ("Treinos recentes"). Creating a workout opens its editor; ▶ starts a session from a workout.
struct WorkoutListView: View {
    /// Starts a session from a workout (▶) or a free one ("Treino livre").
    let sessionActions: SessionActions
    /// Opens the Histórico tab ("Ver tudo").
    let onShowHistory: @MainActor () -> Void

    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    /// The weekly plan: at most seven records, so all of them are read.
    @Query private var weeklyPlan: [WeeklyPlanDay]
    /// The latest finished sessions: the query itself is limited to `SessionService.recentSessionsLimit`.
    @Query(SessionService.recentSessionsDescriptor) private var recentSessions: [Session]
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The moment today's workout is found for; follows the day, as the Início does.
    @State private var now = Date.now
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
        let todayID = WeeklyPlanSummary.scheduledWorkoutID(
            plan: weeklyPlan,
            weekday: TrainingDay.planWeekday(of: now, calendar: TrainingDay.calendar)
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                // Without workouts there is nothing to plan.
                if !workouts.isEmpty {
                    planRow
                }
                myWorkouts(todayID: todayID)
                freeWorkout
                // Without finished sessions the section is not shown.
                if !recentSessions.isEmpty {
                    recent
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 21)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .statusBarBackground()
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
        .updatingCurrentDate($now)
    }

    // MARK: - Sections

    /// The title, how many workouts are in the plan, and the button that creates one.
    private var header: some View {
        let titles = VStack(alignment: .leading, spacing: 2) {
            Text("Treinos")
                .scaledFont(29, weight: .heavy)
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            Text(WorkoutListSummary.planSubtitle(workouts.count))
                .scaledFont(13)
                .foregroundStyle(.secondary)
        }
        let createButton = Button {
            isCreating = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .scaledFont(13, weight: .bold)
                    .accessibilityHidden(true)
                Text("Criar treino")
                    .scaledFont(13, weight: .bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(Color.accentColor, in: Capsule())
            // 3 more points above and below respond to touches, for a 44-point touch area.
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workouts.add")

        // Side by side when they fit, the button aligned with the bottom of the titles; with the
        // largest text sizes the button goes below the title.
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 12) {
                titles
                Spacer(minLength: 8)
                createButton
                    .padding(.bottom, -3)
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
                plannedWeekdays: WeeklyPlanSummary.plannedWeekdays(plan: weeklyPlan, workouts: workouts)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workouts.plan")
    }

    /// The grid; the workout planned for today (`todayID`) is highlighted.
    private func myWorkouts(todayID: UUID?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Meus treinos")
            if workouts.isEmpty {
                EmptyWorkoutsCard {
                    isCreating = true
                }
            } else {
                // Rows of cards; the cards of a row share its height. A person has a handful of
                // workouts, so the grid is not lazy.
                Grid(alignment: .topLeading, horizontalSpacing: 9, verticalSpacing: 9) {
                    ForEach(Array(stride(from: 0, to: workouts.count, by: columnCount)), id: \.self) { start in
                        GridRow {
                            ForEach(workouts[start..<min(start + columnCount, workouts.count)]) { workout in
                                card(for: workout, isToday: workout.id == todayID)
                            }
                            // The last row of an odd number of workouts keeps its card in the first column.
                            if workouts.count - start < columnCount {
                                Color.clear
                                    .gridCellUnsizedAxes([.horizontal, .vertical])
                            }
                        }
                    }
                }
            }
        }
    }

    private var freeWorkout: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Treino livre")
            FreeWorkoutCard {
                sessionActions.startFree()
            }
        }
    }

    /// The latest finished sessions in one card, a line between them; "Ver tudo" opens the Histórico.
    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Treinos recentes", actionTitle: "Ver tudo", actionIdentifier: "workouts.recent.all") {
                onShowHistory()
            }
            VStack(spacing: 0) {
                ForEach(Array(recentSessions.enumerated()), id: \.element.id) { index, session in
                    if index > 0 {
                        Theme.Colors.rowSeparator
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                    NavigationLink(value: session) {
                        RecentSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workouts.recent")
                }
            }
            .cardStyle(padding: EdgeInsets(), cornerRadius: 17)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
    }

    private func card(for workout: Workout, isToday: Bool) -> some View {
        WorkoutGridCard(workout: workout, isToday: isToday) {
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

    /// Two columns; one with the accessibility text sizes, so names and counts are never cut.
    private var columnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : 2
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

/// The weekly plan row: its icon, its name, the seven days with the planned ones in blue, how many
/// days are planned and a disclosure chevron.
private struct WeeklyPlanRow: View {
    let plannedWeekdays: Set<Int>

    var body: some View {
        // Side by side when it fits. With large text it does not: the icon and the chevron go on top,
        // and the name, the days and the count below them, with the whole width.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 6) {
                    title
                    days
                }
                // The name gets its width first, so it is not wrapped while the row has room.
                .layoutPriority(1)
                Spacer(minLength: 8)
                dayCount
                chevron
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    icon
                    Spacer(minLength: 8)
                    chevron
                }
                title
                days
                dayCount
            }
        }
        .cardStyle(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 14), cornerRadius: 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: "Programação semanal")), \(WeeklyPlanSummary.summaryText(plannedWeekdays.count))"))
    }

    private var icon: some View {
        IconTile(systemImage: "calendar", side: 36, cornerRadius: 10)
    }

    private var title: some View {
        Text("Programação semanal")
            .scaledFont(14, weight: .bold)
    }

    private var days: some View {
        WeekdayTiles(plannedWeekdays: plannedWeekdays)
            // Seven tiles in a row never fit the largest text sizes.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var dayCount: some View {
        Text(WeeklyPlanSummary.dayCountText(plannedWeekdays.count))
            .scaledFont(11)
            .foregroundStyle(.secondary)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .scaledFont(12, weight: .semibold)
            .foregroundStyle(.tertiary)
    }
}

/// The seven days of the weekly plan row, Monday to Sunday, with the planned ones in blue. A view of
/// its own, so the size of its tiles follows the text size limit set on it, like its letters.
private struct WeekdayTiles: View {
    let plannedWeekdays: Set<Int>

    /// The letters of the days, Monday to Sunday.
    private static let letters = ["S", "T", "Q", "Q", "S", "S", "D"]

    @ScaledMetric(relativeTo: .caption2) private var side: CGFloat = 19

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(Self.letters.enumerated()), id: \.offset) { index, letter in
                let isPlanned = plannedWeekdays.contains(index + 1)
                Text(verbatim: letter)
                    .scaledFont(10, weight: .bold)
                    .foregroundStyle(isPlanned ? Theme.Colors.plannedDayLetter : Theme.Colors.dimText)
                    .frame(width: side, height: side)
                    .background(
                        isPlanned ? Theme.Colors.plannedDayBackground : Theme.Colors.unplannedDayBackground,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
            }
        }
    }
}
