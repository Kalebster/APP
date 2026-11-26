import SwiftData
import SwiftUI

/// The exercise screen, as in the approved prototype: the name, "grupo · equipamento" (with MEU or
/// ARQUIVADO for an exercise of the user's own), the muscles on the body figure, the kind of machine, and
/// the person's history with the exercise (the last time, the best set, the evolution chart and the
/// sessions). The ⋯ at the top offers "Criar minha versão" for a library exercise, and "Editar",
/// "Duplicar" and "Apagar exercício" or "Arquivar exercício" (or "Restaurar") for one of the user's own.
///
/// It opens from a row of the Exercícios tab (the tab bar stays, with Exercícios chosen) and from
/// "Ver exercício" in the ⋯ of an exercise in the workout editor or in the session (without the tab bar,
/// "‹" with the workout's name). The history is read once when the screen opens; the session in
/// progress never counts. A copy made here takes the screen's place, with the same "‹".
struct ExerciseDetailView: View {
    /// Where the screen was opened from: the back button and the tab bar follow it.
    enum Origin: Hashable {
        case exercises
        /// The workout editor or the session, with the workout's name.
        case workout(name: String)
    }

    let origin: Origin

    /// The exercise shown: the one opened, or the copy made from it.
    @State private var exercise: Exercise
    /// The notices of this screen ("Exercício salvo", "Cópia criada"), over whatever opened it.
    @State private var toast: ToastMessage?

    init(exercise: Exercise, origin: Origin) {
        self.origin = origin
        _exercise = State(initialValue: exercise)
    }

    var body: some View {
        ExerciseDetailScreen(exercise: exercise, origin: origin, toast: $toast) { copy, notice in
            exercise = copy
            toast = ToastMessage(notice)
        }
        // A copy is a new screen: its history, chart and scroll start over.
        .id(exercise.id)
        .toast($toast)
    }
}

/// The screen of one exercise (see `ExerciseDetailView`).
private struct ExerciseDetailScreen: View {
    let exercise: Exercise
    let origin: ExerciseDetailView.Origin
    @Binding var toast: ToastMessage?
    /// Shows the copy just made, with its notice.
    let onShowCopy: @MainActor (Exercise, String) -> Void

    /// The form open over the screen.
    private struct FormRequest: Identifiable {
        let id = UUID()
        let form: ExerciseForm
        let isEditing: Bool
    }

    /// The question before archiving or deleting, with what the person was shown.
    private struct RemovalQuestion {
        let archives: Bool
        let workoutIDs: Set<UUID>
        let title: String
        let message: String
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// The root's notices and errors, for what happens once the screen has closed ("Exercício apagado").
    @Environment(RootFeedback.self) private var rootFeedback: RootFeedback?
    /// `nil` until read.
    @State private var history: ExerciseHistory?
    /// "Today" for the periods of the chart, taken when the screen opens.
    @State private var today = ExerciseDetailToday.current()
    @State private var isShowingMachineTypes = false
    /// The session of a history card, opened in its detail.
    @State private var openedSession: Session?
    @State private var errorMessage: String?
    @State private var formRequest: FormRequest?
    /// The copy saved in the form, shown once the form has closed.
    @State private var savedCopy: (exercise: Exercise, notice: String)?
    @State private var removal: RemovalQuestion?
    @State private var isConfirmingRemoval = false
    /// The name of the active exercise that keeps this one from being restored.
    @State private var restoreConflict: String?
    /// Set once an archive, a deletion or a restore was asked, so a second tap does nothing.
    @State private var isActing = false
    /// The deletion confirmed: it happens once the screen has closed, so the screen never reads an
    /// exercise that no longer exists.
    @State private var pendingDeletion: Set<UUID>?
    @State private var scrollPosition = ScrollPosition(edge: .top)

    @ScaledMetric(relativeTo: .body) private var menuSide: CGFloat = 32

