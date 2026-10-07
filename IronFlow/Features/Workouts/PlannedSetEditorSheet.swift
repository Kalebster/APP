import SwiftUI

/// Edits one planned set: minimum and maximum repetitions and an optional load in kilograms.
/// `onSave` receives the checked values; when it throws, the sheet stays open and shows the error.
struct PlannedSetEditorSheet: View {
    let number: Int
    let initialValues: PlannedSetValues
    let onSave: @MainActor (PlannedSetValues) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var repsMinText: String
    @State private var repsMaxText: String
    @State private var weightText: String
    @State private var saveErrorMessage: String?
    /// Set by a successful save, so a second tap while the sheet closes saves nothing.
    @State private var isSaved = false

    init(number: Int, values: PlannedSetValues, onSave: @escaping @MainActor (PlannedSetValues) throws -> Void) {
        self.number = number
        self.initialValues = values
        self.onSave = onSave
        _repsMinText = State(initialValue: String(values.repsMin))
        _repsMaxText = State(initialValue: String(values.repsMax))
        _weightText = State(initialValue: PlannedSetFormatting.weightFieldText(values.weightKg))
    }

    var body: some View {
        // The typed values, checked once per update, or the first problem with them.
        let input = Result { try PlannedSetFormatting.values(repsMin: repsMinText, repsMax: repsMaxText, weight: weightText) }
        let inputErrorMessage = input.failureMessage

        NavigationStack {
            Form {
                Section("Repetições") {
                    LabeledContent("Mínimo") {
                        TextField("Mínimo", text: $repsMinText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("set.editor.min")
                    }
                    LabeledContent("Máximo") {
                        TextField("Máximo", text: $repsMaxText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("set.editor.max")
                    }
                }
                Section {
                    LabeledContent("Carga (kg)") {
                        TextField("Opcional", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("set.editor.weight")
                    }
                } footer: {
                    if let message = saveErrorMessage ?? inputErrorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("set.editor.error")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Série \(number)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .accessibilityIdentifier("set.editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        if case .success(let values) = input {
                            save(values)
                        }
                    }
                    .disabled(inputErrorMessage != nil)
                    .accessibilityIdentifier("set.editor.save")
                }
            }
            .onChange(of: [repsMinText, repsMaxText, weightText]) {
                saveErrorMessage = nil
            }
        }
        // The number keyboards have no return key; the large size keeps every field reachable.
        .presentationDetents([.medium, .large])
    }

    private func save(_ values: PlannedSetValues) {
        guard !isSaved else { return }
        // Unchanged values need no write.
        guard values != initialValues else {
            dismiss()
            return
        }
        do {
            try onSave(values)
            isSaved = true
            dismiss()
        } catch {
            saveErrorMessage = UserFacingError.message(for: error)
        }
    }
}

private extension Result where Failure == any Error {
    /// The message to show for a failure; `nil` on success.
    var failureMessage: String? {
        guard case .failure(let error) = self else { return nil }
        return UserFacingError.message(for: error)
    }
}
