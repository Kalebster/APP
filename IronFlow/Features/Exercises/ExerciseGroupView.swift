import SwiftData
import SwiftUI

/// The exercises of one muscle group, alphabetical, with search inside the group.
struct ExerciseGroupView: View {
    let group: MuscleGroup

    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    @State private var searchText = ""

    var body: some View {
        let groupExercises = ExerciseListFilter.sections(from: exercises, search: searchText, group: group)
            .first?.exercises ?? []

        ScrollView {
            LazyVStack(spacing: Theme.Metrics.cardSpacing) {
                ForEach(groupExercises) { exercise in
                    ExerciseRow(exercise: exercise)
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .overlay {
            if groupExercises.isEmpty {
                emptyState
            }
        }
        .screenBackground()
        .navigationTitle(Text(group.displayName))
        // Always visible: a pushed screen would otherwise hide the field until the list is pulled down.
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Buscar exercício")
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            ContentUnavailableView.search(text: trimmedSearch)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("exercises.empty.search")
        } else {
            ContentUnavailableView {
                Label("Nenhum exercício em \(String(localized: group.displayName))", systemImage: "dumbbell")
            }
            .accessibilityIdentifier("exercises.empty.group")
        }
    }
}
