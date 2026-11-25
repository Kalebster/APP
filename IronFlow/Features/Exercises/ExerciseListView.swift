import SwiftData
import SwiftUI

/// The Exercícios tab: the active exercises in one alphabetical list, with a search, the group filters
/// ("Todos", "Meus" and the muscle groups) and the equipment of the chosen group. "Limpar filtros" goes
/// back to "Todos" without equipment and keeps the search. "+ Novo" (and "+ Criar" when the search finds
/// nothing) opens the form of a new exercise with the filters on; once created, its screen opens. In
/// "Meus", without a search or an equipment, the archived exercises of the user's own come at the end. A
/// row opens the exercise screen, with the tab bar still there; tapping the tab again goes back to the list.
struct ExerciseListView: View {
    /// Every exercise, the archived ones too: an archived exercise of the user's own is listed in "Meus",
    /// and its screen stays open once it is archived.
    @Query private var exercises: [Exercise]
    /// The items built from the exercises, kept until one of them changes: typing a search or choosing a
    /// filter does not build them again.
    @State private var cache = ExerciseCatalogCache()
    @State private var searchText = ""
    @State private var chosenGroup: ExerciseCatalog.GroupFilter = .all
    @State private var chosenEquipment: Equipment?
    /// The form of a new exercise, while it is open.
    @State private var newExerciseForm: NewExerciseForm?
    /// The exercise just created, opened once the form has closed.
    @State private var createdExercise: Exercise?
    @State private var openedExercise: Exercise?
    /// Shows "Exercício criado".
    @Environment(RootFeedback.self) private var rootFeedback: RootFeedback?

    private struct NewExerciseForm: Identifiable {
        let id = UUID()
        let form: ExerciseForm
    }

    var body: some View {
        let lists = cache.lists(for: exercises)
        let items = lists.active
        let hasArchivedCustom = !lists.archived.isEmpty
        let group = ExerciseCatalog.groupFilter(chosenGroup, in: items, hasArchivedCustom: hasArchivedCustom)
        let equipmentChoices = ExerciseCatalog.equipment(for: group, in: items)
        let equipment = ExerciseCatalog.equipment(chosenEquipment, for: group, in: items)
        let shown = ExerciseCatalog.filtered(items, group: group, equipment: equipment, search: searchText)
        let archived = ExerciseCatalog.archivedShown(lists.archived, group: group, equipment: equipment, search: searchText)
        // With only archived exercises to show, they take the list's place, as in the prototype.
        let showsCount = ExerciseCatalog.isFiltering(group: group, equipment: equipment) && !(shown.isEmpty && !archived.isEmpty)

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
                if showsCount {
                    countRow(shown.count)
                        .padding(.horizontal, Theme.Metrics.screenPadding)
                        .padding(.top, 10)
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
                // The prototype's 8 below the count, 14 below the filters.
                .padding(.top, showsCount ? 8 : 14)
            }
            .padding(.top, 16)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationDestination(for: ExerciseRoute.self) { route in
            if let exercise = exercises.first(where: { $0.id == route.exerciseID }) {
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
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    /// The exercises left, or the card that says none was found.
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

    private func row(_ item: ExerciseCatalog.Item) -> some View {
        NavigationLink(value: ExerciseRoute(exerciseID: item.id)) {
            ExerciseCard(item: item)
        }
        .buttonStyle(.plain)
    }

    /// ARQUIVADOS, how many, what it means, and the archived exercises of the user's own.
    private func archivedSection(_ archived: [ExerciseCatalog.Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle("Arquivados")
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
                .scaledFont(12, lineHeight: 1.4)
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
            let lists = cache.lists(for: exercises)
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
                .scaledFont(11)
                .foregroundStyle(Theme.Colors.secondaryText)
                .accessibilityIdentifier("exercises.count")
            Spacer(minLength: 8)
            Button {
                chosenGroup = .all
                chosenEquipment = nil
            } label: {
                Text("Limpar filtros")
                    .scaledFont(11, weight: .bold)
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
}
