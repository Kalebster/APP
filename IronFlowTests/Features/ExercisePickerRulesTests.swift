import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// What the screens of the base list read and decide without the store: the tap on a base in the picker
/// (chosen at once or the choice sheet, and on which combination), the combination a base opens on, the
/// library records with the hidden ones, the combinations chosen of a base and the texts of the sheet.
@MainActor
struct ExercisePickerRulesTests {
    private func base(_ name: String) throws -> ExerciseBase {
        try #require(ExerciseBaseIndex.bases[name])
    }

    private func entry(_ name: String) throws -> DefaultExercise {
        try #require(DefaultExerciseLibrary.all.first { $0.name == name }, "\(name) is not in the library")
    }

    /// The records of the combinations of `bases`, as the store has them; those named in `hidden` archived,
    /// as the seeder leaves a combination whose name an exercise of the user's own takes.
    private func records(of bases: [String], hidden: Set<String> = []) -> LibraryRecords {
        LibraryRecords(bases.flatMap { ExerciseBaseIndex.combinations[$0] ?? [] }.map { entry in
            let exercise = Exercise(name: entry.name, muscleGroup: entry.muscleGroup, isCustom: false, libraryKey: entry.key)
            exercise.isArchived = hidden.contains(entry.name)
            return exercise
        })
    }

    private func id(of name: String, in records: LibraryRecords) throws -> UUID {
        try #require(records.byKey[entry(name).key]?.id)
    }

    // MARK: - The tap on a base

    @Test("With the equipment filter on, a base without a second row and one common combination of it is chosen at once, and unchosen the same way")
    func directTap() throws {
        let supino = try base("Supino Reto")
        let records = records(of: ["Supino Reto"])
        var selection = ExerciseSelection(workoutExerciseIDs: [])
        let barbell = try id(of: "Supino Reto (Barra)", in: records)

        let first = ExercisePickerView.tapResult(of: supino, equipment: .barbell, selection: selection, records: records, lastDone: ExerciseLastDone())
        #expect(first == .toggle(barbell))
        selection.toggle(barbell)
        let second = ExercisePickerView.tapResult(of: supino, equipment: .barbell, selection: selection, records: records, lastDone: ExerciseLastDone())
        #expect(second == .toggle(barbell))
    }

    @Test("Without the equipment filter a base always opens the sheet, on the combination it opens on: the one done last, or else its first")
    func sheetWithoutFilter() throws {
        let supino = try base("Supino Reto")
        let records = records(of: ["Supino Reto"])
        let selection = ExerciseSelection(workoutExerciseIDs: [])

        let barbell = try entry("Supino Reto (Barra)")
        let dumbbells = try entry("Supino Reto (Halter)")
        let cable = try entry("Supino Reto (Polia)")
        #expect(ExercisePickerView.tapResult(of: supino, equipment: nil, selection: selection, records: records, lastDone: ExerciseLastDone()) == .sheet(barbell))
        var lastDone = ExerciseLastDone()
        lastDone.byKey[dumbbells.key] = Date(timeIntervalSince1970: 2_000)
        lastDone.byKey[cable.key] = Date(timeIntervalSince1970: 1_000)
        #expect(ExercisePickerView.tapResult(of: supino, equipment: nil, selection: selection, records: records, lastDone: lastDone) == .sheet(dumbbells))
    }

    @Test("Two common combinations of the equipment open the sheet on the first of them; a combination chosen before is where it opens")
    func sheetWithTwoOfTheEquipment() throws {
        let supino = try base("Supino Reto")
        let records = records(of: ["Supino Reto"])
        var selection = ExerciseSelection(workoutExerciseIDs: [])

        let machine = try entry("Supino Reto (Máquina)")
        let isoLateral = try entry("Supino Reto Iso-Lateral (Máquina)")
        #expect(ExercisePickerView.tapResult(of: supino, equipment: .machine, selection: selection, records: records, lastDone: ExerciseLastDone()) == .sheet(machine))
        selection.toggle(try id(of: isoLateral.name, in: records))
        #expect(ExercisePickerView.tapResult(of: supino, equipment: .machine, selection: selection, records: records, lastDone: ExerciseLastDone()) == .sheet(isoLateral))
    }

