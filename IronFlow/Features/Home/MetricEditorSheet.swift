import SwiftData
import SwiftUI

/// Edits one value of the body data: body weight (the measurement of today), height or daily calorie
/// goal. The value is large in the middle, with − and + beside it that step within the limits; the
/// keyboard opens only when the number is tapped. Body weight lists its latest records.
///
/// `onSave` receives the checked value; when it throws, the sheet stays open and shows the error.
/// An unchanged value closes the sheet without saving, unless `savesUnchangedValue` is set. `onSaved`
/// is called whenever "Salvar" closes the sheet. With `onCalculatedGoal`, the calorie goal links to the
/// BMR calculator: "Fechar" there comes back here, and a goal used there closes both sheets and is
/// passed to `onCalculatedGoal`.
struct MetricEditorSheet: View {
    let metric: BodyMetric
    let initialValue: Double?
    let savesUnchangedValue: Bool
    let onSave: @MainActor (Double) throws -> Void
    let onSaved: @MainActor () -> Void
    let onCalculatedGoal: (@MainActor (Int) -> Void)?

    /// The latest body weights, the newest first: the "ÚLTIMOS REGISTROS" of the weight.
    @Query(ProfileService.recentWeightsDescriptor) private var recentWeights: [BodyWeightEntry]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var text: String
    /// The error of the last "Salvar", shown under the value until the text changes.
    @State private var errorMessage: String?
    /// Set by a successful save, so a second tap while the sheet closes saves nothing.
    @State private var isSaved = false
    @State private var isCalculating = false
    /// The goal saved by the BMR calculator, handed on once the calculator is gone.
    @State private var calculatedGoal: Int?
    @FocusState private var isFieldFocused: Bool

    @ScaledMetric(relativeTo: .body) private var stepSide: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var fieldWidth: CGFloat = 136
    @ScaledMetric(relativeTo: .caption) private var messageHeight: CGFloat = 32
    @ScaledMetric(relativeTo: .caption2) private var changeWidth: CGFloat = 46

    init(
        metric: BodyMetric,
        initialValue: Double?,
        savesUnchangedValue: Bool = false,
        onSave: @escaping @MainActor (Double) throws -> Void,
        onSaved: @escaping @MainActor () -> Void = {},
        onCalculatedGoal: (@MainActor (Int) -> Void)? = nil
    ) {
        self.metric = metric
        self.initialValue = initialValue
        self.savesUnchangedValue = savesUnchangedValue
        self.onSave = onSave
        self.onSaved = onSaved
        self.onCalculatedGoal = onCalculatedGoal
        _text = State(initialValue: HomeSummary.fieldText(initialValue, for: metric))
    }

    var body: some View {
        FittedSheet {
            // 8 between the blocks, as in the model's sheet, and the value row's own margins.
            VStack(alignment: .leading, spacing: 8) {
                SheetHeader(Text(metric.editorTitle))
                valueRow
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                message
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                if metric == .dailyCalorieGoal, onCalculatedGoal != nil {
                    calculatorLink
                }
                if metric == .bodyWeight, !recentWeights.isEmpty {
                    records
                        .padding(.top, 8)
                }
            }
            .sheetContentPadding()
        } bottom: {
            buttons
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: text) {
            errorMessage = nil
        }
    }

    // MARK: - Value

    /// The value from which − and + step.
    private var base: Double {
        MetricEditing.base(of: metric, text: text, saved: initialValue)
    }

    /// − and + beside the value; below it from the second largest standard text size on, where the
    /// three no longer fit side by side, so nothing is cut.
    @ViewBuilder
    private var valueRow: some View {
        if dynamicTypeSize > .xLarge {
            VStack(spacing: 14) {
                valueField
                HStack {
                    stepButton(.down)
                    Spacer(minLength: 16)
                    stepButton(.up)
                }
            }
        } else {
            HStack(spacing: 8) {
                stepButton(.down)
                Spacer(minLength: 0)
                valueField
                Spacer(minLength: 0)
                stepButton(.up)
            }
        }
    }

