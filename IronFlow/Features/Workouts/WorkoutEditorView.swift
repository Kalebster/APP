import SwiftData
import SwiftUI

/// A planned workout, created or edited on one screen: every exercise with its planned sets, edited in
/// place. The number of a set shows its type and opens the set type sheet; "+ Adicionar série" copies
/// the last set; the menus rename, reorder and delete; "Iniciar" starts the workout.
///
/// Every change is saved right away. A typed value is saved when its field loses focus, with the
/// keyboard's OK, when the screen closes, when the workout starts or when the app leaves the
/// foreground; never at each key. The sets are rows of a list, which creates and reuses rows as they
/// scroll: typed values are kept here (`drafts`), never in a row, so one that scrolls out of sight is
/// still saved.
struct WorkoutEditorView: View {
    let workout: Workout
    /// Starts the workout ("Iniciar"), with the same rules as the ▶ of the Treinos tab.
    let sessionActions: SessionActions

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// Typed values not saved yet, by field.
    @State private var drafts: [PlannedSetField: String] = [:]
    @FocusState private var focusedField: PlannedSetField?
    @State private var isOrdering = false
    @State private var isPickingExercises = false
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    /// The exercise about to be removed, with its name taken when the question was asked.
    @State private var removal: PendingRemoval?
    /// The planned set whose type sheet is open.
    @State private var typeSheet: TypeSheetTarget?
    /// Counts the times the range of a set was adjusted, so the notice shows again each time.
    @State private var rangeNotices = 0
    @State private var isShowingRangeNotice = false
    /// Set right before the workout is deleted, so the view stops reading it.
    @State private var isDeleted = false
    @State private var errorMessage: String?

    @ScaledMetric(relativeTo: .body) private var menuSide: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var addExercisesHeight: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var startHeight: CGFloat = 46

    private struct PendingRemoval {
        let item: WorkoutExercise
        let name: String
    }

    private struct TypeSheetTarget: Identifiable {
        let id: UUID
        let number: Int
        let type: SetType
        let canRemove: Bool
    }

    private var service: WorkoutService {
        WorkoutService(context: context)
    }

    var body: some View {
        if isDeleted {
            Theme.Colors.screenBackground.ignoresSafeArea()
        } else {
            editor
        }
    }

