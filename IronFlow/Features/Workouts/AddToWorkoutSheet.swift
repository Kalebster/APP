import SwiftData
import SwiftUI

/// What "Adicionar a um treino" did.
enum AddToWorkoutOutcome {
    /// The exercises that were missing went to the end of `workoutName`.
    case added(workoutName: String, count: Int)
    /// A new workout was created with the exercises; its editor opens.
    case created(Workout, count: Int)

    /// "Adicionado a “Pull”", "2 exercícios adicionados a “Push”", "Treino criado com 1 exercício".
    var notice: String {
        switch self {
        case .added(let name, let count):
            count == 1
                ? String(localized: "Adicionado a “\(name)”")
                : String(localized: "\(count) exercícios adicionados a “\(name)”")
        case .created(_, let count):
            count == 1
                ? String(localized: "Treino criado com 1 exercício")
                : String(localized: "Treino criado com \(count) exercícios")
        }
    }
}

/// "Adicionar a um treino", from the Exercícios tab (the button of the exercise screen, and "Continuar" of
/// "Montar treino"): "Criar treino novo" first, then the workouts, in the order of the Treinos tab, each
/// with its summary, as "Adicionar à playlist" of the Music app. A workout that already has every exercise
/// is off ("Já está neste treino"); one that has part of them says so ("1 já está neste treino · entra 1")
/// and gets only the others. A workout chosen gets the exercises at its end, with 3 sets each, and the sheet
/// closes; "Criar treino novo" asks for the name (the "Novo treino" sheet), creates the workout with them
/// and opens its editor. Each acts once, even when tapped twice. "Cancelar" goes back to where it was.
struct AddToWorkoutSheet: View {
    /// The exercises, in the order chosen.
    let exercises: [Exercise]
    let onDone: @MainActor (AddToWorkoutOutcome) -> Void

    @Query(sort: [SortDescriptor(\Workout.createdAt), SortDescriptor(\Workout.name)]) private var workouts: [Workout]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isNaming = false
    /// The outcome, handed over once the sheet has closed.
    @State private var outcome: AddToWorkoutOutcome?
    /// Set once a workout got the exercises or was created, so a second tap does nothing.
    @State private var isDone = false
    @State private var errorMessage: String?

    @ScaledMetric(relativeTo: .subheadline) private var plusSide: CGFloat = 32

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(Text("Adicionar a um treino"), explanation: Text(verbatim: lead))
                rows
            }
            .sheetContentPadding()
        } bottom: {
            SheetButton(Text("Cancelar"), kind: .secondary, usesPrototypeStyle: true) {
                dismiss()
            }
            .accessibilityIdentifier("addToWorkout.cancel")
            .sheetButtonBar()
        }
        .sheet(isPresented: $isNaming, onDismiss: finishIfDone) {
            WorkoutNameSheet(title: "Novo treino", saveTitle: "Criar treino") { name in
                try create(named: name)
            }
        }
        .onDisappear {
            if let outcome {
                self.outcome = nil
                onDone(outcome)
            }
        }
        .errorAlert($errorMessage)
    }

    /// "Supino Reto (Halter) entra no fim do treino que você escolher." or "2 exercícios entram…".
    private var lead: String {
        if exercises.count == 1, let exercise = exercises.first {
            return String(localized: "\(exercise.name) entra no fim do treino que você escolher.")
        }
        return String(localized: "\(exercises.count) exercícios entram no fim do treino que você escolher.")
    }

    /// "Criar treino novo" and the workouts, in one block with a line between them.
    private var rows: some View {
        VStack(spacing: 0) {
            Button(action: startNaming) {
                row(
                    name: String(localized: "Criar treino novo"),
                    detail: exercises.count == 1
                        ? String(localized: "Começa com este exercício")
                        : String(localized: "Começa com estes \(exercises.count) exercícios"),
                    accepts: true
                )
            }
            .buttonStyle(PrototypeButtonStyle())
            .disabled(isDone)
            .accessibilityIdentifier("addToWorkout.new")
            ForEach(workouts) { workout in
                Theme.Colors.rowSeparator
                    .frame(height: 1)
                    .accessibilityHidden(true)
                let missing = missingExercises(in: workout)
                let isFull = missing.isEmpty
                Button {
                    add(to: workout)
                } label: {
                    row(name: workout.name, detail: detail(of: workout, missing: missing.count), accepts: !isFull)
                        .opacity(isFull ? 0.45 : 1)
                }
                .buttonStyle(PrototypeButtonStyle())
                .disabled(isFull || isDone)
                .accessibilityIdentifier("addToWorkout.workout")
            }
        }
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// A row: the name (15 bold), the line below it (11 `secondaryText`) and, when it takes the exercises,
    /// the round white + on the right.
    private func row(name: String, detail: String, accepts: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: name)
                    .scaledFont(15, weight: .bold)
                    .foregroundStyle(Theme.Colors.brightText)
                    .lineLimit(1)
                Text(verbatim: detail)
                    .scaledFont(11)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if accepts {
                AppIcon(.plus, size: 14, relativeTo: .subheadline)
                    .foregroundStyle(Theme.Colors.primaryButtonText)
                    .frame(width: plusSide, height: plusSide)
                    .background(Theme.Colors.primaryButton, in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accepts ? "\(name), \(detail), \(String(localized: "adicionar"))" : "\(name), \(detail)"))
    }

    /// The workout's summary; for one that already has some of the exercises, how many it has and how many
    /// go in; "Já está neste treino" or "Todos já estão neste treino" when it has them all.
    private func detail(of workout: Workout, missing: Int) -> String {
        let has = exercises.count - missing
        if missing == 0 {
            return exercises.count == 1 ? String(localized: "Já está neste treino") : String(localized: "Todos já estão neste treino")
        }
        guard has > 0 else { return WorkoutListSummary.cardSummary(for: workout) }
        let already = has == 1 ? String(localized: "1 já está neste treino") : String(localized: "\(has) já estão neste treino")
        let goesIn = missing == 1 ? String(localized: "entra 1") : String(localized: "entram \(missing)")
        return "\(already) · \(goesIn)"
    }

    /// The exercises the workout does not have yet, in the order chosen.
    private func missingExercises(in workout: Workout) -> [Exercise] {
        let inWorkout = Set(workout.exercises.compactMap { $0.exercise?.id })
        return exercises.filter { !inWorkout.contains($0.id) }
    }

    private func startNaming() {
        guard !isDone, !isNaming else { return }
        isNaming = true
    }

    /// The missing exercises at the end of the workout, with 3 sets each; the sheet closes.
    private func add(to workout: Workout) {
        guard !isDone else { return }
        let missing = missingExercises(in: workout)
        guard !missing.isEmpty else { return }
        do {
            try WorkoutService(context: context).addExercises(missing, to: workout)
            isDone = true
            outcome = .added(workoutName: workout.name, count: missing.count)
            dismiss()
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// The workout created with every exercise, in one save; the editor opens once the sheets have closed.
    private func create(named name: String) throws {
        guard !isDone else { return }
        let workout = try WorkoutService(context: context).createWorkout(name: name, exercises: exercises)
        isDone = true
        outcome = .created(workout, count: exercises.count)
    }

    /// Once the name sheet has closed with a workout created, this sheet closes too.
    private func finishIfDone() {
        if isDone {
            dismiss()
        }
    }
}
