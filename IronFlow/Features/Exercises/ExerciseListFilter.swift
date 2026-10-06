import Foundation

/// Search, muscle group filter, sections and group summaries of the exercise list.
/// Pure logic: no UI and no store access.
enum ExerciseListFilter {
    struct Section: Identifiable {
        let group: MuscleGroup
        let exercises: [Exercise]

        var id: MuscleGroup { group }
    }

    struct GroupSummary: Identifiable {
        let group: MuscleGroup
        let count: Int

        var id: MuscleGroup { group }
    }

    /// Every muscle group, in the approved group order, with its number of active
    /// (non-archived) exercises. Groups without exercises are included with a count of zero.
    static func groupSummaries(from exercises: [Exercise]) -> [GroupSummary] {
        var counts: [MuscleGroup: Int] = [:]
        for exercise in exercises where !exercise.isArchived {
            counts[exercise.muscleGroup, default: 0] += 1
        }
        return MuscleGroup.allCases.map { GroupSummary(group: $0, count: counts[$0, default: 0]) }
    }

    /// Active (non-archived) exercises that match `search` and `group`, in one section per
    /// muscle group following the approved group order, alphabetical inside each section.
    ///
    /// `search` matches any part of the name, ignoring case, diacritics and leading or
    /// trailing whitespace (the same normalization as the exercise name uniqueness rule).
    /// A `nil` group means all groups.
    static func sections(from exercises: [Exercise], search: String, group: MuscleGroup?) -> [Section] {
        let query = Validation.comparisonKey(forName: search.trimmingCharacters(in: .whitespacesAndNewlines))

        var exercisesByGroup: [MuscleGroup: [Exercise]] = [:]
        for exercise in exercises where !exercise.isArchived {
            let exerciseGroup = exercise.muscleGroup
            if let group, exerciseGroup != group { continue }
            if !query.isEmpty && !Validation.comparisonKey(forName: exercise.name).contains(query) { continue }
            exercisesByGroup[exerciseGroup, default: []].append(exercise)
        }

        return MuscleGroup.allCases.compactMap { group in
            guard let groupExercises = exercisesByGroup[group] else { return nil }
            let sorted = groupExercises.sorted { lhs, rhs in
                switch lhs.name.localizedStandardCompare(rhs.name) {
                case .orderedAscending: true
                case .orderedDescending: false
                case .orderedSame: lhs.id < rhs.id
                }
            }
            return Section(group: group, exercises: sorted)
        }
    }
}