    private var editor: some View {
        let items = workout.orderedExercises
        let setsByItem = items.map(\.orderedPlannedSets)

        return List {
            listContent(items: items, setsByItem: setsByItem)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .environment(\.editMode, .constant(isOrdering ? .active : .inactive))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar(canReorder: items.count > 1)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focusedField != nil {
                // While typing, a margin above the keyboard, as in the session.
                Color.clear
                    .frame(height: 16)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if isShowingRangeNotice {
                rangeNotice
            }
        }
        .screenBackground()
        // The navigation bar is hidden for the model's own top row; the swipe back stays.
        .background(InteractivePopEnabler())
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
                commit(previous)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                commitAll()
            }
        }
        .onChange(of: items.count) { _, count in
            if count < 2 {
                isOrdering = false
            }
        }
        .onDisappear {
            commitAll()
        }
        .task(id: rangeNotices) {
            guard rangeNotices > 0 else { return }
            do {
                try await Task.sleep(for: .seconds(4))
            } catch {
                // Cancelled by a newer notice, which hides itself.
                return
            }
            withAnimation {
                isShowingRangeNotice = false
            }
        }
        .sheet(item: $typeSheet) { target in
            SetTypeSheet(
                number: target.number,
                selected: target.type,
                removalUnavailableReason: target.canRemove ? nil : String(localized: "O exercício precisa ter pelo menos 1 série."),
                onChoose: { (type: SetType) in setType(type, ofSetWithID: target.id) },
                onRemove: { removeSet(withID: target.id) }
            )
        }
        .fullScreenCover(isPresented: $isPickingExercises) {
            ExercisePickerView(workoutExerciseIDs: Set(workout.exercises.compactMap { $0.exercise?.id })) { exercises in
                try service.addExercises(exercises, to: workout)
            }
        }
        .sheet(isPresented: $isRenaming) {
            WorkoutNameSheet(title: "Renomear treino", initialName: workout.name) { name in
                try service.rename(workout, to: name)
            }
        }
        .errorAlert($errorMessage)
    }

    // MARK: - Rows

    /// The rows of the list: the title, then the exercises to reorder, the empty card, or the legend,
    /// the exercise cards and the buttons at the end.
    @ViewBuilder
    private func listContent(items: [WorkoutExercise], setsByItem: [[PlannedSet]]) -> some View {
        titleRow(items: items, setCount: setsByItem.reduce(0) { $0 + $1.count })

        if isOrdering {
            ForEach(items) { (item: WorkoutExercise) in
                orderingRow(item)
            }
            .onMove(perform: moveExercises)
        } else if items.isEmpty {
            EditorEmptyCard {
                isPickingExercises = true
            }
            .editorRow(top: 2, bottom: 0)
        } else {
            SetTypeLegend()
                .editorRow(top: 12, bottom: 14)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                exerciseCard(item, sets: setsByItem[index], canReorder: items.count > 1)
            }
            bottomButtons
        }
    }

    /// "‹ Treinos" and the ⋯ menu, or "Concluir" while the exercises are reordered. It stays in place.
    private func topBar(canReorder: Bool) -> some View {
        HStack(spacing: 8) {
            Button(action: goBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .scaledFont(17, weight: .semibold)
                    Text("Treinos")
                        .scaledFont(17)
                }
                .foregroundStyle(Theme.Colors.lightAccent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.back")
            Spacer(minLength: 8)
            if isOrdering {
                Button {
                    withAnimation {
                        isOrdering = false
                    }
                } label: {
                    Text("Concluir")
                        .scaledFont(15, weight: .bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 32)
                        .background(Color.accentColor, in: Capsule())
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workout.ordering.done")
            } else {
                Menu {
                    Button("Renomear treino", systemImage: "pencil") {
                        focusedField = nil
                        isRenaming = true
                    }
                    if canReorder {
                        Button("Ordenar exercícios", systemImage: "arrow.up.arrow.down", action: startOrdering)
                    }
                    Button("Excluir treino", systemImage: "trash", role: .destructive) {
                        focusedField = nil
                        isConfirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .scaledFont(14, weight: .bold)
                        .foregroundStyle(Theme.Colors.mediumText)
                        .frame(width: menuSide, height: menuSide)
                        .background(Theme.Colors.cardBackground, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
                        .frame(width: max(44, menuSide), height: max(44, menuSide))
                        .contentShape(Rectangle())
                }
                .padding(.trailing, min(0, (menuSide - 44) / 2))
                .accessibilityLabel(Text("Opções do treino"))
                .accessibilityIdentifier("workout.menu")
                // On the ⋯ itself, so the confirmation points to the button it came from.
                .confirmationDialog(
                    Text("Excluir “\(workout.name)”?"),
                    isPresented: $isConfirmingDelete,
                    titleVisibility: .visible
                ) {
                    Button("Excluir", role: .destructive, action: deleteWorkout)
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("O histórico dos treinos já feitos continua salvo. Não dá para desfazer.")
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .background(Theme.Colors.screenBackground)
    }

    /// The workout's name and "4 exercícios · 15 séries", or "Nenhum exercício ainda".
    private func titleRow(items: [WorkoutExercise], setCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(workout.name)
                .scaledFont(29, weight: .heavy)
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("workout.title")
            Text(verbatim: items.isEmpty
                ? String(localized: "Nenhum exercício ainda")
                : WorkoutListSummary.cardSummary(exercises: items.count, sets: setCount))
                .scaledFont(13)
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityIdentifier("workout.summary")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorRow(top: 6, bottom: 14)
    }

    /// The rows of one exercise, drawn as one card: its header, the set columns, the sets and
    /// "+ Adicionar série". Built here rather than in the list, so the compiler checks it on its own.
    private func exerciseCard(_ item: WorkoutExercise, sets: [PlannedSet], canReorder: Bool) -> some View {
        // A group, so the list takes each of these as its own row.
        Group {
            EditorExerciseHeader(
                item: item,
                canReorder: canReorder,
                isConfirmingRemoval: isConfirmingRemoval(of: item),
                removalName: removal.flatMap { $0.item.id == item.id ? $0.name : nil } ?? EditorExerciseInfo.name(of: item.exercise),
                onReorder: startOrdering,
                onRemove: { confirmRemoval(of: item) },
                onConfirmRemoval: confirmedRemoval
            )
            .cardSegmentRow(.top, gap: editorCardGap)
            PlannedSetColumns()
                .cardSegmentRow(.middle, gap: editorCardGap)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, plannedSet in
                PlannedSetRow(
                    number: index + 1,
                    plannedSet: plannedSet,
                    text: { (field: PlannedSetField) -> Binding<String> in text(of: field, in: plannedSet) },
                    focusedField: $focusedField
                ) {
                    openTypeSheet(for: plannedSet, number: index + 1, setCount: sets.count)
                }
                .cardSegmentRow(.middle, gap: editorCardGap)
            }
            EditorAddSetRow {
                addSet(to: item)
            }
            .cardSegmentRow(.bottom, gap: editorCardGap)
        }
    }

    /// An exercise while reordering: a card of its own with the list's drag handle inside it.
    private func orderingRow(_ item: WorkoutExercise) -> some View {
        EditorOrderingRow(item: item)
            .listRowInsets(EdgeInsets(
                top: 6,
                leading: Theme.Metrics.screenPadding + 12,
                bottom: 6,
                trailing: Theme.Metrics.screenPadding + 4
            ))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.Colors.cardBackground)
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.vertical, 6)
            )
    }

    /// "Adicionar exercícios", dashed, and "▶ Iniciar <nome>".
    private var bottomButtons: some View {
        let dashed = RoundedRectangle(cornerRadius: 13, style: .continuous)
        return VStack(spacing: 10) {
            Button {
                focusedField = nil
                isPickingExercises = true
            } label: {
                Label("Adicionar exercícios", systemImage: "plus")
                    .scaledFont(13, weight: .bold)
                    .foregroundStyle(Theme.Colors.lightAccent)
                    .frame(maxWidth: .infinity, minHeight: addExercisesHeight)
                    .overlay(dashed.strokeBorder(Theme.Colors.dashedBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    .contentShape(dashed)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.addExercises")

            Button(action: start) {
                Label {
                    Text("Iniciar \(workout.name)")
                } icon: {
                    Image(systemName: "play.fill")
                }
                .scaledFont(15, weight: .bold)
                .foregroundStyle(Theme.Colors.screenBackground)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: startHeight)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.start")
        }
        .editorRow(top: 2, bottom: Theme.Metrics.screenPadding)
    }

    /// "O máximo não pode ser menor que o mínimo.", for a few seconds after the range of a set was adjusted.
    private var rangeNotice: some View {
        Text("O máximo não pode ser menor que o mínimo.")
            .scaledFont(13, weight: .semibold)
            .foregroundStyle(Theme.Colors.brightText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.Colors.setFieldBackground, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Colors.cardBorder, lineWidth: 1))
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 12)
            .transition(.opacity)
            .accessibilityIdentifier("workout.rangeNotice")
    }

    /// Whether the question before removing is open for `item`.
    private func isConfirmingRemoval(of item: WorkoutExercise) -> Binding<Bool> {
        Binding(
            get: { removal?.item.id == item.id },
            set: { if !$0 { removal = nil } }
        )
    }

    // MARK: - Typed values

    /// The text of a field: what is being typed, or the stored value.
    private func text(of field: PlannedSetField, in plannedSet: PlannedSet) -> Binding<String> {
        Binding(
            get: { drafts[field] ?? PlannedSetEditing.text(of: field.kind, in: PlannedSetValues(plannedSet)) },
            set: { drafts[field] = $0 }
        )
    }

    private func plannedSet(withID id: UUID) -> PlannedSet? {
        for item in workout.exercises {
            if let plannedSet = item.plannedSets.first(where: { $0.id == id }) {
                return plannedSet
            }
        }
        return nil
    }

    /// Saves what was typed in a field, if it changed the set. Invalid values are not saved: the field
    /// shows the stored value again and the problem is reported. A maximum left below the minimum (or the
    /// other way round) moves the other value and shows a short notice.
    private func commit(_ field: PlannedSetField) {
        guard let typed = drafts.removeValue(forKey: field), let plannedSet = plannedSet(withID: field.setID) else { return }
        let stored = PlannedSetValues(plannedSet)
        do {
            let outcome = try PlannedSetEditing.outcome(editing: field.kind, text: typed, stored: stored)
            guard outcome.values != stored else { return }
            try service.updatePlannedSet(plannedSet, values: outcome.values)
            if outcome.rangeWasAdjusted {
                showRangeNotice()
            }
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// Saves every typed value.
    private func commitAll() {
        for field in Array(drafts.keys) {
            commit(field)
        }
    }

    private func showRangeNotice() {
        withAnimation {
            isShowingRangeNotice = true
        }
        rangeNotices += 1
        AccessibilityNotification.Announcement(String(localized: "O máximo não pode ser menor que o mínimo.")).post()
    }

    // MARK: - Actions

    private func goBack() {
        focusedField = nil
        commitAll()
        dismiss()
    }

    private func start() {
        focusedField = nil
        commitAll()
        sessionActions.start(workout)
    }

    private func startOrdering() {
        focusedField = nil
        commitAll()
        withAnimation {
            isOrdering = true
        }
    }

    private func openTypeSheet(for plannedSet: PlannedSet, number: Int, setCount: Int) {
        focusedField = nil
        commitAll()
        typeSheet = TypeSheetTarget(id: plannedSet.id, number: number, type: plannedSet.setType, canRemove: setCount > 1)
    }

    private func setType(_ type: SetType, ofSetWithID id: UUID) {
        guard let plannedSet = plannedSet(withID: id) else { return }
        do {
            try service.setType(type, of: plannedSet)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func removeSet(withID id: UUID) {
        guard let plannedSet = plannedSet(withID: id) else { return }
        drafts = drafts.filter { $0.key.setID != id }
        do {
            try service.removePlannedSet(plannedSet)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func addSet(to item: WorkoutExercise) {
        focusedField = nil
        commitAll()
        do {
            try service.addPlannedSetCopyingLast(to: item)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func confirmRemoval(of item: WorkoutExercise) {
        focusedField = nil
        commitAll()
        removal = PendingRemoval(item: item, name: EditorExerciseInfo.name(of: item.exercise))
    }

    /// "Remover do treino" in the question: removes the exercise it was asked about.
    private func confirmedRemoval() {
        guard let item = removal?.item else { return }
        removal = nil
        removeExercise(item)
    }

    private func removeExercise(_ item: WorkoutExercise) {
        let setIDs = Set(item.plannedSets.map(\.id))
        drafts = drafts.filter { !setIDs.contains($0.key.setID) }
        do {
            try service.removeExercise(item)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        do {
            try service.moveExercises(in: workout, fromOffsets: source, toOffset: destination)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func deleteWorkout() {
        drafts = [:]
        isDeleted = true
        do {
            try service.delete(workout)
            dismiss()
        } catch {
            isDeleted = false
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

private extension View {
    /// A row of the editor outside the exercise cards: the screen margins, no separator, no background.
    func editorRow(top: CGFloat, bottom: CGFloat) -> some View {
        listRowInsets(EdgeInsets(
            top: top,
            leading: Theme.Metrics.screenPadding,
            bottom: bottom,
            trailing: Theme.Metrics.screenPadding
        ))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
