import SwiftData
import SwiftUI

/// The Início tab: the app header, today's workout (the workout planned for today, continue, choose a
/// workout or start a free one), the current week and the quick summary of the user's body data.
struct HomeView: View {
    /// Starts and opens sessions; `RootView` owns the session screen.
    let sessionActions: SessionActions

    @Query(SessionService.activeSessionsDescriptor) private var activeSessions: [Session]
    /// The workouts: whether any exists, and which days of the weekly plan have one that exists. A
    /// person has a handful, so all of them are read.
    @Query private var workouts: [Workout]
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
    @State private var editingMetric: BodyMetric?
    /// The notice of the last save ("Peso salvo").
    @State private var toast: ToastMessage?
    @State private var isCustomizing = false
    @State private var isChoosingWorkout = false
    /// Workout chosen in the sheet, started once the sheet is dismissed.
    @State private var chosenWorkout: Workout?
    @State private var isShowingPlan = false
    @ScaledMetric(relativeTo: .headline) private var logoSide: CGFloat = 34

    var body: some View {
        let metrics = HomeSummary.metrics(fromStored: storedMetrics)
        let calendar = TrainingDay.calendar
        let week = WeekSummary.week(containing: now, calendar: calendar)
        let scheduledID = WeeklyPlanSummary.scheduledWorkoutID(
            plan: weeklyPlan,
            weekday: TrainingDay.planWeekday(of: now, calendar: calendar)
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(calendar: calendar)

                // A new day or a new planned workout is a new section, so its queries are built
                // again; a change of the plan reaches it at once, through `weeklyPlan`.
                TodayWorkoutSection(
                    scheduledID: scheduledID,
                    now: now,
                    calendar: calendar,
                    activeSessions: activeSessions,
                    hasWorkouts: !workouts.isEmpty,
                    sessionActions: sessionActions,
                    onChoose: chooseWorkout
                )
                .id("\(TrainingDay.key(for: now, calendar: calendar))/\(scheduledID?.uuidString ?? "-")")

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Sua semana")
                    // A new week is a new card, so its queries are built again for the new limits.
                    WeekCard(
                        week: week,
                        now: now,
                        calendar: calendar,
                        plannedWeekdays: WeeklyPlanSummary.plannedWeekdays(plan: weeklyPlan, workouts: workouts),
                        hasWorkouts: !workouts.isEmpty
                    ) {
                        isShowingPlan = true
                    }
                    .id(week.start)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Resumo rápido", actionTitle: "Personalizar", actionIdentifier: "home.customize") {
                        isCustomizing = true
                    }
                    if metrics.isEmpty {
                        Text("Escolha até \(HomeSummary.maxVisibleMetrics) indicadores em Personalizar.")
                            .scaledFont(12)
                            .foregroundStyle(.secondary)
                    } else {
                        metricCards(metrics)
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 21)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .statusBarBackground()
        .screenBackground()
        .toast($toast)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingMetric) { metric in
            MetricEditorSheet(metric: metric, initialValue: value(of: metric), savesUnchangedValue: savesUnchangedValue(for: metric)) { value in
                try save(value, for: metric)
            } onSaved: {
                toast = ToastMessage(String(localized: metric.savedMessage))
            } onCalculatedGoal: { goal in
                toast = ToastMessage(BMRCalculatorSheet.goalSavedMessage(goal))
            }
        }
        .sheet(isPresented: $isCustomizing) {
            SummaryCustomizeSheet(storedMetrics: $storedMetrics)
        }
        .sheet(isPresented: $isChoosingWorkout, onDismiss: startChosenWorkout) {
            WorkoutPickerSheet(todayWorkoutID: scheduledID) { workout in
                chosenWorkout = workout
            }
        }
        .navigationDestination(isPresented: $isShowingPlan) {
            WeeklyPlanView()
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

    /// The app's mark and name, and today's date.
    private func header(calendar: Calendar) -> some View {
        let brand = HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: logoSide * 0.47, weight: .semibold))
                .rotationEffect(.degrees(45))
                .foregroundStyle(.white)
                .frame(width: logoSide, height: logoSide)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(verbatim: "IRON FLOW")
                .scaledFont(17, weight: .heavy)
                .tracking(0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Iron Flow"))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("home.header")

        let date = Text(verbatim: SessionFormatting.weekdayDateText(now, now: now, calendar: calendar))
            .scaledFont(12)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text(verbatim: SessionFormatting.longDateText(now, calendar: calendar)))
            .accessibilityIdentifier("home.date")