    @Test("A base with a second row always opens the sheet; with the equipment filter on, on that equipment with the grip it opens on")
    func sheetKeepsTheGrip() throws {
        let puxada = try base("Puxada Alta")
        let records = records(of: ["Puxada Alta"])
        let selection = ExerciseSelection(workoutExerciseIDs: [])
        let closedMachine = try entry("Puxada Alta Fechada (Máquina)")
        let closedCable = try entry("Puxada Alta Fechada (Polia)")
        var lastDone = ExerciseLastDone()
        lastDone.byKey[closedMachine.key] = Date(timeIntervalSince1970: 1_000)

        #expect(ExercisePickerView.tapResult(of: puxada, equipment: .cable, selection: selection, records: records, lastDone: lastDone) == .sheet(closedCable))
        #expect(ExercisePickerView.tapResult(of: puxada, equipment: nil, selection: selection, records: records, lastDone: lastDone) == .sheet(closedMachine))
    }

    @Test("The one common combination of the equipment already in the workout, or hidden, is not chosen at once: the sheet opens, never on a hidden one")
    func notChosenAtOnce() throws {
        let supino = try base("Supino Reto")
        let barbell = try entry("Supino Reto (Barra)")
        let dumbbells = try entry("Supino Reto (Halter)")
        let free = records(of: ["Supino Reto"])
        let inWorkout = ExerciseSelection(workoutExerciseIDs: [try id(of: barbell.name, in: free)])
        #expect(ExercisePickerView.tapResult(of: supino, equipment: .barbell, selection: inWorkout, records: free, lastDone: ExerciseLastDone()) == .sheet(barbell))

        // Hidden: the sheet opens on the first one shown, as the base does, not on the hidden one.
        let hidden = records(of: ["Supino Reto"], hidden: [barbell.name])
        #expect(hidden.hiddenKeys == [barbell.key])
        let result = ExercisePickerView.tapResult(of: supino, equipment: .barbell, selection: ExerciseSelection(workoutExerciseIDs: []), records: hidden, lastDone: ExerciseLastDone())
        #expect(result == .sheet(dumbbells))
    }

    // MARK: - The combination a base opens on

    @Test("A base opens on the combination done last, else on its first; a hidden one only when all of them are hidden")
    func openingCombination() throws {
        let supino = try base("Supino Reto")
        let barbell = try entry("Supino Reto (Barra)")
        let smith = try entry("Supino Reto (Smith)")
        let dumbbells = try entry("Supino Reto (Halter)")
        var lastDone = ExerciseLastDone()
        #expect(lastDone.openingCombination(of: supino) == barbell)

        lastDone.byKey[smith.key] = Date(timeIntervalSince1970: 3_000)
        lastDone.byKey[dumbbells.key] = Date(timeIntervalSince1970: 1_000)
        #expect(lastDone.openingCombination(of: supino) == smith)
        // The one done last hidden: the other one done.
        #expect(lastDone.openingCombination(of: supino, hiddenKeys: [smith.key]) == dumbbells)
        // Every one hidden: the one done last all the same.
        let all = Set((ExerciseBaseIndex.combinations["Supino Reto"] ?? []).map(\.key))
        #expect(lastDone.openingCombination(of: supino, hiddenKeys: all) == smith)
    }

