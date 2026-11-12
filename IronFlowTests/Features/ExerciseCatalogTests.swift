import Foundation
import Testing
@testable import IronFlow

@MainActor
struct ExerciseCatalogTests {
    private func builtIn(_ entry: DefaultExercise) -> Exercise {
        Exercise(name: entry.name, muscleGroup: entry.muscleGroup, isCustom: false, libraryKey: entry.key)
    }

    private func custom(_ name: String, _ group: MuscleGroup, archived: Bool = false) -> Exercise {
        let exercise = Exercise(name: name, muscleGroup: group, isCustom: true)
        exercise.isArchived = archived
        return exercise
    }

    /// The real library, every exercise active.
    private var library: [Exercise] {
        DefaultExerciseLibrary.all.map(builtIn)
    }

    private func items(_ exercises: [Exercise]) -> [ExerciseCatalog.Item] {
        ExerciseCatalog.items(from: exercises.map { ExerciseCatalog.Source($0) })
    }

    private func names(_ items: [ExerciseCatalog.Item]) -> [String] {
        items.map(\.name)
    }

    // MARK: - Items

    @Test("Items are the active exercises in alphabetical order, as in the model")
    func alphabeticalAndActiveOnly() {
        let all = items(library + [custom("Meu Arquivado", .chest, archived: true)])

        #expect(all.count == 220)
        #expect(!all.contains { $0.name == "Meu Arquivado" })
        #expect(Array(names(all).prefix(2)) == ["Abdominal", "Abdominal (Anilha)"])
        let sorted = names(all).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        #expect(names(all) == sorted)
    }

    @Test("A built-in exercise shows the equipment and focus of the library; a custom one has none")
    func equipmentAndFocus() throws {
        let all = items(library + [custom("Meu Supino", .chest)])

        let bench = try #require(all.first { $0.name == "Supino Reto (Barra)" })
        #expect(bench.equipment == .barbell)
        #expect(bench.focus == "Peitoral médio")
        #expect(bench.group == .chest)
        #expect(!bench.isCustom)
        let mine = try #require(all.first { $0.name == "Meu Supino" })
        #expect(mine.equipment == nil)
        #expect(mine.focus == nil)
        #expect(mine.isCustom)
    }

    // MARK: - Group filters

    @Test("The group filters are Todos, the groups with an exercise in the approved order, and Meus only with a custom exercise")
    func groupFilters() {
        let groups: [ExerciseCatalog.GroupFilter] = [
            .group(.chest), .group(.back), .group(.upperBack), .group(.traps), .group(.lowerBack), .group(.shoulders),
            .group(.biceps), .group(.triceps), .group(.forearms), .group(.abs), .group(.quadriceps),
            .group(.hamstrings), .group(.glutes), .group(.adductors), .group(.calves), .group(.fullBody),
        ]
        let withoutMine: [ExerciseCatalog.GroupFilter] = [.all] + groups
        let withMine: [ExerciseCatalog.GroupFilter] = [.all, .mine] + groups
        #expect(ExerciseCatalog.groupFilters(in: items(library)) == withoutMine)
        #expect(ExerciseCatalog.groupFilters(in: items(library + [custom("Meu Supino", .chest)])) == withMine)
        // An archived custom exercise does not count; a group without exercises is not offered.
        let few = items([custom("Arquivado", .abs, archived: true), builtIn(DefaultExerciseLibrary.all[0])])
        #expect(ExerciseCatalog.groupFilters(in: few) == [.all, .group(.chest)])
        let withoutAdductors = items(library.filter { $0.muscleGroup != .adductors })
        #expect(ExerciseCatalog.groupFilters(in: withoutAdductors) == [.all] + groups.filter { $0 != .group(.adductors) })
    }

    @Test("A custom exercise stored with back, as every back exercise was before, shows as Dorsais and in its filter")
    func customBackShowsAsDorsais() throws {
        let remada = custom("Minha Remada", .back)
        #expect(remada.muscleGroupRaw == "back")
        let all = items(library + [remada])

        let item = try #require(all.first { $0.name == "Minha Remada" })
        #expect(item.group == .back)
        #expect(String(localized: item.group.displayName) == "Dorsais")
        let dorsais = ExerciseCatalog.filtered(all, group: .group(.back), equipment: nil, search: "")
        #expect(dorsais.count == 21)
        #expect(dorsais.contains { $0.name == "Minha Remada" })
    }