    /// The number, large and underlined, with its unit beside it. Tapping it opens the keyboard.
    private var valueField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TextField(text: $text, prompt: Text(verbatim: "—")) {
                Text(metric.editorTitle)
            }
            .scaledFont(46, weight: .heavy)
            .tracking(-1)
            .foregroundStyle(Theme.Colors.brightText)
            .multilineTextAlignment(.center)
            .keyboardType(metric == .bodyWeight ? .decimalPad : .numberPad)
            .focused($isFieldFocused)
            // Wide enough for "80,25" and "8.000"; never wider than the sheet with large text.
            .frame(width: min(fieldWidth, 240))
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isFieldFocused ? Theme.Colors.lightAccent : Theme.Colors.cardBorder)
                    .frame(height: 2)
                    .accessibilityHidden(true)
            }
            .accessibilityIdentifier("metric.editor.field")
            Text(verbatim: metric.unit)
                .scaledFont(17, weight: .semibold)
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityHidden(true)
        }
        // The number stops growing past the first accessibility size, so it fits the width of the sheet.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(maxWidth: .infinity)
    }

    /// A round − or +, in text as in the model: one step (0,1 kg, 1 cm or 50 kcal), unavailable at the limit.
    private func stepButton(_ direction: MetricEditing.Direction) -> some View {
        let isEnabled = MetricEditing.canStep(base, metric: metric, direction: direction)
        let stepText = "\(HomeSummary.number(MetricEditing.step(of: metric))) \(metric.unit)"
        // Grows with the text, up to a size that still leaves room for the value.
        let side = min(stepSide, 84)
        return Button {
            text = HomeSummary.fieldText(MetricEditing.stepped(base, metric: metric, direction: direction), for: metric)
        } label: {
            Text(verbatim: direction == .up ? "+" : "\u{2212}")
                .scaledFont(26, weight: .medium)
                .foregroundStyle(Theme.Colors.brightText)
                .frame(width: side, height: side)
                .background(Theme.Colors.unplannedDayBackground, in: Circle())
                .opacity(isEnabled ? 1 : 0.35)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(direction == .up ? Text("Aumentar \(stepText)") : Text("Diminuir \(stepText)"))
        .accessibilityIdentifier(direction == .up ? "metric.editor.plus" : "metric.editor.minus")
    }

    /// The error of the last "Salvar" or, without one, what the value means. It keeps its height, so the
    /// sheet does not move when an error comes or goes.
    private var message: some View {
        Group {
            if let errorMessage {
                Text(verbatim: errorMessage)
                    .foregroundStyle(Theme.Colors.failureSet)
                    .accessibilityIdentifier("metric.editor.error")
            } else if let help = metric.help {
                Text(help)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .scaledFont(12)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: messageHeight, alignment: .top)
    }

    /// "Calcular pela minha TMB": opens the BMR calculator over the editor. The calculator's sheet is
    /// attached here, inside the editor's content: attached around the whole editor, it kept the editor
    /// at the middle height instead of the height of its content.
    private var calculatorLink: some View {
        Button {
            isFieldFocused = false
            calculatedGoal = nil
            isCalculating = true
        } label: {
            HStack(spacing: 6) {
                AppIcon(.calculator, size: 14)
                Text("Calcular pela minha TMB")
                    .scaledFont(13, weight: .bold)
            }
            .foregroundStyle(Theme.Colors.lightAccent)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A 44-point touch area in the room of the model's link: its text with 6 points above and below.
        .padding(.vertical, -8)
        .accessibilityIdentifier("metric.editor.bmr")
        .sheet(isPresented: $isCalculating, onDismiss: finishCalculation) {
            BMRCalculatorSheet { goal in
                calculatedGoal = goal
            }
        }
    }

    /// Once the calculator is gone: a goal used there closes the editor too, without saving its field.
    private func finishCalculation() {
        guard let goal = calculatedGoal, !isSaved else { return }
        calculatedGoal = nil
        isSaved = true
        onCalculatedGoal?(goal)
        dismiss()
    }

    // MARK: - Records

    /// "ÚLTIMOS REGISTROS": the latest body weights, each with its change from the one below it.
    private var records: some View {
        let rows = HomeSummary.weightRecordRows(recentWeights, now: .now, calendar: TrainingDay.calendar)
        return VStack(alignment: .leading, spacing: 6) {
            SheetSectionTitle("Últimos registros")
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Theme.Colors.rowSeparator
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                    recordRow(row)
                }
            }
            .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func recordRow(_ row: HomeSummary.WeightRecordRow) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text(verbatim: row.dateText)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer(minLength: 0)
                recordValue(row)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: row.dateText)
                    .foregroundStyle(Theme.Colors.secondaryText)
                recordValue(row)
            }
        }
        .scaledFont(14)
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: [row.dateText, row.valueText, row.changeText.map { "\($0) kg" }].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityIdentifier("metric.editor.record")
    }

    /// "80 kg" and, in gray, its change ("−0,6") in a column of its own, so the values line up.
    private func recordValue(_ row: HomeSummary.WeightRecordRow) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: row.valueText)
                .scaledFont(14, weight: .bold)
                .foregroundStyle(Theme.Colors.brightText)
            Text(verbatim: row.changeText ?? "")
                .scaledFont(11)
                .foregroundStyle(Theme.Colors.dimText)
                .frame(minWidth: changeWidth, alignment: .trailing)
        }
    }

    // MARK: - Buttons

    /// "Salvar" in blue and "Cancelar" below it, above the keyboard while it is open.
    private var buttons: some View {
        VStack(spacing: 8) {
            SheetButton(Text("Salvar"), kind: .primary, action: saveTapped)
                .disabled(isTextEmpty)
                .accessibilityIdentifier("metric.editor.save")
            SheetButton(Text("Cancelar"), kind: .secondary) {
                dismiss()
            }
            .accessibilityIdentifier("metric.editor.cancel")
        }
        .sheetButtonBar()
    }

    private var isTextEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Checks the typed value; an error stays under the value until the text changes.
    private func saveTapped() {
        do {
            guard let value = try HomeSummary.value(for: metric, text: text) else { return }
            save(value)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func save(_ value: Double) {
        guard !isSaved else { return }
        // An unchanged value needs no write.
        if value != initialValue || savesUnchangedValue {
            do {
                try onSave(value)
            } catch {
                errorMessage = UserFacingError.message(for: error)
                return
            }
        }
        isSaved = true
        isFieldFocused = false
        onSaved()
        dismiss()
    }
}