    var body: some View {
        let muscles = DefaultExerciseMuscles.muscles(of: exercise)
        let machine = DefaultExerciseMuscles.machine(of: exercise)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ExerciseDetailTitle(name: exercise.name, detail: detailText, badge: badge)
                    // 52 below the top of the screen, as in the prototype: 4 below the 44-point top row.
                    .padding(.top, 4)

                if exercise.isCustom && exercise.isArchived {
                    ArchivedExerciseCard(isRestoring: isActing, onRestore: restore)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle("Músculos")
                    ExerciseMusclesCard(
                        primary: muscles.primary,
                        secondary: muscles.secondary,
                        focus: focus,
                        showsGroupNote: DefaultExerciseMuscles.showsGroupMuscles(of: exercise)
                    )
                    if let machine {
                        MachineTypeRow(machine: machine) {
                            isShowingMachineTypes = true
                        }
                    }
                }

                if let history {
                    if history.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle("Evolução")
                            ExerciseNeverDoneCard()
                        }
                    } else {
                        ExerciseEvolutionSection(history: history, today: today, calendar: TrainingDay.calendar)
                        ExerciseHistorySection(history: history, today: today, calendar: TrainingDay.calendar, onOpen: openSession)
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollPosition($scrollPosition)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                TextBackButton(verbatim: backTitle) {
                    dismiss()
                }
                .accessibilityIdentifier("exercise.back")
                Spacer(minLength: 0)
                menu
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            // The prototype's 8 above its 36-point top row, with the 44-point controls centered on it.
            .padding(.top, 4)
            .background(Theme.Colors.screenBackground)
        }
        .screenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exercise.screen")
        // The navigation bar is hidden for the prototype's own top row; the swipe back stays. The name is the
        // title the session detail's back button shows.
        .navigationTitle(exercise.name)
        .background(InteractivePopEnabler())
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(origin == .exercises ? .automatic : .hidden, for: .tabBar)
        .task(id: exercise.id) {
            loadHistory()
        }
        // A new kind of machine (Graviton or not) reads the same sessions with other metrics.
        .onChange(of: DefaultExerciseMuscles.isAssisted(exercise)) { _, isAssisted in
            if let history {
                self.history = ExerciseHistory(entries: history.entries, isAssisted: isAssisted)
            }
        }
        .sheet(isPresented: $isShowingMachineTypes) {
            MachineTypesSheet(current: machine, context: exercise.isCustom ? .custom : .library)
        }
        .fullScreenCover(item: $formRequest, onDismiss: showSavedCopy) { request in
            ExerciseFormView(form: request.form, editing: request.isEditing ? exercise : nil) { saved in
                if request.isEditing {
                    toast = ToastMessage(String(localized: "Exercício salvo"))
                } else {
                    savedCopy = (saved, exercise.isCustom ? String(localized: "Cópia criada") : String(localized: "Sua versão foi criada"))
                }
            }
        }
        .navigationDestination(item: $openedSession) { session in
            HistorySessionDetailView(detail: HistorySessionDetail(session))
        }
        .alert(
            Text(verbatim: String(localized: "Já existe “\(restoreConflict ?? "")”")),
            isPresented: Binding(get: { restoreConflict != nil }, set: { if !$0 { restoreConflict = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Mude o nome deste exercício em Editar e tente de novo.")
        }
        .onDisappear(perform: deleteIfConfirmed)
        .errorAlert($errorMessage)
    }

    // MARK: - Menu

    /// The ⋯ of the top row: the iOS menu, with the confirmation of archiving or deleting coming from it.
    private var menu: some View {
        Menu {
            if !exercise.isCustom {
                Button("Criar minha versão", systemImage: "plus.square.on.square", action: duplicate)
            } else if exercise.isArchived {
                Button("Restaurar", systemImage: "arrow.uturn.backward", action: restore)
                Button("Editar", systemImage: "pencil", action: edit)
                Button("Duplicar", systemImage: "plus.square.on.square", action: duplicate)
            } else {
                Button("Editar", systemImage: "pencil", action: edit)
                Button("Duplicar", systemImage: "plus.square.on.square", action: duplicate)
                Divider()
                let archives = !exercise.sessionExercises.isEmpty
                Button(
                    ExerciseRemovalText.action(archives: archives),
                    systemImage: archives ? "archivebox" : "trash",
                    role: .destructive,
                    action: askRemoval
                )
            }
        } label: {
            AppIcon(.more, size: 16)
                .foregroundStyle(Theme.Colors.mediumText)
                .frame(width: menuSide, height: menuSide)
                .glassEffect(.regular.interactive(), in: Circle())
                .frame(width: max(44, menuSide), height: max(44, menuSide))
                .contentShape(Rectangle())
        }
        .padding(.trailing, min(0, (menuSide - 44) / 2))
        .accessibilityLabel(Text("Opções do exercício"))
        .accessibilityIdentifier("exercise.menu")
        // On the ⋯ itself, so the confirmation points to the button it came from.
        .confirmationDialog(
            Text(verbatim: removal?.title ?? ""),
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible,
            presenting: removal
        ) { question in
            Button(ExerciseRemovalText.action(archives: question.archives), role: .destructive) {
                remove(question)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { question in
            Text(verbatim: question.message)
        }
    }

    // MARK: - Texts

    private var backTitle: String {
        switch origin {
        case .exercises: String(localized: "Exercícios")
        case .workout(let name): name
        }
    }

    /// "Peito · Barra"; for an exercise of the user's own, its equipment or "Outro".
    private var detailText: String {
        let group = String(localized: exercise.muscleGroup.displayName)
        if let equipment = DefaultExerciseMuscles.equipment(of: exercise) {
            return "\(group) · \(String(localized: equipment.displayName))"
        }
        return exercise.isCustom ? "\(group) · \(String(localized: "Outro"))" : group
    }

    /// MEU or ARQUIVADO after the subtitle of an exercise of the user's own.
    private var badge: String? {
        guard exercise.isCustom else { return nil }
        return exercise.isArchived ? String(localized: "ARQUIVADO") : String(localized: "MEU")
    }

    private var focus: String? {
        guard !exercise.isCustom, let key = exercise.libraryKey else { return nil }
        return DefaultExerciseLibrary.byKey[key]?.focus
    }

    // MARK: - Actions

    /// Reads the history once: coming back from a session's detail does not read it again.
    private func loadHistory() {
        guard history == nil else { return }
        do {
            history = try ExerciseHistoryLoader(context: context).history(of: exercise)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func openSession(_ id: UUID) {
        #if DEBUG
        UITestDeletedSession.deleteIfAsked(id: id, in: context)
        #endif
        do {
            if let session = try ExerciseHistoryLoader(context: context).session(id: id) {
                openedSession = session
            } else {
                // Deleted since the screen read its history: the history is read again without it.
                toast = ToastMessage(String(localized: "Esse treino não está mais no histórico."))
                history = nil
                loadHistory()
            }
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func edit() {
        formRequest = FormRequest(form: ExerciseForm(editing: exercise), isEditing: true)
    }

    /// "Duplicar" and "Criar minha versão": the form of a copy, with the name and " 2".
    private func duplicate() {
        do {
            let name = try ExerciseService(context: context).copyName(for: exercise.name)
            formRequest = FormRequest(form: ExerciseForm(copying: exercise, name: name), isEditing: false)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// The copy takes the screen's place once the form has closed.
    private func showSavedCopy() {
        guard let savedCopy else { return }
        self.savedCopy = nil
        onShowCopy(savedCopy.exercise, savedCopy.notice)
    }

    private func askRemoval() {
        let impact = ExerciseService(context: context).removalImpact(of: exercise)
        guard impact != .notAllowedSystemExercise else { return }
        var archives = false
        if case .willArchive = impact {
            archives = true
        }
        let workouts = impact.workouts
        removal = RemovalQuestion(
            archives: archives,
            workoutIDs: Set(workouts.map(\.id)),
            title: ExerciseRemovalText.title(name: exercise.name, archives: archives),
            message: ExerciseRemovalText.message(archives: archives, workoutNames: workouts.map(\.name))
        )
        isConfirmingRemoval = true
    }

    /// Archives at once and stays on the screen, at its top; a deletion waits for the screen to close.
    private func remove(_ question: RemovalQuestion) {
        guard !isActing else { return }
        isActing = true
        if question.archives {
            do {
                try ExerciseService(context: context).remove(exercise, confirmedWorkoutIDs: question.workoutIDs)
                toast = ToastMessage(String(localized: "Exercício arquivado"))
                withAnimation {
                    scrollPosition.scrollTo(edge: .top)
                }
            } catch {
                errorMessage = UserFacingError.message(for: error)
            }
            isActing = false
        } else {
            pendingDeletion = question.workoutIDs
            dismiss()
        }
    }

    /// The deletion confirmed, once the screen has closed; its notice and its error go to the root.
    private func deleteIfConfirmed() {
        guard let confirmed = pendingDeletion else { return }
        pendingDeletion = nil
        do {
            try ExerciseService(context: context).remove(exercise, confirmedWorkoutIDs: confirmed)
            rootFeedback?.show(String(localized: "Exercício apagado"))
        } catch {
            rootFeedback?.errorMessage = UserFacingError.message(for: error)
        }
    }

    /// Acts once: a second tap finds the exercise restored already.
    private func restore() {
        guard !isActing, exercise.isArchived else { return }
        isActing = true
        defer { isActing = false }
        do {
            try ExerciseService(context: context).unarchive(exercise)
            toast = ToastMessage(String(localized: "Exercício restaurado"))
        } catch ExerciseError.nameTakenByActiveExercise(let name) {
            restoreConflict = name
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// "Exercício arquivado" at the top of the screen of an archived exercise of the user's own, with "Restaurar".
private struct ArchivedExerciseCard: View {
    let isRestoring: Bool
    let onRestore: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Exercício arquivado")
                .scaledFont(14, weight: .bold)
                .accessibilityAddTraits(.isHeader)
            Text("Não aparece na lista nem para adicionar a um treino. O histórico e os recordes continuam aqui.")
                .scaledFont(12, lineHeight: 1.4)
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onRestore) {
                Text("Restaurar")
                    .scaledFont(13, weight: .bold)
                    .foregroundStyle(Theme.Colors.primaryButtonText)
                    .padding(.horizontal, 16)
                    .frame(minHeight: buttonHeight)
                    .background(Theme.Colors.primaryButton, in: Capsule())
                    // 5 more points above and below respond to touches, for a 44-point touch area.
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .padding(.vertical, -5)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
            .padding(.top, 8)
            .accessibilityIdentifier("exercise.restore")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14), cornerRadius: 17)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exercise.archived")
    }
}
