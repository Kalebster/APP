import SwiftData
import SwiftUI

/// The Exercises tab: one card per muscle group, opening that group's exercises.
/// Searching shows matching exercises from every group instead of the cards.
/// Read-only for now; creating, editing and archiving come in later steps.
struct ExerciseListView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    @State private var searchText = ""

    var body: some View {
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let sections = isSearching ? ExerciseListFilter.sections(from: exercises, search: searchText, group: nil) : []

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
                if isSearching {
                    ForEach(sections) { section in
                        ExerciseSectionHeader(group: section.group)
                        ForEach(section.exercises) { exercise in
                            ExerciseRow(exercise: exercise)
                        }
                    }
                } else {
                    ForEach(ExerciseListFilter.groupSummaries(from: exercises)) { summary in
                        NavigationLink(value: summary.group) {
                            GroupCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("exercises.group.\(summary.group.rawValue)")
                    }
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .overlay {
            if isSearching && sections.isEmpty {
                ContentUnavailableView.search(text: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("exercises.empty.search")
            }
        }
        .screenBackground()
        .searchable(text: $searchText, prompt: Text("Buscar exercício"))
        .navigationDestination(for: MuscleGroup.self) { group in
            ExerciseGroupView(group: group)
        }
    }
}

/// A muscle group card: name, number of exercises and a disclosure chevron.
private struct GroupCard: View {
    let summary: ExerciseListFilter.GroupSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.group.displayName)
                    .font(.headline)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Group {
                    if summary.count == 0 {
                        Text("Nenhum exercício")
                    } else {
                        Text("\(summary.count) exercícios")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .cardStyle()
    }
}

/// The muscle group title above its exercises in search results.
struct ExerciseSectionHeader: View {
    let group: MuscleGroup

    var body: some View {
        Text(group.displayName)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("exercises.section.\(group.rawValue)")
    }
}

/// An exercise card: the name, and a label when the exercise was created by the user.
struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Text(exercise.name)
            Spacer(minLength: 0)
            if exercise.isCustom {
                Text("Personalizado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
