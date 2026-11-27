import SwiftData
import SwiftUI

/// The Exercícios tab: the 103 base exercises of the library and the exercises of the user's own, in one
/// alphabetical list, with a search, the group filters ("Todos", "Meus" and the muscle groups) and the
/// equipment of the chosen group (a base by its common equipment). "Montar treino" at the top (not while
/// searching) opens the picker to build a workout or add to one. "Limpar filtros" goes back to "Todos"
/// without equipment and keeps the search. "+ Novo" (and "+ Criar" when the search finds nothing) opens the
/// form of a new exercise with the filters on; once created, its screen opens. In "Meus", without a search
/// or an equipment, the archived exercises of the user's own come at the end. A row opens the exercise
/// screen (a base on the combination done last, or on its first), with the tab bar still there; tapping the
/// tab again goes back to the list.
struct ExerciseListView: View {
    /// The exercises of the user's own, the archived ones too: an archived one is listed in "Meus", and its
    /// screen stays open once it is archived.
    @Query(filter: #Predicate<Exercise> { $0.isCustom }) private var customs: [Exercise]
    @Environment(\.modelContext) private var context
    @Environment(\.openWorkoutEditor) private var openWorkoutEditor
    /// The rows built from the exercises of the user's own, kept until one of them changes: typing a search
    /// or choosing a filter does not build them again. The bases are built once for all.
    @State private var cache = ExerciseCatalogCache()
    /// When each combination was last done, and the hidden ones, read when the tab appears.
    @State private var lastDone = ExerciseLastDone()
    @State private var hiddenKeys: Set<String> = []
    @State private var searchText = ""
    @State private var chosenGroup: ExerciseCatalog.GroupFilter = .all
    @State private var chosenEquipment: Equipment?
    /// The form of a new exercise, while it is open.
    @State private var newExerciseForm: NewExerciseForm?
    /// The exercise just created, opened once the form has closed.
    @State private var createdExercise: Exercise?
    @State private var openedExercise: Exercise?
    /// "Montar treino": the picker that builds a workout.
    @State private var isBuildingWorkout = false
    @State private var errorMessage: String?
    /// Shows "Exercício criado" and the notices of "Adicionar a um treino".
    @Environment(RootFeedback.self) private var rootFeedback: RootFeedback?

    private struct NewExerciseForm: Identifiable {
        let id = UUID()
        let form: ExerciseForm
    }

    var body: some View {
        let lists = cache.lists(for: customs)
        let items = lists.active
        let hasArchivedCustom = !lists.archived.isEmpty
        let group = ExerciseCatalog.groupFilter(chosenGroup, in: items, hasArchivedCustom: hasArchivedCustom)
        let equipmentChoices = ExerciseCatalog.equipment(for: group, in: items)
        let equipment = ExerciseCatalog.equipment(chosenEquipment, for: group, in: items)
        let shown = ExerciseCatalog.filtered(items, group: group, equipment: equipment, search: searchText)
        let archived = ExerciseCatalog.archivedShown(lists.archived, group: group, equipment: equipment, search: searchText)
        // With only archived exercises to show, they take the list's place, as in the prototype.
        let showsCount = ExerciseCatalog.isFiltering(group: group, equipment: equipment) && !(shown.isEmpty && !archived.isEmpty)
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // "Montar treino" with the rows, as the prototype's list; not while searching or with nothing found.
        let showsBuild = !isSearching && !shown.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(total: items.count)
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                ExerciseFilterBar(
                    items: items,
                    group: group,
                    equipmentChoices: equipmentChoices,
                    equipment: equipment,
                    searchText: $searchText,
                    chosenGroup: $chosenGroup,
                    chosenEquipment: $chosenEquipment,
                    identifierPrefix: "exercises",
                    hasArchivedCustom: hasArchivedCustom
                )
                .padding(.top, 14)
                if showsBuild {
                    buildRow
                        .padding(.horizontal, Theme.Metrics.screenPadding)
                        .padding(.top, 14)
                }
                if showsCount {
                    countRow(shown.count)
                        .padding(.horizontal, Theme.Metrics.screenPadding)
                        // 10 below the filters, as in the prototype; 4 below "Montar treino".
                        .padding(.top, showsBuild ? 4 : 10)
                }
                VStack(alignment: .leading, spacing: 0) {
                    if !(shown.isEmpty && !archived.isEmpty) {
                        cards(shown, group: group, equipment: equipment)
                    }
                    if !archived.isEmpty {
                        archivedSection(archived)
                            .padding(.top, 26)
                    }
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                // The prototype's 8 below the count and below "Montar treino", 14 below the filters.
                .padding(.top, showsCount || showsBuild ? 8 : 14)
            }
            .padding(.top, 16)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear(perform: readUsage)
        .navigationDestination(for: ExerciseRoute.self) { route in
            if let exercise = customs.first(where: { $0.id == route.exerciseID }) {
                ExerciseDetailView(exercise: exercise, origin: .exercises)
            }
        }
        .navigationDestination(for: ExerciseBaseRoute.self) { route in
            if let exercise = try? LibraryRecords.record(forKey: route.key, in: context) {
                ExerciseDetailView(exercise: exercise, origin: .exercises)
            }
        }
        .navigationDestination(item: $openedExercise) { exercise in
            ExerciseDetailView(exercise: exercise, origin: .exercises)
        }
        .fullScreenCover(item: $newExerciseForm, onDismiss: openCreatedExercise) { request in
            ExerciseFormView(form: request.form) { exercise in
                createdExercise = exercise
            }
        }
        .fullScreenCover(isPresented: $isBuildingWorkout) {
            ExercisePickerView(buildingWorkout: finishBuilding)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .errorAlert($errorMessage)
    }

    /// The rows left, or the card that says none was found.
    private func cards(_ shown: [ExerciseCatalog.Item], group: ExerciseCatalog.GroupFilter, equipment: Equipment?) -> some View {
        LazyVStack(spacing: 8) {
            if shown.isEmpty {
                let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                ExerciseEmptyCard(spacing: 8, search: search) {
                    openForm(name: search, group: group, equipment: equipment)
                }
            } else {
                ForEach(shown) { (item: ExerciseCatalog.Item) in
                    row(item)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: ExerciseCatalog.Item) -> some View {
        if let base = item.base {
            let opening = lastDone.openingCombination(of: base, hiddenKeys: hiddenKeys)
            NavigationLink(value: ExerciseBaseRoute(key: opening?.key ?? "")) {
                ExerciseCard(item: item, iconEquipment: opening?.equipment)
            }
            .buttonStyle(.plain)
            .disabled(opening == nil)
        } else if let id = item.exerciseID {
            NavigationLink(value: ExerciseRoute(exerciseID: id)) {
                ExerciseCard(item: item)
            }
            .buttonStyle(.plain)
        }
    }

    /// "Montar treino": the white + on its square, what it does, and the ›. Opens the picker that builds a
    /// workout.
    private var buildRow: some View {
        Button {
            guard !isBuildingWorkout else { return }
            isBuildingWorkout = true
        } label: {
            HStack(spacing: 12) {
                AppIcon(.plus, size: 16)
                    .foregroundStyle(Theme.Colors.primaryButtonText)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.primaryButton, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Montar treino")
                        .scaledFont(14, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                    Text("Escolha os exercícios e crie um treino ou adicione a um que já existe")
                        .scaledFont(11, lineHeight: 1.35, webKitLine: true)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AppIcon(.chevronRightList, size: 13)
                    .foregroundStyle(Theme.Colors.futureDayText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exercises.build")
    }

    /// ARQUIVADOS, how many, what it means, and the archived exercises of the user's own.
    private func archivedSection(_ archived: [ExerciseCatalog.Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle("Arquivados", webKitLine: true)
                Spacer(minLength: 8)
                Text(verbatim: "\(archived.count)")
                    .scaledFont(12)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .monospacedDigit()
                    .accessibilityLabel(Text(verbatim: ExerciseCatalog.countText(archived.count)))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("exercises.archived.title")
            Text("Não aparecem na lista nem para adicionar a um treino. Toque para ver o histórico ou restaurar.")
                .scaledFont(12, lineHeight: 1.4, webKitLine: true)
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            LazyVStack(spacing: 8) {
                ForEach(archived) { (item: ExerciseCatalog.Item) in
                    row(item)
                }
            }
            .padding(.top, 10)
        }
    }

    /// "Exercícios" and how many active exercises there are, with "+ Novo" on the right.
    private func header(total: Int) -> some View {
        let titles = VStack(alignment: .leading, spacing: 3) {
            Text("Exercícios")
                .scaledFont(29, weight: .heavy, lineHeight: 1.05)
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: ExerciseCatalog.countText(total))
                .scaledFont(13)
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityIdentifier("exercises.total")
        }
        let newButton = Button {
            let lists = cache.lists(for: customs)
            let group = ExerciseCatalog.groupFilter(chosenGroup, in: lists.active, hasArchivedCustom: !lists.archived.isEmpty)
            openForm(name: "", group: group, equipment: ExerciseCatalog.equipment(chosenEquipment, for: group, in: lists.active))
        } label: {
            HStack(spacing: 5) {
                AppIcon(.plus, size: 14)
                Text("Novo")
                    .scaledFont(13, weight: .bold)
            }
            .foregroundStyle(Theme.Colors.primaryButtonText)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(Theme.Colors.primaryButton, in: Capsule())
            // 3 more points above and below respond to touches, for a 44-point touch area.
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Novo exercício"))
        .accessibilityIdentifier("exercises.new")

        // Side by side when they fit, the button aligned with the bottom of the titles; with the
        // largest text sizes the button goes below the title.
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                titles
                Spacer(minLength: 8)
                newButton
                    .padding(.bottom, -3)
            }
            VStack(alignment: .leading, spacing: 12) {
                titles
                newButton
            }
        }
    }

    /// How many exercises the filters leave, and "Limpar filtros".
    private func countRow(_ count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: ExerciseCatalog.countText(count))
                .scaledFont(11, webKitLine: true)
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityIdentifier("exercises.count")
            Spacer(minLength: 8)
            Button {
                chosenGroup = .all
                chosenEquipment = nil
            } label: {
                Text("Limpar filtros")
                    .scaledFont(11, weight: .bold, webKitLine: true)
                    .foregroundStyle(Theme.Colors.lightAccent)
                    // The touch area grows to 44 points without taking room.
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -15)
            .accessibilityIdentifier("exercises.clearFilters")
        }
    }

    /// The form of a new exercise with the search typed and the group and equipment of the filters on
    /// ("Meus" is no group).
    private func openForm(name: String, group: ExerciseCatalog.GroupFilter, equipment: Equipment?) {
        // A second tap while the form is opening would open it again, losing what was typed.
        guard newExerciseForm == nil else { return }
        var muscleGroup: MuscleGroup?
        if case .group(let chosen) = group {
            muscleGroup = chosen
        }
        newExerciseForm = NewExerciseForm(form: ExerciseForm(name: name, group: muscleGroup, equipment: equipment))
    }

    /// The screen of the exercise just created, with "Exercício criado", once the form has closed.
    private func openCreatedExercise() {
        guard let createdExercise else { return }
        self.createdExercise = nil
        openedExercise = createdExercise
        rootFeedback?.show(String(localized: "Exercício criado"))
    }

    /// When each combination was last done and which are hidden, read when the tab appears (and when it comes
    /// back from a screen over it): the icon of a base and the combination its screen opens on.
    private func readUsage() {
        do {
            lastDone = try ExerciseLastDone.read(in: context)
            hiddenKeys = try LibraryRecords.hiddenKeys(in: context)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// "Montar treino" added to a workout, or created one: its notice and, for a new one, its editor.
    private func finishBuilding(_ outcome: AddToWorkoutOutcome) {
        rootFeedback?.show(outcome.notice)
        if case .created(let workout, _) = outcome {
            openWorkoutEditor(workout)
        }
    }
}