        // Side by side when they fit; with the largest text sizes the date goes below the name, so
        // no word is broken.
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                brand
                Spacer(minLength: 8)
                date
            }
            VStack(alignment: .leading, spacing: 8) {
                brand
                date
            }
        }
    }

    /// One row of cards; a column with the largest text sizes, so values are never cut.
    @ViewBuilder
    private func metricCards(_ metrics: [SummaryMetric]) -> some View {
        let cards = ForEach(metrics) { metric in
            Button {
                editingMetric = metric.bodyMetric
            } label: {
                SummaryMetricCard(metric: metric, value: value(of: metric.bodyMetric), valueText: valueText(of: metric.bodyMetric))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.metric.\(metric.rawValue)")
        }
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 9) { cards }
        } else {
            // Cards in a row share the height of the tallest one.
            HStack(alignment: .top, spacing: 9) { cards }
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func value(of metric: BodyMetric) -> Double? {
        switch metric {
        case .bodyWeight: latestWeight.first?.weightKg
        case .height: profiles.first?.heightCm.map { Double($0) }
        case .dailyCalorieGoal: profiles.first?.dailyCalorieGoalKcal.map { Double($0) }
        }
    }

    /// The same weight on a new day is a new measurement; an unchanged height or goal needs no write.
    private func savesUnchangedValue(for metric: BodyMetric) -> Bool {
        guard metric == .bodyWeight, let latest = latestWeight.first else { return false }
        return !TrainingDay.calendar.isDateInToday(latest.measuredAt)
    }

    /// The value with its unit, as VoiceOver reads it ("80 kg", "2.300 kcal").
    private func valueText(of metric: BodyMetric) -> String? {
        switch metric {
        case .bodyWeight: latestWeight.first.map { HomeSummary.weightText($0.weightKg) }
        case .height: profiles.first?.heightCm.map(HomeSummary.heightText)
        case .dailyCalorieGoal: profiles.first?.dailyCalorieGoalKcal.map(HomeSummary.calorieText)
        }
    }

    private func save(_ value: Double, for metric: BodyMetric) throws {
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
        let scheduled = scheduledWorkouts.first
        let state = TodayWorkoutState.resolve(
            activeSessions: activeSessions,
            hasWorkouts: hasWorkouts,
            scheduled: scheduled,
            finishedSessions: finishedToday,
            now: now,
            calendar: calendar
        )
        let content = TodayWorkoutContent(
            state: state,
            summary: scheduled.map { WorkoutListSummary.cardSummary(for: $0) } ?? "",
            muscleGroups: scheduled.map { WorkoutListSummary.muscleGroups(of: $0).map { String(localized: $0.displayName) } } ?? [],
            now: now,
            calendar: calendar
        )
        TodayWorkoutCard(state: state, content: content, onAction: perform)
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

/// The "Treino de hoje" block, the highlight of the Início: what is going on today and its actions
/// (continue the session in progress; start the workout planned for today; choose another workout or
/// start a free one). The main action is a white button; the others are outlined below it.
private struct TodayWorkoutCard: View {
    let state: TodayWorkoutState
    let content: TodayWorkoutContent
    let onAction: @MainActor (TodayWorkoutAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            // Side by side when they fit; with the largest text sizes the badge goes below the
            // label, so it is never cut.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 8) {
                    sectionLabel
                    Spacer(minLength: 8)
                    stateBadge
                }
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel
                    stateBadge
                }
            }

            // The text is one accessibility element; the buttons stay separate so they can be reached.
            VStack(alignment: .leading, spacing: 11) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: content.title)
                        .scaledFont(26, weight: .heavy)
                        .foregroundStyle(Theme.Colors.highlightText)
                    Text(verbatim: content.subtitle)
                        .scaledFont(13)
                        .foregroundStyle(Theme.Colors.highlightSecondaryText)
                }
                if !content.chips.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(content.chips, id: \.self) { chip in
                            Text(verbatim: chip)
                                .scaledFont(11)
                                .foregroundStyle(Theme.Colors.highlightText)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                                .overlay(Capsule().strokeBorder(Theme.Colors.highlightLine, lineWidth: 1))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: content.accessibilityText))
            .accessibilityIdentifier("home.today")

            if let main = state.mainAction {
                actionButton(main, isMain: true)
            }
            secondaryButtons
        }
        .highlightStyle(padding: EdgeInsets(top: 15, leading: 15, bottom: 14, trailing: 15), cornerRadius: 20)
    }

    private var sectionLabel: some View {
        Text("Treino de hoje")
            .scaledFont(10, weight: .bold)
            .tracking(1.7)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.highlightLabel)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var stateBadge: some View {
        if let badge = content.badge {
            // VoiceOver reads the state with the text below.
            CapsuleBadge(text: badge, weight: .semibold, tracking: 0, padding: EdgeInsets(top: 4, leading: 9, bottom: 4, trailing: 9))
                .accessibilityHidden(true)
        }
    }

    /// Side by side; stacked with the accessibility text sizes. Each keeps a 44-point touch area,
    /// which reaches past its outline without moving it.
    @ViewBuilder
    private var secondaryButtons: some View {
        let actions = state.secondaryActions
        if !actions.isEmpty {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: -2) {
                        ForEach(actions, id: \.self) { actionButton($0, isMain: false) }
                    }
                } else {
                    HStack(spacing: 8) {
                        ForEach(actions, id: \.self) { actionButton($0, isMain: false) }
                    }
                }
            }
            .padding(.vertical, -5)
        }
    }

    @ViewBuilder
    private func actionButton(_ action: TodayWorkoutAction, isMain: Bool) -> some View {
        let label = buttonLabel(of: action, isMain: isMain)
        let button = Button {
            onAction(action)
        } label: {
            HStack(spacing: 8) {
                if let icon = label.icon {
                    Image(systemName: icon)
                        .scaledFont(13, weight: .bold)
                        .accessibilityHidden(true)
                }
                Text(verbatim: label.title)
            }
        }
        .accessibilityLabel(Text(verbatim: label.accessibilityTitle))
        .accessibilityIdentifier(identifier(of: action))
        if isMain {
            button.buttonStyle(HighlightMainButtonStyle())
        } else {
            button.buttonStyle(HighlightOutlinedButtonStyle())
        }
    }

    /// What a button shows and what VoiceOver reads. The outlined buttons are short ("Escolher outro",
    /// "Treino livre"); VoiceOver reads what they do.
    private func buttonLabel(of action: TodayWorkoutAction, isMain: Bool) -> (title: String, accessibilityTitle: String, icon: String?) {
        switch action {
        case .continueSession:
            let title = String(localized: "Continuar")
            return (title, title, "play.fill")
        case .startScheduledWorkout:
            let title = String(localized: "Iniciar \(content.title)")
            return (title, title, "play.fill")
        case .chooseWorkout:
            if isMain {
                let title = String(localized: "Escolher treino")
                return (title, title, "play.fill")
            }
            return (String(localized: "Escolher outro"), String(localized: "Escolher outro treino"), nil)
        case .startFreeWorkout:
            let full = String(localized: "Iniciar treino livre")
            return isMain ? (full, full, "play.fill") : (String(localized: "Treino livre"), full, nil)
        }
    }

    private func identifier(of action: TodayWorkoutAction) -> String {
        switch action {
        case .continueSession: "home.continue"
        case .startScheduledWorkout: "home.startPlanned"
        case .chooseWorkout: "home.chooseWorkout"
        case .startFreeWorkout: "home.startFree"
        }
    }
}

