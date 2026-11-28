import Foundation
import Testing
@testable import IronFlow

/// The muscles and the kind of machine of each library exercise, from the approved base list.
struct DefaultExerciseMusclesTests {
    let table = DefaultExerciseMuscles.all

    @Test("Every key of the library has exactly one entry, in the library's order, and no entry is left over")
    func everyKeyIsThere() {
        #expect(table.map(\.key) == DefaultExerciseLibrary.all.map(\.key))
        #expect(DefaultExerciseMuscles.byKey.count == 1_525)
    }

    @Test("Every exercise has at least one main muscle")
    func mainMuscleNeverEmpty() {
        let empty = table.filter { $0.primary.isEmpty }.map(\.key)
        #expect(empty.isEmpty, "Without a main muscle: \(empty)")
    }

    @Test("No muscle is both main and secondary, and none is repeated in a list")
    func noMuscleTwice() {
        for entry in table {
            #expect(Set(entry.primary).isDisjoint(with: entry.secondary), "Main and secondary: \(entry.key)")
            #expect(Set(entry.primary).count == entry.primary.count, "Repeated main muscle: \(entry.key)")
            #expect(Set(entry.secondary).count == entry.secondary.count, "Repeated secondary muscle: \(entry.key)")
        }
    }

    @Test("A kind of machine only on the exercises done on a machine, and every one of them has one")
    func machineOnlyOnMachines() throws {
        for entry in table {
            let exercise = try #require(DefaultExerciseLibrary.byKey[entry.key])
            #expect((entry.machine != nil) == (exercise.equipment == .machine), "\(exercise.name): \(String(describing: entry.machine))")
        }
    }

