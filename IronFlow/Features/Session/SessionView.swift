import SwiftData
import SwiftUI

/// The session in progress: its exercises and sets, adding exercises and sets, finishing and
/// discarding. Every change is saved right away; a typed value is saved when its field loses
/// focus, when the set is checked, or when the screen is minimized or the app leaves the foreground.
/// Changes here touch only the session, never the planned workout.
struct SessionView: View {
    let session: Session
    /// Closes the screen (minimized, finished or discarded).
    let onClose: @MainActor () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    /// Typed values not saved yet, by set id.
    @State private var drafts: [UUID: SetDraft] = [:]
    @FocusState private var focusedField: SetField?
    @State private var isPickingExercises = false
    @State private var isConfirmingFinish = false
    @State private var isConfirmingDiscard = false
    /// Set once the session is finished or discarded, so the view stops reading it.
    @State private var isClosed = false
    @State private var errorMessage: String?

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
        let notCompletedCount = exercises.reduce(0) { $0 + $1.setLogs.filter { !$0.isCompleted }.count }

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
                    header
                        .padding(.bottom, 4)

                    if exercises.isEmpty {
                        Text("Adicione exercícios para começar.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .accessibilityIdentifier("session.empty")
                    }

                    ForEach(exercises) { performed in
                        SessionExerciseCard(
                            performed: performed,
                            focusedField: $focusedField,
                            draft: draftBinding,
                            onToggle: toggle
                        ) {
                            addSet(to: performed)
                        }
                    }

                    Button {
                        isPickingExercises = true
                    } label: {
                        Label("Adicionar exercício", systemImage: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session.addExercise")

                    Button(role: .destructive) {
                        focusedField = nil
                        isConfirmingDiscard = true
                    } label: {
                        Text("Descartar treino")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .accessibilityIdentifier("session.discard")
                }
                .padding(Theme.Metrics.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: minimize) {
                        Label("Minimizar", systemImage: "chevron.down")
                    }
                    .accessibilityIdentifier("session.minimize")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir", action: requestFinish)
                        .accessibilityIdentifier("session.finish")
                }
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
            .confirmationDialog("Concluir treino?", isPresented: $isConfirmingFinish, titleVisibility: .visible) {
                Button("Concluir treino", action: finish)
                Button("Cancelar", role: .cancel) {}
            } message: {
                if notCompletedCount == 1 {
                    Text("1 série não foi concluída e ficará registrada como não feita.")
                } else {
                    Text("\(notCompletedCount) séries não foram concluídas e ficarão registradas como não feitas.")
                }
            }
            .confirmationDialog("Descartar este treino?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Descartar", role: .destructive, action: discard)
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tudo o que foi registrado neste treino será apagado. O treino planejado não muda.")
            }
            .sheet(isPresented: $isPickingExercises) {
                ExercisePickerView(workoutExerciseIDs: Set(session.exercises.compactMap { $0.exercise?.id })) { exercises in
                    try service.addExercises(exercises, to: session)
                }
            }
            .errorAlert($errorMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(SessionFormatting.name(session.workoutNameSnapshot))
                .font(.title2.weight(.heavy))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("session.name")
            TimelineView(.periodic(from: session.startedAt, by: 1)) { timeline in
                Label(SessionFormatting.elapsedText(from: session.startedAt, to: timeline.date), systemImage: "timer")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("session.elapsed")
        }
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
    /// shows the stored value again and the problem is reported.
    private func commit(_ logID: UUID) {
        guard let draft = drafts.removeValue(forKey: logID), let log = setLog(id: logID) else { return }
        do {
            let values = try SessionFormatting.values(of: draft)
            guard values.weightKg != log.weightKg || values.reps != log.reps else { return }
            try service.updateSetValues(log, weightKg: values.weightKg, reps: values.reps)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func commitAll() {
        for logID in Array(drafts.keys) {
            commit(logID)
        }
    }

    // MARK: - Actions

    /// Checks a set with the typed values (empty repetitions take the target), or unchecks it.
    private func toggle(_ log: SetLog) {
        do {
            if log.isCompleted {
                try service.uncompleteSet(log)
                return
            }
            let draft = drafts[log.id] ?? SessionFormatting.draft(weightKg: log.weightKg, reps: log.reps)
            let values = try SessionFormatting.values(of: draft)
            guard let reps = SessionFormatting.repsForCompletion(
                typed: values.reps,
                targetMin: log.targetRepsMin,
                targetMax: log.targetRepsMax
            ) else {
                throw SessionError.repsRequired
            }
            try service.completeSet(log, weightKg: values.weightKg, reps: reps)
            drafts[log.id] = nil
            if focusedField?.logID == log.id {
                focusedField = nil
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

    private func minimize() {
        focusedField = nil
        commitAll()
        onClose()
    }

    private func requestFinish() {
        focusedField = nil
        commitAll()
        let logs = session.exercises.flatMap(\.setLogs)
        guard logs.contains(where: \.isCompleted) else {
            errorMessage = UserFacingError.message(for: SessionError.noCompletedSets)
            return
        }
        if logs.contains(where: { !$0.isCompleted }) {
            isConfirmingFinish = true
        } else {
            finish()
        }
    }

    private func finish() {
        do {
            try service.finishSession(session)
            isClosed = true
            onClose()
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func discard() {
        drafts = [:]
        isClosed = true
        do {
            try service.discardSession(session)
            onClose()
        } catch {
            isClosed = false
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
