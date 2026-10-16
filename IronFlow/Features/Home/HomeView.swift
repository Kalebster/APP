import SwiftData
import SwiftUI

/// The Início tab: the app header, today's workout (the workout planned for today, continue, choose a
/// workout or start a free one), the current week and the quick summary of the user's body data.
struct HomeView: View {
    /// Starts and opens sessions; `RootView` owns the session screen.
    let sessionActions: SessionActions

    @Query(SessionService.activeSessionsDescriptor) private var activeSessions: [Session]
    @Query(HomeView.anyWorkout) private var anyWorkout: [Workout]
    /// The weekly plan: at most seven records, so all of them are read.
    @Query private var weeklyPlan: [WeeklyPlanDay]
    @Query(ProfileService.latestWeightDescriptor) private var latestWeight: [BodyWeightEntry]
    @Query(ProfileService.profileDescriptor) private var profiles: [UserProfile]
    @AppStorage(HomeSummary.metricsPreferenceKey, store: AppPreferences.store) private var storedMetrics: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The moment the week and today's workout are shown for. Updated when the day changes with the
    /// app open, when the time or time zone changes, and when the app comes back to the foreground.
    @State private var now = Date.now
    @State private var editingMetric: SummaryMetric?
    @State private var isCustomizing = false
    @State private var isChoosingWorkout = false
    /// Workout chosen in the sheet, started once the sheet is dismissed.
    @State private var chosenWorkout: Workout?

    /// Only whether a workout exists matters here.
    nonisolated private static var anyWorkout: FetchDescriptor<Workout> {
        var descriptor = FetchDescriptor<Workout>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    var body: some View {
        let metrics = HomeSummary.metrics(fromStored: storedMetrics)
        let calendar = TrainingDay.calendar
        let week = WeekSummary.week(containing: now, calendar: calendar)
        let scheduledID = WeeklyPlanSummary.scheduledWorkoutID(
            plan: weeklyPlan,
            weekday: TrainingDay.planWeekday(of: now, calendar: calendar)
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle("Treino de hoje")
                    // A new day or a new planned workout is a new section, so its queries are built
                    // again; a change of the plan reaches it at once, through `weeklyPlan`.
                    TodayWorkoutSection(
                        scheduledID: scheduledID,
                        now: now,
                        calendar: calendar,
                        activeSessions: activeSessions,
                        hasWorkouts: !anyWorkout.isEmpty,
                        sessionActions: sessionActions,
                        onChoose: chooseWorkout
                    )
                    .id("\(TrainingDay.key(for: now, calendar: calendar))/\(scheduledID?.uuidString ?? "-")")
                }

                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle("Sua semana")
                    // A new week is a new card, so its queries are built again for the new limits.
                    WeekCard(week: week, now: now, calendar: calendar)
                        .id(week.start)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionTitle("Resumo rápido")
                        Spacer(minLength: 8)
                        Button("Personalizar") {
                            isCustomizing = true
                        }
                        .accessibilityIdentifier("home.customize")
                    }
                    if metrics.isEmpty {
                        Text("Escolha até \(HomeSummary.maxVisibleMetrics) indicadores em Personalizar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        metricCards(metrics)
                    }
                }
            }
            .padding(Theme.Metrics.screenPadding)
            .padding(.top, 8)
        }
        .statusBarBackground()
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingMetric) { metric in
            MetricEditorSheet(metric: metric, initialValue: value(of: metric), savesUnchangedValue: savesUnchangedValue(for: metric)) { value in
                try save(value, for: metric)
            }
        }
        .sheet(isPresented: $isCustomizing) {
            SummaryCustomizeSheet(storedMetrics: $storedMetrics)
        }
        .sheet(isPresented: $isChoosingWorkout, onDismiss: startChosenWorkout) {
            WorkoutPickerSheet { workout in
                chosenWorkout = workout
            }
        }
        .updatingCurrentDate($now)
    }

    private func chooseWorkout() {
        // A choice left from an earlier sheet is never started by this one.
        chosenWorkout = nil
        isChoosingWorkout = true
    }

    /// The session screen opens only once the sheet is gone, so two screens never present at once.
    private func startChosenWorkout() {
        guard let chosenWorkout else { return }
        self.chosenWorkout = nil
        sessionActions.start(chosenWorkout)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 20, weight: .semibold))
                .rotationEffect(.degrees(45))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(verbatim: "IRON FLOW")
                .font(.title2.weight(.heavy))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Iron Flow"))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("home.header")
    }

    /// One row of cards; a column with the largest text sizes, so values are never cut.
    @ViewBuilder
    private func metricCards(_ metrics: [SummaryMetric]) -> some View {
        let cards = ForEach(metrics) { metric in
            Button {
                editingMetric = metric
            } label: {
                SummaryMetricCard(metric: metric, valueText: valueText(of: metric))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.metric.\(metric.rawValue)")
        }
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Theme.Metrics.cardSpacing) { cards }
        } else {
            // Cards in a row share the height of the tallest one.
            HStack(alignment: .top, spacing: Theme.Metrics.cardSpacing) { cards }
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func value(of metric: SummaryMetric) -> Double? {
        switch metric {
        case .bodyWeight: latestWeight.first?.weightKg
        case .height: profiles.first?.heightCm.map { Double($0) }
        case .dailyCalorieGoal: profiles.first?.dailyCalorieGoalKcal.map { Double($0) }
        }
    }

    /// The same weight on a new day is a new measurement; an unchanged height or goal needs no write.
    private func savesUnchangedValue(for metric: SummaryMetric) -> Bool {
        guard metric == .bodyWeight, let latest = latestWeight.first else { return false }
        return !Calendar.current.isDateInToday(latest.measuredAt)
    }

    private func valueText(of metric: SummaryMetric) -> String? {
        switch metric {
        case .bodyWeight: latestWeight.first.map { HomeSummary.weightText($0.weightKg) }
        case .height: profiles.first?.heightCm.map(HomeSummary.heightText)
        case .dailyCalorieGoal: profiles.first?.dailyCalorieGoalKcal.map(HomeSummary.calorieText)
        }
    }

    private func save(_ value: Double, for metric: SummaryMetric) throws {
        let service = ProfileService(context: context)
        switch metric {
        case .bodyWeight: try service.recordWeight(value)
        case .height: try service.setHeight(Int(value))
        case .dailyCalorieGoal: try service.setDailyCalorieGoal(Int(value))
        }
    }
}