    @Test("Graviton is exactly the 6 Graviton combinations (the 4 of the library of 420 keep their keys), and no library exercise is on the GHD bench")
    func gravitonAndGHD() throws {
        let graviton = table.filter { $0.machine == .graviton }.map(\.key)
        #expect(graviton.count == 6)
        for key in ["assisted-pull-up", "assisted-chin-up", "assisted-chest-dips", "assisted-dips"] {
            #expect(graviton.contains(key), "\(key)")
        }
        let names = try graviton.map { try #require(DefaultExerciseLibrary.byKey[$0]).name }
        #expect(Set(names) == [
            "Peito na Paralela (Graviton)", "Barra Fixa (Graviton)", "Barra Fixa Fechada (Graviton)",
            "Barra Fixa Supinada (Graviton)", "Barra Fixa Neutra (Graviton)", "Tríceps na Paralela (Graviton)",
        ])
        for key in graviton {
            #expect(DefaultExerciseLibrary.byKey[key]?.option == .graviton, "\(key)")
        }
        // The Glute Ham Raise left the list; the bench stays a kind an exercise of the user's own can choose.
        #expect(table.filter { $0.machine == .ghd }.isEmpty)
    }

    @Test("20 of the 21 muscles are used by the library: Tibial anterior left it with Elevação de Ponta dos Pés, now Panturrilha em Pé")
    func everyMuscleUsed() {
        let used = Set(table.flatMap { $0.primary + $0.secondary })
        #expect(Muscle.allCases.count == 21)
        #expect(used == Set(Muscle.allCases).subtracting([.tibialis]))
    }

    @Test("A few entries as in the prototype")
    func samples() throws {
        let bench = try #require(DefaultExerciseMuscles.byKey["bench-press-barbell"])
        #expect(bench.primary == [.chest])
        #expect(bench.secondary == [.triceps, .frontDelts])
        #expect(bench.machine == nil)
        let legPress = try #require(DefaultExerciseMuscles.byKey["leg-press"])
        #expect(legPress.primary == [.quadriceps, .glutes])
        #expect(legPress.machine == .track)
    }

    @Test("An exercise of the user's own shows the muscles of its group; Corpo inteiro and Outro show none")
    func customExerciseMuscles() {
        #expect(DefaultExerciseMuscles.muscles(of: .chest) == [.chest])
        #expect(DefaultExerciseMuscles.muscles(of: .back) == [.lats])
        #expect(DefaultExerciseMuscles.muscles(of: .shoulders) == [.frontDelts, .sideDelts, .rearDelts])
        #expect(DefaultExerciseMuscles.muscles(of: .fullBody).isEmpty)
        #expect(DefaultExerciseMuscles.muscles(of: .other).isEmpty)
        for group in MuscleGroup.allCases where group != .fullBody && group != .other {
            #expect(DefaultExerciseMuscles.muscles(of: group).isEmpty == false, "No muscle for \(group)")
        }
    }

    @Test("Library and custom exercises: muscles, machine and Graviton")
    func exercises() {
        let legPress = Exercise(name: "Leg Press 45° (Máquina)", muscleGroup: .quadriceps, isCustom: false, libraryKey: "leg-press")
        let assisted = Exercise(name: "Barra Fixa (Graviton)", muscleGroup: .back, isCustom: false, libraryKey: "assisted-pull-up")
        let custom = Exercise(name: "Meu Supino", muscleGroup: .chest, isCustom: true)
        #expect(DefaultExerciseMuscles.isAssisted(assisted))
        #expect(DefaultExerciseMuscles.isAssisted(custom) == false)
        #expect(DefaultExerciseMuscles.isAssisted(nil) == false)
        #expect(DefaultExerciseMuscles.machine(of: assisted) == .graviton)
        #expect(DefaultExerciseMuscles.machine(of: custom) == nil)
        #expect(DefaultExerciseMuscles.muscles(of: custom).primary == [.chest])
        #expect(DefaultExerciseMuscles.muscles(of: custom).secondary.isEmpty)
        #expect(DefaultExerciseMuscles.muscles(of: legPress).primary == [.quadriceps, .glutes])
        #expect(DefaultExerciseMuscles.machine(of: legPress) == .track)
    }

    @Test("An exercise of the user's own with muscles, equipment and kind of machine of its own")
    func customExerciseChoices() {
        let custom = Exercise(name: "Puxada na Máquina Articulada", muscleGroup: .back, isCustom: true)
        custom.equipment = .machine
        custom.machineType = .lever
        custom.primaryMuscles = [.lats]
        custom.secondaryMuscles = [.biceps, .upperBack]
        #expect(DefaultExerciseMuscles.muscles(of: custom).primary == [.lats])
        #expect(DefaultExerciseMuscles.muscles(of: custom).secondary == [.biceps, .upperBack])
        #expect(DefaultExerciseMuscles.showsGroupMuscles(of: custom) == false)
        #expect(DefaultExerciseMuscles.machine(of: custom) == .lever)
        #expect(DefaultExerciseMuscles.equipment(of: custom) == .machine)
        #expect(DefaultExerciseMuscles.isAssisted(custom) == false)

        // Graviton: assisted, as the 4 of the library.
        custom.machineType = .graviton
        #expect(DefaultExerciseMuscles.isAssisted(custom))
        // A kind of machine stored without the machine as equipment does not count.
        custom.equipment = .dumbbell
        #expect(DefaultExerciseMuscles.machine(of: custom) == nil)
        #expect(DefaultExerciseMuscles.isAssisted(custom) == false)

        // Only secondary muscles: no group muscle is added ("Corpo inteiro" with helpers).
        let fullBody = Exercise(name: "Circuito", muscleGroup: .fullBody, isCustom: true)
        fullBody.secondaryMuscles = [.abs]
        #expect(DefaultExerciseMuscles.muscles(of: fullBody).primary.isEmpty)
        #expect(DefaultExerciseMuscles.muscles(of: fullBody).secondary == [.abs])
        #expect(DefaultExerciseMuscles.showsGroupMuscles(of: fullBody) == false)

        // Without muscles of its own: the group's, as before version 8; the library's equipment for a built-in.
        let old = Exercise(name: "Meu Supino", muscleGroup: .chest, isCustom: true)
        #expect(DefaultExerciseMuscles.showsGroupMuscles(of: old))
        #expect(DefaultExerciseMuscles.equipment(of: old) == nil)
        let legPress = Exercise(name: "Leg Press 45° (Máquina)", muscleGroup: .quadriceps, isCustom: false, libraryKey: "leg-press")
        #expect(DefaultExerciseMuscles.equipment(of: legPress) == .machine)
        #expect(DefaultExerciseMuscles.showsGroupMuscles(of: legPress) == false)
    }

    @Test("An exercise of the user's own whose stored muscles are all unknown to this version shows its group's, not none")
    func unknownMusclesShowTheGroup() {
        // Keys written by a newer version only: read as nothing, so the screen falls back to the group.
        let chest = Exercise(name: "Meu Supino", muscleGroup: .chest, isCustom: true)
        chest.primaryMuscleKeys = ["neck"]
        chest.secondaryMuscleKeys = []
        #expect(DefaultExerciseMuscles.muscles(of: chest).primary == [.chest])
        #expect(DefaultExerciseMuscles.muscles(of: chest).secondary.isEmpty)
        #expect(DefaultExerciseMuscles.showsGroupMuscles(of: chest))

        // One known key is enough to show what was chosen.
        chest.primaryMuscleKeys = ["neck", "triceps"]
        #expect(DefaultExerciseMuscles.muscles(of: chest).primary == [.triceps])
        #expect(DefaultExerciseMuscles.showsGroupMuscles(of: chest) == false)
    }

    @Test("The kinds of machine in the order of the sheet, with the prototype's names")
    func machineTypes() {
        #expect(MachineType.allCases == [.plates, .lever, .track, .graviton, .ghd])
        #expect(String(localized: MachineType.plates.displayName) == "Máquina de placas")
        #expect(String(localized: MachineType.graviton.explanation) == "O peso ajuda você a subir: mais kg deixa o exercício mais fácil.")
    }
}