    @Test("Read from the store, the day each exercise was last done is that of its latest finished session; the session in progress never counts, and an exercise of the user's own counts by its id only")
    func lastDoneFromTheStore() throws {
        let harness = try ServiceTestHarness()
        try ExerciseLibrarySeeder(context: harness.context, now: harness.clock.now).seed()
        let bench = try #require(try harness.context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Supino Reto (Barra)" })).first)
        let fly = try #require(try harness.context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Crucifixo (Halter)" })).first)
        let own = try harness.exercises.createCustomExercise(name: "Meu Supino", muscleGroup: .chest)
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10)]), (own, [.reps(8, 10)])])

        var starts: [Date] = []
        for _ in 0..<2 {
            harness.clock.advance(by: 86_400)
            let session = try harness.sessions.startSession(from: workout)
            starts.append(session.startedAt)
            try harness.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: 60, reps: 8)
            try harness.sessions.completeSet(session.orderedExercises[1].orderedSetLogs[0], weightKg: 20, reps: 8)
            try harness.sessions.finishSession(session)
        }
        // In progress: Crucifixo (Halter) only there, Supino Reto again.
        harness.clock.advance(by: 86_400)
        let active = try harness.sessions.startSession(from: workout)
        try harness.sessions.addExercises([fly], to: active)

        let lastDone = try ExerciseLastDone.read(in: harness.context)
        let benchKey = try #require(bench.libraryKey)
        let flyKey = try #require(fly.libraryKey)
        #expect(lastDone.byKey[benchKey] == starts[1])
        #expect(lastDone.byID[bench.id] == starts[1])
        #expect(lastDone.byID[own.id] == starts[1])
        #expect(!lastDone.byKey.values.contains(active.startedAt))
        #expect(lastDone.byKey[flyKey] == nil)
        #expect(lastDone.byKey.count == 1)
        let finished = try harness.context.fetch(SessionService.finishedSessionsDescriptor)
        #expect(lastDone == ExerciseLastDone(sessions: finished))
    }

    // MARK: - The records    // MARK: - The records

    @Test("The records are the library's, by key: the archived ones are the hidden ones; an exercise of the user's own is never one")
    func libraryRecords() throws {
        let bench = try entry("Supino Reto (Barra)")
        let dumbbells = try entry("Supino Reto (Halter)")
        let library = Exercise(name: bench.name, muscleGroup: .chest, isCustom: false, libraryKey: bench.key)
        let hidden = Exercise(name: dumbbells.name, muscleGroup: .chest, isCustom: false, libraryKey: dumbbells.key)
        hidden.isArchived = true
        let own = Exercise(name: "Supino Reto (Halter)", muscleGroup: .chest, isCustom: true)
        let copy = Exercise(name: "Outro", muscleGroup: .chest, isCustom: false, libraryKey: bench.key)

        let records = LibraryRecords([library, hidden, own, copy])
        #expect(records.byKey.count == 2)
        #expect(records.byKey[bench.key] === library)
        #expect(records.hiddenKeys == [dumbbells.key])
    }

    // MARK: - The sheet

    @Test("The combinations chosen of a base are those of the selection, in the order they were chosen, never another base's")
    func chosenOfABase() throws {
        let records = records(of: ["Supino Reto", "Supino Inclinado"])
        var selection = ExerciseSelection(workoutExerciseIDs: [])
        selection.toggle(try id(of: "Supino Reto (Polia)", in: records))
        selection.toggle(try id(of: "Supino Inclinado (Halter)", in: records))
        selection.toggle(try id(of: "Supino Reto (Barra)", in: records))

        let chosen = ExerciseChoiceSheet.chosen(of: try base("Supino Reto"), in: selection, records: records)
        #expect(chosen.map(\.name) == ["Supino Reto (Polia)", "Supino Reto (Barra)"])
    }

    @Test("The combination's text: the equipment, and the grip or variation when it says something; the day as dd/mm")
    func texts() throws {
        let texts = try ["Puxada Alta Triângulo (Polia)", "Rosca Direta (Barra W)", "Rosca Alternada (Halter)", "Supino Reto (Barra)"]
            .map { try ExerciseBaseIndex.optionText(of: entry($0)) }
        #expect(texts == ["Polia · Triângulo", "Barra W", "Halteres · Alternada", "Barra"])

        let day = try #require(TrainingDay.calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 18)))
        #expect(ExerciseChoiceSheet.dayAndMonth(day) == "05/11")
    }

    @Test("The notices of Adicionar a um treino")
    func addNotices() {
        #expect(AddToWorkoutOutcome.added(workoutName: "Pull", count: 1).notice == "Adicionado a “Pull”")
        #expect(AddToWorkoutOutcome.added(workoutName: "Push", count: 2).notice == "2 exercícios adicionados a “Push”")
        let workout = Workout(name: "Novo")
        #expect(AddToWorkoutOutcome.created(workout, count: 1).notice == "Treino criado com 1 exercício")
        #expect(AddToWorkoutOutcome.created(workout, count: 3).notice == "Treino criado com 3 exercícios")
    }
}
