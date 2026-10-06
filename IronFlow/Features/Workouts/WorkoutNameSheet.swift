import SwiftUI

/// Asks for a workout name, to create or rename a workout.
/// `onSave` receives the typed name; when it throws, the sheet stays open and shows the error.
struct WorkoutNameSheet: View {
    let title: LocalizedStringKey
    let initialName: String
    let onSave: @MainActor (String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?
    /// Set by a successful save, so a second tap while the sheet closes saves nothing.
    @State private var isSaved = false
    @FocusState private var isNameFocused: Bool

    init(title: LocalizedStringKey, initialName: String = "", onSave: @escaping @MainActor (String) throws -> Void) {
        self.title = title
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome do treino", text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .accessibilityIdentifier("workout.name.field")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("workout.name.error")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .accessibilityIdentifier("workout.name.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("workout.name.save")
                }
            }
            .onChange(of: name) {
                errorMessage = nil
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard canSave, !isSaved else { return }
        // An unchanged name (renaming) needs no write.
        guard name.trimmingCharacters(in: .whitespacesAndNewlines) != initialName else {
            dismiss()
            return
        }
        do {
            try onSave(name)
            isSaved = true
            dismiss()
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