/// The "Treino de hoje" section: finds the workout planned for today and the sessions finished today,
/// works out what the card shows and carries out its actions.
///
/// The queries are built from the values it receives when it is created, so `HomeView` gives it an
/// identity made of the day and the planned workout: another day or another planned workout creates
/// a new section with new queries. A planned workout that no longer exists finds nothing, and the
/// day is a rest day.
private struct TodayWorkoutSection: View {
    let now: Date
    let calendar: Calendar
    let activeSessions: [Session]
    let hasWorkouts: Bool
    let sessionActions: SessionActions
    let onChoose: @MainActor () -> Void

    /// The workout planned for today: none when the day is a rest day or the workout was deleted.
    @Query private var scheduledWorkouts: [Workout]
    /// Finished sessions that started today.
    @Query private var finishedToday: [Session]

    /// Matches no workout, for a day without a planned workout.
    private static let noWorkoutID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    init(
        scheduledID: UUID?,
        now: Date,
        calendar: Calendar,
        activeSessions: [Session],
        hasWorkouts: Bool,
        sessionActions: SessionActions,
        onChoose: @escaping @MainActor () -> Void
    ) {
        self.now = now
        self.calendar = calendar
        self.activeSessions = activeSessions
        self.hasWorkouts = hasWorkouts
        self.sessionActions = sessionActions
        self.onChoose = onChoose
        let workoutID = scheduledID ?? Self.noWorkoutID
        _scheduledWorkouts = Query(filter: #Predicate<Workout> { workout in
            workout.id == workoutID
        })
        let day = TrainingDay.dayInterval(of: now, calendar: calendar)
        let start = day.start
        let end = day.end
        _finishedToday = Query(filter: #Predicate<Session> { session in
            session.endedAt != nil && session.startedAt >= start && session.startedAt < end
        })
    }

    var body: some View {
        let state = TodayWorkoutState.resolve(
            activeSessions: activeSessions,
            hasWorkouts: hasWorkouts,
            scheduled: scheduledWorkouts.first,
            finishedSessions: finishedToday,
            now: now,
            calendar: calendar
        )
        TodayWorkoutCard(state: state, onAction: perform)
    }

    private func perform(_ action: TodayWorkoutAction) {
        switch action {
        case .continueSession: sessionActions.open()
        case .startScheduledWorkout:
            if let workout = scheduledWorkouts.first {
                sessionActions.start(workout)
            }
        case .chooseWorkout: onChoose()
        case .startFreeWorkout: sessionActions.startFree()
        }
    }
}

