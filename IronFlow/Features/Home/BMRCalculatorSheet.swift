import SwiftData
import SwiftUI

/// "Calcular TMB": the basal metabolic rate by the Mifflin-St Jeor formula (`BMRCalculator`), from the
/// latest body weight, the height and the choices made here: sex, date of birth, activity level and
/// goal. Each choice is saved in the profile at once and the result follows it. "Usar … kcal como meta"
/// saves the suggested goal and calls `onUseGoal`; "Fechar" only closes the sheet.
struct BMRCalculatorSheet: View {
    /// Called once the suggested goal is saved, with it. The sheet closes itself.
    let onUseGoal: @MainActor (Int) -> Void

    @Query(ProfileService.latestWeightDescriptor) private var latestWeight: [BodyWeightEntry]
    @Query(ProfileService.profileDescriptor) private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The error of the last save; the choice shown is still the saved one.
    @State private var errorMessage: String?
    /// Set when the goal is used, so a second tap while the sheet closes saves nothing.
    @State private var isGoalUsed = false

    @ScaledMetric(relativeTo: .subheadline) private var segmentHeight: CGFloat = 38
    @ScaledMetric(relativeTo: .callout) private var menuHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .callout) private var dayMenuWidth: CGFloat = 72
    @ScaledMetric(relativeTo: .callout) private var yearMenuWidth: CGFloat = 98

    var body: some View {
        let calendar = TrainingDay.calendar
        let now = Date.now
        let inputs = BMRCalculator.inputs(profile: profiles.first, weightKg: latestWeight.first?.weightKg)
        let estimate = BMRCalculator.estimate(inputs, now: now, calendar: calendar)

        FittedSheet {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(
                    Text("Calcular TMB"),
                    explanation: Text(verbatim: Self.introduction(weightKg: inputs.weightKg, heightCm: inputs.heightCm)),
                    explanationIdentifier: "bmr.intro"
                )

                section("Sexo") {
                    segments(BiologicalSex.allCases, selected: inputs.sex, name: \.displayName, identifier: { "bmr.sex.\($0.rawValue)" }) { sex in
                        save { try $0.setSex(sex) }
                    }
                }
                section("Data de nascimento") {
                    birthDateMenus(inputs.birthDate, now: now, calendar: calendar)
                }
                section("Nível de atividade") {
                    activityLevels(selected: inputs.activityLevel)
                }
                section("Objetivo") {
                    segments(WeightGoal.allCases, selected: inputs.weightGoal, name: \.displayName, identifier: { "bmr.goal.\($0.rawValue)" }) { goal in
                        save { try $0.setWeightGoal(goal) }
                    }
                }
                section("Resultado") {
                    result(estimate, goal: inputs.weightGoal)
                }
                closing
            }
            .sheetContentPadding()
        }
    }

    /// What the BMR is and which data it uses: "… Usamos o seu peso (80 kg) e a sua altura (180 cm).";
    /// without one of them, the sentence has no numbers.
    static func introduction(weightKg: Double?, heightCm: Int?) -> String {
        guard let weightKg, let heightCm else {
            return String(localized: "A taxa metabólica basal é o quanto o seu corpo gasta parado. Usamos o seu peso e a sua altura.")
        }
        let weight = HomeSummary.weightText(weightKg)
        let height = HomeSummary.heightText(heightCm)
        return String(localized: "A taxa metabólica basal é o quanto o seu corpo gasta parado. Usamos o seu peso (\(weight)) e a sua altura (\(height)).")
    }

    /// The notice once a suggested goal is used: "Meta de 2.360 kcal salva".
    static func goalSavedMessage(_ goalKcal: Int) -> String {
        String(localized: "Meta de \(HomeSummary.number(Double(goalKcal))) kcal salva")
    }

    // MARK: - Choices

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionTitle(title)
            content()
        }
    }

    /// Two or three options side by side, the chosen one in blue; one below the other with the
    /// largest text, so no name is cut.
    private func segments<Option: Hashable>(
        _ options: [Option],
        selected: Option?,
        name: @escaping (Option) -> LocalizedStringResource,
        identifier: @escaping (Option) -> String,
        choose: @escaping (Option) -> Void
    ) -> some View {
        let layout = dynamicTypeSize >= .accessibility1 ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        return layout {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button {
                    if !isSelected {
                        choose(option)
                    }
                } label: {
                    Text(name(option))
                        .scaledFont(14, weight: .semibold)
                        .foregroundStyle(isSelected ? Theme.Colors.highlightText : Theme.Colors.mediumText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: segmentHeight)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Theme.Colors.highlightBadge)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .strokeBorder(Theme.Colors.highlightLine, lineWidth: 1)
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier(identifier(option))
            }
        }
        .padding(3)
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Day, month by name and year, each in a menu. The years go from 15 to 100 years ago, the most
    /// recent first. A day beyond the chosen month is saved as its last day.
    @ViewBuilder
    private func birthDateMenus(_ birthDate: BirthDate, now: Date, calendar: Calendar) -> some View {
        let currentYear = calendar.component(.year, from: now)
        let years = Array(stride(
            from: currentYear - BMRCalculator.ageRange.lowerBound,
            through: currentYear - BMRCalculator.ageRange.upperBound,
            by: -1
        ))
        let day = dateMenu("Dia", options: Array(1...31), selected: birthDate.day, text: { "\($0)" }, identifier: "bmr.birth.day") { day in
            var date = birthDate
            date.day = day
            save { try $0.setBirthDate(date) }
        }
        let month = dateMenu("Mês", options: Array(1...12), selected: birthDate.month, text: SessionFormatting.monthName, identifier: "bmr.birth.month") { month in
            var date = birthDate
            date.month = month
            save { try $0.setBirthDate(date) }
        }
        let year = dateMenu("Ano", options: years, selected: birthDate.year, text: { "\($0)" }, identifier: "bmr.birth.year") { year in
            var date = birthDate
            date.year = year
            save { try $0.setBirthDate(date) }
        }
        if dynamicTypeSize >= .accessibility1 {
            VStack(spacing: 8) {
                day
                month
                year
            }
        } else {
            HStack(spacing: 8) {
                day.frame(width: dayMenuWidth)
                month
                year.frame(width: yearMenuWidth)
            }
        }
    }

    /// A menu of `options` with a check on the chosen one; its box shows the choice, or `title` in gray
    /// before there is one.
    private func dateMenu(
        _ title: LocalizedStringResource,
        options: [Int],
        selected: Int?,
        text: @escaping (Int) -> String,
        identifier: String,
        choose: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            Picker(selection: Binding(get: { selected }, set: { value in
                if let value, value != selected {
                    choose(value)
                }
            })) {
                ForEach(options, id: \.self) { option in
                    Text(verbatim: text(option))
                        .tag(Optional(option))
                }
            } label: {
                Text(title)
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Group {
                    if let selected {
                        Text(verbatim: text(selected))
                            .foregroundStyle(Theme.Colors.brightText)
                    } else {
                        Text(title)
                            .foregroundStyle(Theme.Colors.dimText)
                    }
                }
                .scaledFont(16, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .scaledFont(12, weight: .bold)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: menuHeight)
            .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(verbatim: selected.map(text) ?? ""))
        .accessibilityIdentifier(identifier)
    }

    /// The five levels in one block, a line between them, the chosen one with a blue check.
    private func activityLevels(selected: ActivityLevel) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(ActivityLevel.allCases.enumerated()), id: \.element) { index, level in
                if index > 0 {
                    Theme.Colors.rowSeparator
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                activityRow(level, isSelected: level == selected)
            }
        }
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func activityRow(_ level: ActivityLevel, isSelected: Bool) -> some View {
        Button {
            if !isSelected {
                save { try $0.setActivityLevel(level) }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .scaledFont(14, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                    Text(level.detail)
                        .scaledFont(11)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .scaledFont(13, weight: .bold)
                        .foregroundStyle(Theme.Colors.lightAccent)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: level.displayName)), \(String(localized: level.detail))"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("bmr.activity.\(level.rawValue)")
    }

    // MARK: - Result

    /// The BMR, the energy spent and the suggested goal, with what they mean and "Usar … kcal como
    /// meta"; or, without a result, what is missing.
    @ViewBuilder
    private func result(_ estimate: Result<BMRCalculator.Estimate, BMRCalculator.Missing>, goal: WeightGoal) -> some View {
        VStack(spacing: 12) {
            Group {
                switch estimate {
                case .success(let values):
                    VStack(spacing: 10) {
                        ViewThatFits(in: .horizontal) {
                            // The three boxes share the height of the tallest one.
                            HStack(spacing: 8) { resultBoxes(values) }
                                .fixedSize(horizontal: false, vertical: true)
                            VStack(spacing: 8) { resultBoxes(values) }
                        }
                        Text(Self.resultNote(for: goal))
                            .scaledFont(12)
                            .foregroundStyle(Theme.Colors.highlightSecondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("bmr.note")
                    }
                case .failure(let missing):
                    Text(missing.message)
                        .scaledFont(13)
                        .foregroundStyle(Theme.Colors.highlightSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("bmr.message")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.highlightBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Theme.Colors.highlightBorder, lineWidth: 1))

            if let errorMessage {
                Text(verbatim: errorMessage)
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.failureSet)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("bmr.error")
            }

            if case .success(let values) = estimate {
                SheetButton(Text("Usar \(HomeSummary.number(Double(values.goalKcal))) kcal como meta"), kind: .primary) {
                    use(values.goalKcal)
                }
                .accessibilityIdentifier("bmr.use")
            }
        }
    }

    @ViewBuilder
    private func resultBoxes(_ values: BMRCalculator.Estimate) -> some View {
        resultBox(values.bmrKcal, label: "TMB", identifier: "bmr.result.bmr")
        resultBox(values.expenditureKcal, label: "gasto do dia", identifier: "bmr.result.expenditure")
        resultBox(values.goalKcal, label: "meta sugerida", identifier: "bmr.result.goal")
    }

    private func resultBox(_ kcal: Int, label: LocalizedStringResource, identifier: String) -> some View {
        let number = HomeSummary.number(Double(kcal))
        return VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: number)
                .scaledFont(16, weight: .heavy)
                .foregroundStyle(Theme.Colors.brightText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            // One line at the standard sizes; with larger text it wraps rather than being cut.
            Text(label)
                .scaledFont(11)
                .foregroundStyle(Theme.Colors.highlightSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Colors.selectedCardBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: label)): \(number) kcal"))
        .accessibilityIdentifier(identifier)
    }

    /// What the values are, with the goal's adjustment.
    static func resultNote(for goal: WeightGoal) -> LocalizedStringResource {
        switch goal {
        case .lose: "Valores em kcal por dia · meta para perder peso (−400 kcal por dia)"
        case .maintain: "Valores em kcal por dia · meta para manter o peso"
        case .gain: "Valores em kcal por dia · meta para ganhar massa (+300 kcal por dia)"
        }
    }

    /// The note on the estimate and "Fechar".
    private var closing: some View {
        VStack(spacing: 12) {
            Text("É uma estimativa pela fórmula de Mifflin-St Jeor. Para um plano sob medida, procure um nutricionista.")
                .scaledFont(11)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            SheetButton(Text("Fechar"), kind: .secondary) {
                dismiss()
            }
            .accessibilityIdentifier("bmr.close")
        }
    }

    // MARK: - Saving

    /// Saves a choice through the profile service; an error is shown and the saved choice stays.
    private func save(_ change: (ProfileService) throws -> Void) {
        do {
            try change(ProfileService(context: context))
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// Saves the suggested goal, then closes the sheet and tells the presenter.
    private func use(_ goalKcal: Int) {
        guard !isGoalUsed else { return }
        do {
            try ProfileService(context: context).setDailyCalorieGoal(goalKcal)
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return
        }
        isGoalUsed = true
        onUseGoal(goalKcal)
        dismiss()
    }
}
