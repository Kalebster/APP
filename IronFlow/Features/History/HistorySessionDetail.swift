import Foundation

/// A finished session as its history detail shows it.
///
/// Built only from what the session recorded: its name, exercise and muscle group snapshots and its
/// sets. The planned workout and the library exercise are never read, so renaming, archiving or
/// deleting them changes nothing here. Plain values: the screen holding them cannot reach the store.
struct HistorySessionDetail: Equatable, Sendable {
    /// A performed exercise, in the recorded order.
    struct ExerciseRecord: Equatable, Identifiable, Sendable {
        let id: UUID
        let name: String
        let muscleGroup: MuscleGroup
        let sets: [SetRecord]
    }

    /// A recorded set, numbered from 1 in the recorded order.
    struct SetRecord: Equatable, Identifiable, Sendable {
        let id: UUID
        let number: Int
        let targetRepsMin: Int?
        let targetRepsMax: Int?
        let weightKg: Double?
        let reps: Int?
        let isCompleted: Bool
    }

    /// The session's name; a session without a planned workout is a "Treino livre".
    let name: String
    let startedAt: Date
    let duration: TimeInterval?
    let exercises: [ExerciseRecord]

    init(_ session: Session) {
        name = SessionFormatting.name(session.workoutNameSnapshot)
        startedAt = session.startedAt
        duration = session.duration
        exercises = session.orderedExercises.map { performed in
            ExerciseRecord(
                id: performed.id,
                name: performed.exerciseNameSnapshot,
                muscleGroup: performed.muscleGroupSnapshot,
                sets: performed.orderedSetLogs.enumerated().map { index, log in
                    SetRecord(
                        id: log.id,
                        number: index + 1,
                        targetRepsMin: log.targetRepsMin,
                        targetRepsMax: log.targetRepsMax,
                        weightKg: log.weightKg,
                        reps: log.reps,
                        isCompleted: log.isCompleted
                    )
                }
            )
        }
    }
}

extension HistorySessionDetail.SetRecord {
    /// What the set row shows: "Meta: 8–12 · Carga: 20 kg · Reps: 10", with "—" for what was not recorded.
    var valuesText: String {
        let targetText = SessionFormatting.targetText(min: targetRepsMin, max: targetRepsMax) ?? "—"
        let weightText = weightKg.map { PlannedSetFormatting.weightText($0) } ?? "—"
        let repsText = reps.map { "\($0)" } ?? "—"
        return String(localized: "Meta: \(targetText) · Carga: \(weightText) · Reps: \(repsText)")
    }

    /// What VoiceOver reads for the set: number, target, load, repetitions and whether it was done,
    /// in words ("Série 2, Meta: 6–8, Sem carga, Sem repetições, Não concluída").
    var accessibilityText: String {
        let targetText = SessionFormatting.targetText(min: targetRepsMin, max: targetRepsMax)
            .map { String(localized: "Meta: \($0)") } ?? String(localized: "Sem meta")
        let weightText = weightKg.map { String(localized: "Carga: \(PlannedSetFormatting.weightText($0))") }
            ?? String(localized: "Sem carga")
        // The catalog gives the singular and plural forms.
        let repsText = reps.map { String(localized: "\($0) repetições") } ?? String(localized: "Sem repetições")
        let stateText = isCompleted ? String(localized: "Concluída") : String(localized: "Não concluída")
        return [String(localized: "Série \(number)"), targetText, weightText, repsText, stateText].joined(separator: ", ")
    }
}
