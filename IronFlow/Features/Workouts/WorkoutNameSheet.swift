import SwiftUI

/// Asks for a workout name, to create or rename a workout, as in the model: the title, the name field,
/// and the blue button ("Criar treino", "Salvar") above "Cancelar". The button is unavailable while the
/// name is blank. `onSave` receives the typed name; when it throws, the sheet stays open and shows the
/// error below the field.
struct WorkoutNameSheet: View {
    let title: LocalizedStringKey
    let initialName: String
    /// The blue button's title: "Criar treino" for a new workout, "Salvar" when renaming.
    let saveTitle: LocalizedStringKey
    let onSave: @MainActor (String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?
    /// Set by a successful save, so a second tap while the sheet closes saves nothing.
    @State private var isSaved = false
    @FocusState private var isNameFocused: Bool
    @ScaledMetric(relativeTo: .callout) private var fieldHeight: CGFloat = 46

    init(
        title: LocalizedStringKey,
        initialName: String = "",
        saveTitle: LocalizedStringKey = "Salvar",
        onSave: @escaping @MainActor (String) throws -> Void
    ) {
        self.title = title
        self.initialName = initialName
        self.saveTitle = saveTitle
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 8) {
                SheetHeader(Text(title))
                field
                if let errorMessage {
                    Text(errorMessage)
                        .scaledFont(11)
                        .foregroundStyle(Theme.Colors.failureSet)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                        .padding(.top, -2)
                        .accessibilityIdentifier("workout.name.error")
                }
            }
            .sheetContentPadding()
        } bottom: {
            VStack(spacing: 8) {
                SheetButton(Text(saveTitle), kind: .primary, action: save)
                    .disabled(!canSave)
                    .accessibilityIdentifier("workout.name.save")
                SheetButton(Text("Cancelar"), kind: .secondary) {
                    dismiss()
                }
                .accessibilityIdentifier("workout.name.cancel")
            }
            .sheetButtonBar()
        }
        .onChange(of: name) {
            errorMessage = nil
        }
        .onAppear {
            isNameFocused = true
        }
    }

    /// The name, 16 semibold in a dark field 46 points tall; its border turns light blue while typing.
    private var field: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return TextField(text: $name, prompt: Text("Ex.: Costas e Bíceps").foregroundStyle(Theme.Colors.dimText)) {
            Text("Nome do treino")
        }
        .scaledFont(16, weight: .semibold)
        .foregroundStyle(Theme.Colors.brightText)
        .focused($isNameFocused)
        .submitLabel(.done)
        .onSubmit(save)
        .accessibilityIdentifier("workout.name.field")
        .padding(.horizontal, 14)
        .frame(minHeight: fieldHeight)
        .background(Theme.Colors.screenBackground, in: shape)
        .overlay(shape.strokeBorder(isNameFocused ? Theme.Colors.lightAccent : Theme.Colors.cardBorder, lineWidth: 1))
        // The whole field opens the keyboard, not only its text.
        .contentShape(shape)
        .onTapGesture {
            isNameFocused = true
        }
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
