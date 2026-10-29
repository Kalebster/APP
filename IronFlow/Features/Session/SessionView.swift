import OSLog
import SwiftData
import SwiftUI

private let sessionLogger = Logger(subsystem: "com.ironflow.app", category: "session")

/// The session in progress: its exercises and sets, adding and removing exercises and sets, the rest
/// between sets, finishing and discarding. Every change is saved right away; a typed value is saved
/// when its field loses focus, when the set is checked, or when the screen is minimized or the app
/// leaves the foreground. Changes here touch only the session, never the planned workout.
///
/// The sets are rows of a list, which creates and reuses rows as they scroll: typed values are kept
/// here (`drafts`), never in a row, so one that scrolls out of sight is still saved.
struct SessionView: View {
    let session: Session
    /// The rest between sets. Kept by the root view, so it goes on while the session is minimized.
    @Binding var restTimer: RestTimer
    /// Closes the screen (minimized, finished or discarded).
    let onClose: @MainActor () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    /// Shows "Treino salvo" and "Treino descartado" once the screen has closed.
    @Environment(RootFeedback.self) private var rootFeedback: RootFeedback?
    /// The notice of the last change on this screen ("Série removida").
    @State private var toast: ToastMessage?
    /// Typed values not saved yet, by set id.
    @State private var drafts: [UUID: SetDraft] = [:]
    @FocusState private var focusedField: SetField?
    /// "Última vez": the sets done the last time each exercise was performed, by exercise id. Read once
    /// when the screen opens and again when its exercises change.
    @State private var lastPerformances: [UUID: [PreviousSet]] = [:]
    /// Finished exercises opened again, by performed exercise id; the others stay closed.
    @State private var openedFinished: Set<UUID> = []
    /// Rests that reached zero on screen, for the vibration.
    @State private var restsEnded = 0
    @State private var isPickingExercises = false
    /// "Concluir treino?", with what the session did when "Concluir" was tapped.
    @State private var finishSummary: SessionFinishSummary?
    /// What a button of "Concluir treino?" asked for, done once the sheet has closed.
    @State private var afterFinishSheet: FinishSheetAction?
    @State private var isConfirmingDiscard = false
    /// A set already done that is about to be removed, waiting for the confirmation.
    @State private var setPendingRemoval: SetLog?
    /// An exercise with sets done that is about to be removed, waiting for the confirmation.
    @State private var exercisePendingRemoval: SessionExercise?
    /// The set whose type sheet is open.
    @State private var typeSheet: TypeSheetTarget?
    /// The set "Remover série" of the type sheet asked to remove, removed once the sheet has closed (a
    /// set done asks for a confirmation first, which cannot show while the sheet closes).
    @State private var removalAfterTypeSheet: UUID?
    /// Set once the session is finished or discarded, so the view stops reading it.
    @State private var isClosed = false
    @State private var errorMessage: String?

    private struct TypeSheetTarget: Identifiable {
        let id: UUID
        let number: Int
        let type: SetType
    }

    private enum FinishSheetAction {
        case finish(SessionEnd)
        case discard
    }

    private var service: SessionService {
        SessionService(context: context)
    }

    var body: some View {
        if isClosed {
            Theme.Colors.screenBackground.ignoresSafeArea()
        } else {
            content
        }
    }

