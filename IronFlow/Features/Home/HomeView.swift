import SwiftData
import SwiftUI

/// The Início tab: the app header, today's workout (continue, choose a workout or start a free one)
/// and the quick summary of the user's body data.
struct HomeView: View {
    /// Starts and opens sessions; `RootView` owns the session screen.
    let sessionActions: SessionActions

    @Query(filter: #Predicate<Session> { $0.endedAt == nil }) private var activeSessions: [Session]
    @Query(HomeView.anyWorkout) private var anyWorkout: [Workout]
    @Query(ProfileService.latestWeightDescriptor) private var latestWeight: [BodyWeightEntry]
    @Query(ProfileService.profileDescriptor) private var profiles: [UserProfile]
    @AppStorage(HomeSummary.metricsPreferenceKey, store: AppPreferences.store) private var storedMetrics: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    HomeSectionTitle("Treino de hoje")
                    TodayWorkoutCard(
                        state: .resolve(activeSessions: activeSessions, hasWorkouts: !anyWorkout.isEmpty),
                        onAction: perform
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        HomeSectionTitle("Resumo rápido")
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
    }

    private func perform(_ action: TodayWorkoutAction) {
        switch action {
        case .continueSession: sessionActions.open()
        case .chooseWorkout: isChoosingWorkout = true
        case .startFreeWorkout: sessionActions.startFree()
        }
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

/// A Home section title: uppercase, heavy and widely spaced.
private struct HomeSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline.weight(.heavy))
            .tracking(3)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The "Treino de hoje" card: what is going on today, and its actions (continue the session in
/// progress, or choose a workout and start a free one).
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
                ForEach(state.actions, id: \.self) { action in
                    actionButton(action)
                }
            }
        }
        .padding(8)
        .cardStyle()
    }

    @ViewBuilder
    private func actionButton(_ action: TodayWorkoutAction) -> some View {
        switch action {
        case .continueSession:
            Button("Continuar") { onAction(action) }
                .buttonStyle(CardMainButtonStyle())
                .accessibilityIdentifier("home.continue")
        case .chooseWorkout:
            Button("Escolher um treino") { onAction(action) }
                .buttonStyle(CardMainButtonStyle())
                .accessibilityIdentifier("home.chooseWorkout")
        case .startFreeWorkout:
            Button("Iniciar treino livre") { onAction(action) }
                .buttonStyle(CardTextButtonStyle())
                .accessibilityIdentifier("home.startFree")
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