    @Test("A group keeps its exercises; Meus keeps the custom ones of every group")
    func groupAndMine() {
        let all = items(library + [custom("Meu Supino", .chest), custom("Minha Remada", .back)])

        let chest = ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "")
        #expect(chest.count == 34)
        #expect(chest.allSatisfy { $0.group == .chest })
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "")) == ["Meu Supino", "Minha Remada"])
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "").count == 222)
    }

    @Test("A filter no longer offered falls back to Todos")
    func groupFilterFallsBack() {
        let all = items(library)
        #expect(ExerciseCatalog.groupFilter(.mine, in: all) == .all)
        #expect(ExerciseCatalog.groupFilter(.group(.other), in: all) == .all)
        #expect(ExerciseCatalog.groupFilter(.group(.calves), in: all) == .group(.calves))
    }

    // MARK: - Equipment

    @Test("Only the equipment of the selected group is offered, in the equipment order")
    func equipmentPerGroup() {
        let all = items(library + [custom("Meu Supino", .chest)])

        #expect(ExerciseCatalog.equipment(for: .all, in: all) == Equipment.allCases)
        #expect(ExerciseCatalog.equipment(for: .group(.chest), in: all) == [.barbell, .dumbbell, .machine, .cable, .smith, .bodyweight])
        #expect(ExerciseCatalog.equipment(for: .group(.glutes), in: all) == [.barbell, .dumbbell, .machine, .cable, .smith, .bodyweight, .band])
        #expect(ExerciseCatalog.equipment(for: .group(.fullBody), in: all) == [.barbell, .dumbbell, .bodyweight, .kettlebell])
        #expect(ExerciseCatalog.equipment(for: .group(.lowerBack), in: all) == [.barbell, .dumbbell, .machine, .bodyweight, .plate])
        #expect(ExerciseCatalog.equipment(for: .group(.adductors), in: all) == [.machine, .cable])
        // Custom exercises have no equipment.
        #expect(ExerciseCatalog.equipment(for: .mine, in: all).isEmpty)
    }

    @Test("The chosen equipment is unselected when the new group has none of it, and kept otherwise")
    func unavailableEquipmentIsUnselected() {
        let all = items(library)

        #expect(ExerciseCatalog.equipment(.band, for: .group(.chest), in: all) == nil)
        #expect(ExerciseCatalog.equipment(.band, for: .group(.glutes), in: all) == .band)
        #expect(ExerciseCatalog.equipment(.dumbbell, for: .group(.chest), in: all) == .dumbbell)
        #expect(ExerciseCatalog.equipment(.kettlebell, for: .all, in: all) == .kettlebell)
        #expect(ExerciseCatalog.equipment(.barbell, for: .mine, in: all) == nil)
        #expect(ExerciseCatalog.equipment(nil, for: .group(.chest), in: all) == nil)
    }

    @Test("Peito with Halteres shows its 5 exercises, and a custom exercise never shows with an equipment")
    func groupWithEquipment() {
        let all = items(library + [custom("Meu Supino com Halter", .chest)])

        let chestDumbbells = ExerciseCatalog.filtered(all, group: .group(.chest), equipment: .dumbbell, search: "")
        #expect(names(chestDumbbells) == [
            "Crucifixo (Halter)", "Crucifixo Inclinado (Halter)", "Supino Declinado (Halter)",
            "Supino Inclinado (Halter)", "Supino Reto (Halter)",
        ])
        let dumbbells = ExerciseCatalog.filtered(all, group: .all, equipment: .dumbbell, search: "halter")
        #expect(!dumbbells.contains { $0.isCustom })
    }

    // MARK: - Search

    @Test("The search ignores case, diacritics and surrounding spaces, and matches any part of the name")
    func searchWithoutAccents() {
        let all = items(library)

        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "  ELEVACAO PELVICA ")) == [
            "Elevação Pélvica (Barra)", "Elevação Pélvica (Máquina)", "Elevação Pélvica (Smith)",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "graviton")) == ["Barra Fixa (Graviton)"])
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "supino xyz").isEmpty)
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "   ").count == 220)
    }

    @Test("The search finds the names with every word typed, in any order, ignoring case, diacritics and extra spaces")
    func searchByWords() {
        let all = items(library)
        func search(_ text: String) -> [String] {
            names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: text))
        }
        let benchWithBarbell = [
            "Supino Declinado (Barra)", "Supino Fechado (Barra)", "Supino Inclinado (Barra)", "Supino Reto (Barra)",
        ]

        // Any order.
        #expect(search("supino barra") == benchWithBarbell)
        #expect(search("barra supino") == benchWithBarbell)
        // Case, diacritics and extra spaces, tabs and line breaks between and around the words.
        #expect(search("  BARRA   Supino \t\n") == benchWithBarbell)
        #expect(search("EXTENSAO   triceps  CABEÇA") == [
            "Extensão de Tríceps Acima da Cabeça (Barra W)", "Extensão de Tríceps Acima da Cabeça (Halter)",
            "Extensão de Tríceps Acima da Cabeça (Polia)",
        ])
        // Each word may be any part of the name.
        #expect(search("sup barr") == ["Barra Fixa (Pegada Supinada)", "Remada Curvada Supinada (Barra)"] + benchWithBarbell)
        // A word that no name has leaves nothing, even with words that match.
        #expect(search("supino barra xyz").isEmpty)
        #expect(search("xyz").isEmpty)
        // An empty search keeps every exercise.
        #expect(search("").count == 220)
        #expect(search(" \t ").count == 220)
    }

    @Test("Search, group and equipment work together")
    func combinedFilters() {
        let all = items(library + [custom("Meu Supino Inclinado", .chest)])

        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: .dumbbell, search: "inclinado")) == [
            "Crucifixo Inclinado (Halter)", "Supino Inclinado (Halter)",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "inclinado")) == [
            "Crucifixo Inclinado (Halter)", "Crucifixo Inclinado (Máquina)", "Crucifixo Inclinado (Polia)",
            "Meu Supino Inclinado", "Supino Inclinado (Barra)", "Supino Inclinado (Halter)", "Supino Inclinado (Máquina)",
            "Supino Inclinado (Polia)", "Supino Inclinado (Smith)",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "inclinado")) == ["Meu Supino Inclinado"])
        #expect(ExerciseCatalog.filtered(all, group: .group(.back), equipment: .smith, search: "supino").isEmpty)
        // Several words with a group or an equipment.
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "barra supino")) == [
            "Supino Declinado (Barra)", "Supino Inclinado (Barra)", "Supino Reto (Barra)",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.triceps), equipment: nil, search: "fechado supino")) == [
            "Supino Fechado (Barra)", "Supino Fechado (Smith)",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: .smith, search: "SUPINO  smith")) == [
            "Supino Declinado (Smith)", "Supino Fechado (Smith)", "Supino Inclinado (Smith)", "Supino Reto (Smith)",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "inclinado meu")) == ["Meu Supino Inclinado"])
    }

    @Test("Only a group other than Todos or an equipment counts as filtering, never the search")
    func isFiltering() {
        #expect(!ExerciseCatalog.isFiltering(group: .all, equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .mine, equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .group(.chest), equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .all, equipment: .band))
    }

    @Test("The count reads 220 exercícios, 1 exercício")
    func countText() {
        #expect(ExerciseCatalog.countText(220) == "220 exercícios")
        #expect(ExerciseCatalog.countText(6) == "6 exercícios")
        #expect(ExerciseCatalog.countText(1) == "1 exercício")
    }

    // MARK: - Cache

    @Test("The items are built once for the same exercises, and again only when one of them changes")
    func cacheBuildsOnlyOnChange() {
        let exercises = library + [custom("Meu Supino", .chest)]
        let cache = ExerciseCatalogCache()

        let first = cache.items(for: exercises)
        _ = cache.items(for: exercises)
        _ = cache.items(for: exercises)
        #expect(cache.builds == 1)
        #expect(first.count == 221)

        exercises[220].name = "Meu Supino Reto"
        #expect(cache.items(for: exercises).contains { $0.name == "Meu Supino Reto" })
        #expect(cache.builds == 2)

        exercises[220].isArchived = true
        #expect(cache.items(for: exercises).count == 220)
        #expect(cache.builds == 3)
    }
}