    private var content: some View {
        let exercises = session.orderedExercises
        let setsByExercise = exercises.map(\.orderedSetLogs)
        let progress = SessionProgress(sets: setsByExercise)

        return NavigationStack {
            List {
                if exercises.isEmpty {
                    Text("Adicione exercícios para começar.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .accessibilityIdentifier("session.empty")
                        .cardListRow()
                }

                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, performed in
                    exerciseCard(
                        performed,
                        sets: setsByExercise[index],
                        isCurrent: progress.currentExerciseIndex == index,
                        currentSetID: progress.currentSetID
                    )
                }

                addExerciseButton
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
            // Below the header, which keeps "Concluir" in sight.
            .toast($toast)
            // The header and the rest bar stay in place, so, like the system's bars, they stop growing at
            // the first accessibility text size: with the largest ones they would leave the sets no room.
            .safeAreaInset(edge: .top, spacing: 0) {
                SessionHeader(
                    name: SessionFormatting.name(session.workoutNameSnapshot),
                    startedAt: session.startedAt,
                    volumeKg: SessionProgress.volumeKg(of: setsByExercise.flatMap { $0 }),
                    progress: progress,
                    onMinimize: minimize,
                    onDiscard: {
                        focusedField = nil
                        isConfirmingDiscard = true
                    },
                    onFinish: requestFinish
                )
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
            // The list ends above the rest bar, so the bar never covers its last rows. It steps aside
            // while a value is typed, leaving the keyboard's room to the field; the rest goes on.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if focusedField != nil {
                    // While typing, a margin above the keyboard: the list brings the field just above
                    // the keyboard, where the OK of the keyboard's bar would touch its lower edge.
                    Color.clear
                        .frame(height: 16)
                        .allowsHitTesting(false)
                } else if restTimer.isRunning(for: session.id) {
                    RestTimerBar(
                        timer: restTimer,
                        onAdd: { seconds in restTimer.add(seconds, at: .now) },
                        onSkip: { restTimer.stop() }
                    )
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("session.rest")
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") {
                        focusedField = nil
                    }
                }
            }
            .onChange(of: focusedField) { previous, _ in
                if let previous {
                    commit(previous.logID)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    commitAll()
                }
            }
            .task(id: exerciseIDs) {
                loadLastPerformances()
            }
            .task(id: restTimer.endsAt) {
                await endRestWhenOver()
            }
            .sensoryFeedback(.success, trigger: restsEnded)
            .sheet(item: $finishSummary, onDismiss: actAfterFinishSheet) { summary in
                FinishSessionSheet(
                    summary: summary,
                    onFinish: { (end: SessionEnd) in afterFinishSheet = .finish(end) },
                    onDiscard: { afterFinishSheet = .discard }
                )
            }
            .confirmationDialog("Descartar este treino?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Descartar", role: .destructive, action: discard)
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tudo o que foi registrado neste treino será apagado. O treino planejado não muda.")
            }
            .confirmationDialog("Remover esta série?", isPresented: isConfirmingSetRemoval, titleVisibility: .visible) {
                Button("Remover série", role: .destructive) {
                    if let log = setPendingRemoval {
                        setPendingRemoval = nil
                        remove(log)
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("A série já foi feita. Ela será apagada deste treino; o treino planejado não muda.")
            }
            .confirmationDialog("Remover este exercício?", isPresented: isConfirmingExerciseRemoval, titleVisibility: .visible) {
                Button("Remover exercício", role: .destructive) {
                    if let performed = exercisePendingRemoval {
                        exercisePendingRemoval = nil
                        remove(performed)
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("As séries já feitas dele serão apagadas deste treino; o treino planejado não muda.")
            }
            .sheet(item: $typeSheet, onDismiss: removeAfterTypeSheet) { target in
                SetTypeSheet(
                    number: target.number,
                    selected: target.type,
                    removalUnavailableReason: nil,
                    onChoose: { (type: SetType) in setType(type, ofSetWithID: target.id) },
                    onRemove: { removalAfterTypeSheet = target.id }
                )
            }
            .fullScreenCover(isPresented: $isPickingExercises) {
                ExercisePickerView(workoutExerciseIDs: Set(session.exercises.compactMap { $0.exercise?.id })) { exercises in
                    let added = try service.addExercises(exercises, to: session)
                    toast = ToastMessage(String(localized: "\(added.count) exercícios adicionados"))
                }
            }
            .errorAlert($errorMessage)
        }
    }

    /// The card of one exercise, with its "Última vez" and the screen's actions. Built here rather than
    /// in the list, so the compiler checks the call on its own.
    private func exerciseCard(_ performed: SessionExercise, sets: [SetLog], isCurrent: Bool, currentSetID: UUID?) -> SessionExerciseCard {
        let isFinished = SessionProgress.isFinished(sets)
        let previousSets: [PreviousSet] = performed.exercise.flatMap { lastPerformances[$0.id] } ?? []
        let isClosed = isFinished && !openedFinished.contains(performed.id)
        return SessionExerciseCard(
            performed: performed,
            sets: sets,
            previousSets: previousSets,
            isCurrent: isCurrent,
            currentSetID: currentSetID,
            isFinished: isFinished,
            isClosed: isClosed,
            focusedField: $focusedField,
            draft: { (log: SetLog) -> Binding<SetDraft> in draftBinding(for: log) },
            onToggle: { (log: SetLog, suggestion: SetSuggestion) in toggle(log, of: performed, suggestion: suggestion) },
            onAddSet: { addSet(to: performed) },
            onRemoveSet: { (log: SetLog) in requestRemoval(of: log) },
            onChooseType: { (log: SetLog, number: Int) in openTypeSheet(for: log, number: number) },
            onRemoveExercise: { requestRemoval(of: performed) },
            onOpenOrClose: { openOrClose(performed) }
        )
    }

    /// "+ Adicionar exercício", a dashed outline after the last card.
    private var addExerciseButton: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        return Button {
            isPickingExercises = true
        } label: {
            Label("Adicionar exercício", systemImage: "plus")
                .scaledFont(14, weight: .semibold)
                .foregroundStyle(Theme.Colors.lightAccent)
                .frame(maxWidth: .infinity, minHeight: 46)
                .overlay(shape.strokeBorder(Theme.Colors.controlBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("session.addExercise")
        .listRowInsets(EdgeInsets(
            top: 0,
            leading: Theme.Metrics.screenPadding,
            bottom: Theme.Metrics.screenPadding,
            trailing: Theme.Metrics.screenPadding
        ))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    /// The exercises of the session, for reading "Última vez" again when they change.
    private var exerciseIDs: [UUID] {
        session.exercises.compactMap { $0.exercise?.id }.sorted()
    }

    private var isConfirmingSetRemoval: Binding<Bool> {
        Binding(
            get: { setPendingRemoval != nil },
            set: { if !$0 { setPendingRemoval = nil } }
        )
    }

    private var isConfirmingExerciseRemoval: Binding<Bool> {
        Binding(
            get: { exercisePendingRemoval != nil },
            set: { if !$0 { exercisePendingRemoval = nil } }
        )
    }

    // MARK: - Typed values

    private func draftBinding(for log: SetLog) -> Binding<SetDraft> {
        Binding(
            get: { drafts[log.id] ?? SessionFormatting.draft(weightKg: log.weightKg, reps: log.reps) },
            set: { drafts[log.id] = $0 }
        )
    }

    private func setLog(id: UUID) -> SetLog? {
        for performed in session.exercises {
            if let log = performed.setLogs.first(where: { $0.id == id }) {
                return log
            }
        }
        return nil
    }

    /// Saves the typed values of a set, if they changed. Invalid values are not saved: the field
    /// shows the stored value again and the problem is reported. Returns whether nothing failed.
    @discardableResult
    private func commit(_ logID: UUID) -> Bool {
        guard let draft = drafts.removeValue(forKey: logID), let log = setLog(id: logID) else { return true }
        do {
            let values = try SessionFormatting.values(of: draft)
            guard values.weightKg != log.weightKg || values.reps != log.reps else { return true }
            try service.updateSetValues(log, weightKg: values.weightKg, reps: values.reps)
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    /// Saves every typed value. Returns whether nothing failed, so a failure is shown before the
    /// screen closes or the session is finished.
    @discardableResult
    private func commitAll() -> Bool {
        var succeeded = true
        for logID in Array(drafts.keys) {
            if !commit(logID) {
                succeeded = false
            }
        }
        return succeeded
    }

    // MARK: - Última vez

    /// Reads "Última vez" for the exercises of the session. Should the history fail to be read, the
    /// sets show "—" and suggest the plan; the session itself is not affected.
    private func loadLastPerformances() {
        do {
            lastPerformances = try service.lastPerformances(for: session)
        } catch {
            lastPerformances = [:]
            sessionLogger.error("Última vez could not be read: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Rest

    /// Ends the rest when it reaches zero, with a vibration. A rest that ended while the app was away
    /// (or the session minimized) just goes, without one.
    private func endRestWhenOver() async {
        guard restTimer.isRunning(for: session.id), let endsAt = restTimer.endsAt else { return }
        let wait = endsAt.timeIntervalSinceNow
        if wait > 0 {
            do {
                try await Task.sleep(for: .seconds(wait))
            } catch {
                // Cancelled: the rest changed, or the screen closed.
                return
            }
        }
        guard restTimer.endsAt == endsAt else { return }
        if endsAt.timeIntervalSinceNow > -2 {
            restsEnded += 1
        }
        restTimer.stop()
    }

    // MARK: - Actions

    /// Checks a set or unchecks it. Checking records what is typed, and the suggestion for a field left
    /// empty (the values in gray), and starts the rest.
    private func toggle(_ log: SetLog, of performed: SessionExercise, suggestion: SetSuggestion) {
        do {
            if log.isCompleted {
                try service.uncompleteSet(log)
                // Once finished again, the exercise closes again.
                openedFinished.remove(performed.id)
                return
            }
            let draft = drafts[log.id] ?? SessionFormatting.draft(weightKg: log.weightKg, reps: log.reps)
            let typed = try SessionFormatting.values(of: draft)
            let values = SessionFormatting.completionValues(typed: typed, suggestion: suggestion)
            guard let reps = values.reps else {
                throw SessionError.repsRequired
            }
            try service.completeSet(log, weightKg: values.weightKg, reps: reps)
            drafts[log.id] = nil
            if focusedField?.logID == log.id {
                focusedField = nil
            }
            restTimer.start(for: session.id, at: .now)
            if session.exercises.allSatisfy({ $0.setLogs.allSatisfy(\.isCompleted) }) {
                toast = ToastMessage(String(localized: "Todas as séries feitas. Toque em Concluir."))
            }
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func addSet(to performed: SessionExercise) {
        do {
            try service.addSetCopyingLast(to: performed)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// Opens the set type sheet of a set; what is typed is saved first.
    private func openTypeSheet(for log: SetLog, number: Int) {
        focusedField = nil
        commit(log.id)
        typeSheet = TypeSheetTarget(id: log.id, number: number, type: log.setType)
    }

    private func setType(_ type: SetType, ofSetWithID id: UUID) {
        guard let log = setLog(id: id) else { return }
        do {
            try service.setType(type, of: log)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// Removes the set "Remover série" of the type sheet asked for, as a swipe does: a set done is
    /// removed only after a confirmation.
    private func removeAfterTypeSheet() {
        guard let id = removalAfterTypeSheet else { return }
        removalAfterTypeSheet = nil
        if let log = setLog(id: id) {
            requestRemoval(of: log)
        }
    }

    /// Opens a finished exercise, or closes it again.
    private func openOrClose(_ performed: SessionExercise) {
        withAnimation(.snappy) {
            if openedFinished.contains(performed.id) {
                openedFinished.remove(performed.id)
            } else {
                openedFinished.insert(performed.id)
            }
        }
    }

    /// Removes a set; one already done is removed only after a confirmation.
    private func requestRemoval(of log: SetLog) {
        if log.isCompleted {
            setPendingRemoval = log
        } else {
            remove(log)
        }
    }

    private func remove(_ log: SetLog) {
        drafts[log.id] = nil
        if focusedField?.logID == log.id {
            focusedField = nil
        }
        do {
            try service.removeSet(log)
            toast = ToastMessage(String(localized: "Série removida"))
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// Removes an exercise; one with sets done is removed only after a confirmation.
    private func requestRemoval(of performed: SessionExercise) {
        if performed.setLogs.contains(where: \.isCompleted) {
            exercisePendingRemoval = performed
        } else {
            remove(performed)
        }
    }

    private func remove(_ performed: SessionExercise) {
        let logIDs = Set(performed.setLogs.map(\.id))
        drafts = drafts.filter { !logIDs.contains($0.key) }
        if let field = focusedField, logIDs.contains(field.logID) {
            focusedField = nil
        }
        openedFinished.remove(performed.id)
        do {
            try service.removeExercise(performed)
            toast = ToastMessage(String(localized: "Exercício removido do treino"))
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func minimize() {
        focusedField = nil
        guard commitAll() else { return }
        onClose()
    }

    /// "Concluir": saves what was typed, then shows "Concluir treino?" with what the session did, or
    /// "Nenhuma série marcada" without any set done. Nothing is saved before its "Concluir e salvar".
    private func requestFinish() {
        focusedField = nil
        guard commitAll() else { return }
        finishSummary = SessionFinishSummary(
            sets: session.exercises.flatMap(\.setLogs),
            startedAt: session.startedAt,
            now: .now,
            suggestedEnd: service.suggestedEnd(for: session)
        )
    }

    /// Finishes or discards once "Concluir treino?" has closed, as its button asked; a confirmation
    /// cannot show while the sheet closes.
    private func actAfterFinishSheet() {
        guard let action = afterFinishSheet else { return }
        afterFinishSheet = nil
        switch action {
        case .finish(let end):
            finish(endingAt: end)
        case .discard:
            isConfirmingDiscard = true
        }
    }

    private func finish(endingAt end: SessionEnd) {
        // Read before finishing, which keeps only the sets done.
        let sets = session.exercises.flatMap(\.setLogs)
        let saved = SessionFinishSummary.savedText(
            doneSets: sets.filter(\.isCompleted).count,
            volumeKg: SessionProgress.volumeKg(of: sets)
        )
        do {
            try service.finishSession(session, endingAt: end)
            isClosed = true
            restTimer.stop()
            rootFeedback?.show(saved)
            onClose()
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func discard() {
        isClosed = true
        do {
            try service.discardSession(session)
            drafts = [:]
            restTimer.stop()
            rootFeedback?.show(String(localized: "Treino descartado"))
            onClose()
        } catch {
            isClosed = false
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