/// The block's main action: a white button, full width, at least 42 points tall.
private struct HighlightMainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        return configuration.label
            .scaledFont(15, weight: .bold)
            .foregroundStyle(Theme.Colors.screenBackground)
            .multilineTextAlignment(.center)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(.white, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// A secondary action of the block: outlined, at least 34 points tall, with 5 more points above and
/// below that respond to touches, so the touch area is 44 points.
private struct HighlightOutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        return configuration.label
            .scaledFont(13, weight: .semibold)
            .foregroundStyle(Theme.Colors.highlightText)
            .multilineTextAlignment(.center)
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 34)
            .overlay(shape.strokeBorder(Theme.Colors.highlightLine, lineWidth: 1))
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A quick summary card: icon, value with its unit (or "Adicionar") and the short name. VoiceOver
/// reads the full name and the value with its unit.
private struct SummaryMetricCard: View {
    let metric: SummaryMetric
    let value: Double?
    /// The value with its unit ("80 kg"), for VoiceOver.
    let valueText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconTile(systemImage: metric.systemImage, side: 29, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 2) {
                if let value {
                    let parts = HomeSummary.cardValue(of: metric, value: value)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(verbatim: parts.number)
                            .scaledFont(19, weight: .heavy)
                        if let unit = parts.unit {
                            Text(verbatim: unit)
                                .scaledFont(12, weight: .semibold)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                } else {
                    Text("Adicionar")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(Theme.Colors.lightAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(metric.cardTitle)
                    .scaledFont(11)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .cardStyle(padding: EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10), cornerRadius: 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: metric.title)), \(valueText ?? String(localized: "Adicionar"))"))
    }
}