/// The "Treino de hoje" card: what is going on today, and its actions (continue the session in
/// progress; start the workout planned for today; choose another workout or start a free one).
private struct TodayWorkoutCard: View {
    let state: TodayWorkoutState
    let onAction: @MainActor (TodayWorkoutAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // The text is one accessibility element; the buttons stay separate so they can be reached.
            VStack(alignment: .leading, spacing: 6) {
                switch state {
                case .inProgress(let name, let startedAt):
                    Text("Treino em andamento")
                        .font(.headline)
                    Text(name.isEmpty ? String(localized: "Treino livre") : name)
                    Text(HomeSummary.startedText(startedAt))
                        .foregroundStyle(.secondary)
                case .scheduled(_, let name):
                    Text(name)
                        .font(.headline)
                    Text("Programado para hoje")
                        .foregroundStyle(.secondary)
                case .scheduledCompleted(let name):
                    Text("\(name) concluído hoje")
                        .font(.headline)
                case .noWorkouts:
                    Text("Você ainda não tem treinos.")
                        .foregroundStyle(.secondary)
                case .nothingPlanned:
                    Text("Nenhum treino planejado para hoje.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home.today")

            VStack(spacing: 8) {
                // The first action is the main one (a gray button); the others are text.
                ForEach(Array(state.actions.enumerated()), id: \.element) { index, action in
                    actionButton(action, isMain: index == 0)
                }
            }
        }
        .padding(8)
        .cardStyle()
    }

    /// The name of the workout planned for today, when the card is about it.
    private var scheduledName: String {
        switch state {
        case .scheduled(_, let name), .scheduledCompleted(let name): name
        default: ""
        }
    }

    @ViewBuilder
    private func actionButton(_ action: TodayWorkoutAction, isMain: Bool) -> some View {
        // With a workout planned for today the choice is of another one.
        let chooseTitle: LocalizedStringKey = switch state {
        case .scheduled, .scheduledCompleted: "Escolher outro treino"
        default: "Escolher um treino"
        }
        let button = switch action {
        case .continueSession: Button("Continuar") { onAction(action) }
        case .startScheduledWorkout: Button("Iniciar \(scheduledName)") { onAction(action) }
        case .chooseWorkout: Button(chooseTitle) { onAction(action) }
        case .startFreeWorkout: Button("Iniciar treino livre") { onAction(action) }
        }
        let identifier = switch action {
        case .continueSession: "home.continue"
        case .startScheduledWorkout: "home.startPlanned"
        case .chooseWorkout: "home.chooseWorkout"
        case .startFreeWorkout: "home.startFree"
        }
        if isMain {
            button
                .buttonStyle(CardMainButtonStyle())
                .accessibilityIdentifier(identifier)
        } else {
            button
                .buttonStyle(CardTextButtonStyle())
                .accessibilityIdentifier(identifier)
        }
    }
}

/// The card's main action: full width, on a gray fill.
private struct CardMainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(.fill.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A secondary action of the card: centered gray text.
private struct CardTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A quick summary card: icon, value (or "—" with "Adicionar") and title.
private struct SummaryMetricCard: View {
    let metric: SummaryMetric
    let valueText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Image(systemName: metric.systemImage)
                    .font(.title3)
                    .frame(height: 28)
                    .foregroundStyle(metric == .dailyCalorieGoal ? Color.accentColor : Color.secondary)
                Spacer(minLength: 4)
                if valueText == nil {
                    Text("Adicionar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(valueText ?? "—")
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(metric.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: metric.title)), \(valueText ?? String(localized: "Adicionar"))"))
    }
}
