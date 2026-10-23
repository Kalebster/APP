import Foundation

/// Where the session in progress stands: the sets done out of all of them, the current exercise (the
/// first with a set not done) and the current set (the first not done of that exercise).
/// Pure logic: it reads the sets it is given, in order, and never the store.
struct SessionProgress: Equatable {
    let completedSets: Int
    let totalSets: Int
    let exerciseCount: Int
    /// Position of the current exercise, from 0; `nil` when every set is done or there are no sets.
    let currentExerciseIndex: Int?
    /// The first set not done of the current exercise.
    let currentSetID: UUID?

    /// `sets` holds the sets of each exercise of the session, both in session order.
    init(sets: [[SetLog]]) {
        completedSets = sets.reduce(0) { $0 + $1.filter(\.isCompleted).count }
        totalSets = sets.reduce(0) { $0 + $1.count }
        exerciseCount = sets.count
        let current = sets.firstIndex { exercise in exercise.contains { !$0.isCompleted } }
        currentExerciseIndex = current
        currentSetID = current.flatMap { index in sets[index].first { !$0.isCompleted }?.id }
    }

    /// The part of the sets done, from 0 to 1, for the progress bar.
    var fraction: Double {
        totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0
    }

    /// "5 de 13 séries", "1 de 1 série", "0 de 0 séries".
    var setsText: String {
        totalSets == 1
            ? String(localized: "\(completedSets) de 1 série")
            : String(localized: "\(completedSets) de \(totalSets) séries")
    }

    /// "Exercício 2 de 4"; with every set done, the last one ("Exercício 4 de 4"); `nil` without exercises.
    var exerciseText: String? {
        guard exerciseCount > 0 else { return nil }
        let number = (currentExerciseIndex ?? (exerciseCount - 1)) + 1
        return String(localized: "Exercício \(number) de \(exerciseCount)")
    }

    // MARK: - One exercise

    /// An exercise is finished when it has sets and all of them are done.
    static func isFinished(_ sets: [SetLog]) -> Bool {
        !sets.isEmpty && sets.allSatisfy(\.isCompleted)
    }

    /// The load lifted: the sum of load × repetitions of the working and failure sets done. Warm-up and
    /// feeder sets, and sets without a load, do not count (`SetType.countsTowardLiftedLoad`).
    static func volumeKg(of sets: [SetLog]) -> Double {
        sets.reduce(0) { total, log in
            guard log.isCompleted, log.setType.countsTowardLiftedLoad,
                  let weightKg = log.weightKg, let reps = log.reps else { return total }
            return total + weightKg * Double(reps)
        }
    }

    /// The repetition targets of an exercise's working and failure sets (`SetType.countsTowardTarget`),
    /// or of all its sets when it has none of those: "meta 8–12 reps" from the lowest minimum to the
    /// highest maximum, "meta 10 reps" when they are equal, `nil` when no set has a target.
    static func targetText(of sets: [SetLog]) -> String? {
        let work = sets.filter(\.setType.countsTowardTarget)
        let counted = work.isEmpty ? sets : work
        let lows = counted.compactMap { $0.targetRepsMin ?? $0.targetRepsMax }
        let highs = counted.compactMap { $0.targetRepsMax ?? $0.targetRepsMin }
        guard let low = lows.min(), let high = highs.max() else { return nil }
        return low == high
            ? String(localized: "meta \(low) reps")
            : String(localized: "meta \(low)–\(high) reps")
    }

    /// What a finished exercise did, in its closed card: "60 kg × 10 · 10 · 9 · 8". A set shows only its
    /// repetitions when it has the load of the set before it, and only them when it has no load.
    static func doneSummary(of sets: [SetLog]) -> String {
        var parts: [String] = []
        var previousLoad: Double?
        for log in sets where log.isCompleted {
            let reps = log.reps.map { $0.formatted() } ?? "—"
            if let load = log.weightKg, parts.isEmpty || load != previousLoad {
                parts.append("\(PlannedSetFormatting.weightText(load)) × \(reps)")
            } else {
                parts.append(reps)
            }
            previousLoad = log.weightKg
        }
        return parts.joined(separator: " · ")
    }
}
