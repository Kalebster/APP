import SwiftData
import SwiftUI

/// The Exercises tab: the exercise library with search and a muscle group filter.
/// Read-only for now; creating, editing and archiving come in later steps.
struct ExerciseListView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var selectedGroup: MuscleGroup?

    var body: some View {
        let sections = ExerciseListFilter.sections(from: exercises, search: searchText, group: selectedGroup)

        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.exercises) { exercise in
                        ExerciseRow(exercise: exercise)
                    }
                } header: {
                    Text(section.group.displayName)
                        .accessibilityIdentifier("exercises.section.\(section.group.rawValue)")
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                emptyState
            }
        }
        .searchable(text: $searchText, prompt: Text("Buscar exercício"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Grupo muscular", selection: $selectedGroup) {
                Text("Todos").tag(MuscleGroup?.none)
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    Text(group.displayName).tag(Optional(group))
                }
            }
        } label: {
            Label(
                "Filtrar por grupo",
                systemImage: selectedGroup == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityIdentifier("exercises.filter")
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            VStack {
                ContentUnavailableView.search(text: trimmedSearch)
                // A group filter can hide matches: offer to clear it.
                if selectedGroup != nil {
                    Button("Mostrar todos") {
                        selectedGroup = nil
                    }
                    .padding(.bottom)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("exercises.empty.search")
        } else if let selectedGroup {
            ContentUnavailableView {
                Label("Nenhum exercício em \(String(localized: selectedGroup.displayName))", systemImage: "dumbbell")
            } actions: {
                Button("Mostrar todos") {
                    self.selectedGroup = nil
                }
            }
            .accessibilityIdentifier("exercises.empty.group")
        } else {
            ContentUnavailableView("Nenhum exercício disponível", systemImage: "dumbbell")
                .accessibilityIdentifier("exercises.empty.library")
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack {
            Text(exercise.name)
            Spacer()
            if exercise.isCustom {
                Text("Personalizado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}
