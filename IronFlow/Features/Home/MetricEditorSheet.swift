import SwiftUI

/// Edits one quick summary value: body weight (a new measurement), height or daily calorie goal.
/// `onSave` receives the checked value; when it throws, the sheet stays open and shows the error.
struct MetricEditorSheet: View {
    let metric: SummaryMetric
    let initialValue: Double?
    let onSave: @MainActor (Double) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var saveErrorMessage: String?
    /// Set by a successful save, so a second tap while the sheet closes saves nothing.
    @State private var isSaved = false
    @FocusState private var isFieldFocused: Bool

    init(metric: SummaryMetric, initialValue: Double?, onSave: @escaping @MainActor (Double) throws -> Void) {
        self.metric = metric
        self.initialValue = initialValue
        self.onSave = onSave
        _text = State(initialValue: HomeSummary.fieldText(initialValue))
    }

    private var unit: String {
        switch metric {
        case .bodyWeight: "kg"
        case .height: "cm"
        case .dailyCalorieGoal: "kcal"
        }
    }

    var body: some View {
        // The typed value, checked once per update: nil while empty.
        let input = Result { try HomeSummary.value(for: metric, text: text) }
        let value = try? input.get()
        let inputErrorMessage = Self.message(for: input)

        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        HStack(spacing: 6) {
                            TextField("Valor", text: $text)
                                .keyboardType(metric == .bodyWeight ? .decimalPad : .numberPad)
                                .multilineTextAlignment(.trailing)
                                .focused($isFieldFocused)
                                .accessibilityIdentifier("metric.editor.field")
                            Text(verbatim: unit)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Text(metric.title)
                    }
                } footer: {
                    if let message = saveErrorMessage ?? inputErrorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("metric.editor.error")
                    } else if metric == .bodyWeight {
                        Text("Cada novo peso fica registrado com a data de hoje.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(metric.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .accessibilityIdentifier("metric.editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        if let value {
                            save(value)
                        }
                    }
                    .disabled(value == nil)
                    .accessibilityIdentifier("metric.editor.save")
                }
            }
            .onChange(of: text) {
                saveErrorMessage = nil
            }
            .onAppear {
                isFieldFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private static func message(for input: Result<Double?, any Error>) -> String? {
        guard case .failure(let error) = input else { return nil }
        return UserFacingError.message(for: error)
    }

    private func save(_ value: Double) {
        guard !isSaved else { return }
        // An unchanged value needs no write.
        guard value != initialValue else {
            dismiss()
            return
        }
        do {
            try onSave(value)
            isSaved = true
            dismiss()
        } catch {
            saveErrorMessage = UserFacingError.message(for: error)
        }
    }
}
