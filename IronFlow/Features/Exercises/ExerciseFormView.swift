import SwiftData
import SwiftUI

/// The form of an exercise of the user's own, full screen like the exercise picker, as in the approved
/// prototype: "Cancelar" and the title at the top, then NOME, GRUPO PRINCIPAL, EQUIPAMENTO, TIPO DE MÁQUINA
/// (only with the machine) and MÚSCULOS, and the main button at the bottom with what is still missing
/// above it. A copy starts with a note of what it copies. "Cancelar" asks before leaving changes behind.
/// The main button acts once: a second tap while the form closes does nothing.
struct ExerciseFormView: View {
    /// The exercise of the user's own being edited; `nil` for a new one or a copy.
    let editing: Exercise?
    /// Called with the exercise once it is saved, right before the form closes.
    let onSaved: @MainActor (Exercise) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var form: ExerciseForm
    /// The names taken by the other exercises, read when the form opens.
    @State private var taken: [String: ExerciseNameOwner] = [:]
    /// Set once the exercise was saved, so a second tap saves nothing.
    @State private var isSaved = false
    @State private var isConfirmingDiscard = false
    @State private var musclesSheet: MusclesSheetKind?
    @State private var isShowingMachineTypes = false
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 46
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 46

    init(form: ExerciseForm, editing: Exercise? = nil, onSaved: @escaping @MainActor (Exercise) -> Void) {
        self.editing = editing
        self.onSaved = onSaved
        _form = State(initialValue: form)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let note = form.copyNote {
                    copyNote(note)
                }
                nameSection
                // One group: where the exercise is in the list's filter; its muscles, as many as it has, below.
                VStack(alignment: .leading, spacing: 10) {
                    ExerciseFormChips(
                        title: "Grupo principal",
                        identifier: "exerciseForm.group",
                        options: ExerciseForm.groups.map { group in
                            FormChipOption(id: group.rawValue, title: String(localized: group.displayName), isOn: form.draft.group == group) {
                                form.selectGroup(group)
                            }
                        }
                    )
                    hint("Escolha 1: é onde ele aparece na lista. Mais de um músculo? Marque em Músculos, logo abaixo.", identifier: "exerciseForm.groupChoiceHint")
                }
                ExerciseFormChips(
                    title: "Equipamento",
                    identifier: "exerciseForm.equipment",
                    options: EquipmentChoice.all.map { choice in
                        FormChipOption(
                            id: choice.equipment?.rawValue ?? "other",
                            title: choice.equipment.map { String(localized: $0.displayName) } ?? String(localized: "Outro"),
                            icon: choice.equipment,
                            showsIcon: true,
                            isOn: form.draft.equipment == choice
                        ) {
                            form.selectEquipment(choice)
                        }
                    }
                )
                if form.draft.equipment == .equipment(.machine) {
                    machineSection
                }
                musclesSection
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            // The prototype's 24 between blocks, 6 less below its top row.
            .padding(.top, 18)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .top, spacing: 0) {
            ExerciseFormTopBar(title: form.title, cancelIdentifier: "exerciseForm.cancel", onCancel: cancel)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .screenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exerciseForm.screen")
        // On the whole form, so the question comes up from the bottom, with "Continuar editando".
        .confirmationDialog(
            Text(verbatim: form.discardQuestion.title),
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Descartar", role: .destructive) {
                dismiss()
            }
            Button("Continuar editando", role: .cancel) {}
        } message: {
            Text(verbatim: form.discardQuestion.message)
        }
        .sheet(item: $musclesSheet) { kind in
            MusclesSheet(kind: kind, form: $form)
        }
        .sheet(isPresented: $isShowingMachineTypes) {
            MachineTypesSheet(current: form.draft.machine, context: .form)
        }
        .task {
            loadTakenNames()
        }
        .errorAlert($errorMessage)
    }

    // MARK: - Sections

    private func copyNote(_ note: (title: String, text: String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: note.title)
                .scaledFont(14, weight: .bold, lineHeight: 1.3)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: note.text)
                .scaledFont(12, lineHeight: 1.4, webKitLine: true)
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exerciseForm.copyNote")
    }

    private var nameSection: some View {
        let message = form.nameMessage(taken: taken)
        return VStack(alignment: .leading, spacing: 10) {
            ExerciseFormSectionTitle("Nome")
            nameField
            if let message {
                Text(verbatim: message)
                    .scaledFont(12, lineHeight: 1.35)
                    .foregroundStyle(Theme.Colors.failureSet)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                    // The prototype's 10 between blocks, 4 less above the message.
                    .padding(.top, -4)
                    .accessibilityIdentifier("exerciseForm.nameError")
            }
        }
    }

    /// The name, 16 semibold in a dark field 46 points tall, with a light gray ring while typing. The whole
    /// field opens the keyboard, not only its text.
    private var nameField: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return TextField(
            text: Binding(get: { form.draft.name }, set: { form.setName(String($0.prefix(Validation.maxNameLength))) }),
            prompt: Text("Ex.: Leg Press 45° (Smart Fit)").fontWeight(.medium).foregroundStyle(Theme.Colors.dimText)
        ) {
            Text("Nome")
        }
        .scaledFont(16, weight: .semibold)
        .foregroundStyle(Theme.Colors.brightText)
        .textInputAutocapitalization(.sentences)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .focused($isNameFocused)
        .accessibilityIdentifier("exerciseForm.name")
        .padding(.horizontal, 14)
        .frame(minHeight: fieldHeight)
        .background(Theme.Colors.unplannedDayBackground, in: shape)
        .overlay {
            if isNameFocused {
                shape.strokeBorder(Theme.Colors.lightAccent, lineWidth: 1.5)
            }
        }
        .contentShape(shape)
        .onTapGesture {
            isNameFocused = true
        }
    }

    private var machineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ExerciseFormChips(
                title: "Tipo de máquina",
                identifier: "exerciseForm.machine",
                options: [FormChipOption(id: "unknown", title: String(localized: "Não sei"), isOn: form.draft.machine == nil) {
                    form.selectMachine(nil)
                }] + MachineType.allCases.map { machine in
                    FormChipOption(id: machine.rawValue, title: String(localized: machine.displayName), isOn: form.draft.machine == machine) {
                        form.selectMachine(machine)
                    }
                },
                accessory: {
                    Button {
                        isShowingMachineTypes = true
                    } label: {
                        HStack(spacing: 5) {
                            AppIcon(.info, size: 15)
                            Text("O que é cada tipo")
                                .scaledFont(13, weight: .semibold)
                        }
                        .foregroundStyle(Theme.Colors.lightAccent)
                        .padding(.horizontal, 4)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // The 44-point link is centered on the 14-point row of the title, as in the prototype.
                    .padding(.vertical, -15)
                    .padding(.trailing, -4)
                    .accessibilityIdentifier("exerciseForm.machineInfo")
                }
            )
            if form.draft.machine == .graviton {
                hint("No Graviton, o kg é a ajuda da máquina: menos kg conta como progresso, na evolução e nos recordes.", identifier: "exerciseForm.gravitonHint")
            }
        }
    }

    private var musclesSection: some View {
        let primary = form.primaryText
        let secondary = form.secondaryText
        return VStack(alignment: .leading, spacing: 10) {
            ExerciseFormSectionTitle("Músculos")
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    BodyFigure(side: .front, primary: Set(form.draft.primary), secondary: Set(form.draft.secondary), size: Self.figureSize)
                    BodyFigure(side: .back, primary: Set(form.draft.primary), secondary: Set(form.draft.secondary), size: Self.figureSize)
                }
                VStack(spacing: 0) {
                    musclesRow(kind: .primary, text: primary.text, isPlaceholder: primary.isPlaceholder)
                    Theme.Colors.rowSeparator
                        .frame(height: 1)
                        .accessibilityHidden(true)
                    musclesRow(kind: .secondary, text: secondary.text, isPlaceholder: secondary.isPlaceholder)
                }
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            if form.showsGroupHint {
                hint("Preenchido pelo grupo. Toque para mudar.", identifier: "exerciseForm.groupHint")
            }
        }
    }

    /// The size of each body figure in the form.
    static let figureSize = CGSize(width: 52, height: 141)

    private func musclesRow(kind: MusclesSheetKind, text: String, isPlaceholder: Bool) -> some View {
        Button {
            isNameFocused = false
            musclesSheet = kind
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    MuscleListTitle(kind: kind)
                    Text(verbatim: text)
                        .scaledFont(14, weight: isPlaceholder ? .medium : .semibold, lineHeight: 1.3)
                        .foregroundStyle(isPlaceholder ? Theme.Colors.secondaryText : Theme.Colors.brightText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AppIcon(.chevronRightList, size: 13)
                    .foregroundStyle(Theme.Colors.futureDayText)
            }
            .padding(.vertical, 8)
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(kind.listTitle): \(text)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(kind == .primary ? "exerciseForm.primary" : "exerciseForm.secondary")
    }

    private func hint(_ text: LocalizedStringKey, identifier: String) -> some View {
        Text(text)
            .scaledFont(12, lineHeight: 1.4, webKitLine: true)
            .foregroundStyle(Theme.Colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
            .padding(.top, -2)
            .accessibilityIdentifier(identifier)
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        let canSave = form.canSave(taken: taken) && !isSaved
        return VStack(spacing: 0) {
            Theme.Colors.rowSeparator
                .frame(height: 1)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                if let missing = form.missingText {
                    Text(verbatim: missing)
                        .scaledFont(12, lineHeight: 16.0 / 12)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("exerciseForm.missing")
                }
                Button(action: save) {
                    Text(verbatim: form.buttonTitle)
                        .scaledFont(15, weight: .bold)
                        .foregroundStyle(Theme.Colors.primaryButtonText)
                        .frame(maxWidth: .infinity, minHeight: buttonHeight)
                        .background(Theme.Colors.primaryButton, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .contentShape(Rectangle())
                }
                // Unavailable, the whole white button at 35 %, as in the prototype.
                .buttonStyle(PrototypeButtonStyle())
                .disabled(!canSave)
                .accessibilityIdentifier("exerciseForm.save")
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        // Opaque, so the form never shows through the button.
        .background(Theme.Colors.screenBackground)
    }

    // MARK: - Actions

    private func loadTakenNames() {
        do {
            taken = try ExerciseService(context: context).takenNames(ignoring: editing)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func cancel() {
        isNameFocused = false
        if form.hasChanges {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard !isSaved, form.canSave(taken: taken) else { return }
        isNameFocused = false
        let service = ExerciseService(context: context)
        do {
            let saved: Exercise
            if let editing {
                try service.update(editing, with: form.draft)
                saved = editing
            } else {
                saved = try service.create(form.draft)
            }
            isSaved = true
            onSaved(saved)
            dismiss()
        } catch {
            // The names may have changed since the form opened: read them again for the message below the name.
            loadTakenNames()
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// Which of the two muscle lists a row or a sheet is about.
enum MusclesSheetKind: String, Identifiable {
    case primary, secondary

    var id: String { rawValue }

    var listTitle: String {
        switch self {
        case .primary: String(localized: "Principais")
        case .secondary: String(localized: "Secundários")
        }
    }
}

/// "■ PRINCIPAIS" or "■ SECUNDÁRIOS": the color of the list on the body figure and its name.
struct MuscleListTitle: View {
    let kind: MusclesSheetKind

    @ScaledMetric(relativeTo: .caption2) private var swatchSide: CGFloat = 9

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(kind == .primary ? Theme.Colors.accent : Theme.Colors.muscleSecondary)
                .frame(width: swatchSide, height: swatchSide)
            Text(verbatim: kind.listTitle)
                .scaledFont(10, weight: .heavy)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }
}

/// A title of the form ("NOME", "GRUPO PRINCIPAL"): 11 heavy, spaced 2,1, on a 14-point line.
struct ExerciseFormSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .scaledFont(11, weight: .heavy, lineHeight: 14.0 / 11)
            .tracking(2.1)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.brightText)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The top of the form, as the exercise picker's in the prototype: "Cancelar" on the left and the title
/// centered on a 36-point row, 8 below the top of the screen. "Cancelar" keeps 44 points of touch.
struct ExerciseFormTopBar: View {
    let title: String
    let cancelIdentifier: String
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            cancelButton
            Text(verbatim: title)
                .scaledFont(16, weight: .heavy)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("exerciseForm.title")
            cancelButton
                .hidden()
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .frame(minHeight: 36)
        .padding(.top, 8)
        .background(Theme.Colors.screenBackground)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancelar")
                .scaledFont(15)
                .foregroundStyle(Theme.Colors.lightAccent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        // The 44 points of touch take no more room than the 36-point row.
        .padding(.vertical, -4)
        .accessibilityIdentifier(cancelIdentifier)
    }
}
