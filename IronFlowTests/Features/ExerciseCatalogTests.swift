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

    /// `names` in the catalog's alphabetical order (checked on its own in `alphabeticalAndActiveOnly`).
    private func alphabetical(_ names: [String]) -> [String] {
        names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // MARK: - Items

    @Test("Items are the active exercises in alphabetical order, as in the model")
    func alphabeticalAndActiveOnly() {
        let all = items(library + [custom("Meu Arquivado", .chest, archived: true)])

        #expect(all.count == 420)
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
        #expect(dorsais.count == 39)
        #expect(dorsais.contains { $0.name == "Minha Remada" })
    }

    @Test("A group keeps its exercises; Meus keeps the custom ones of every group")
    func groupAndMine() {
        let all = items(library + [custom("Meu Supino", .chest), custom("Minha Remada", .back)])

        let chest = ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "")
        #expect(chest.count == 59)
        #expect(chest.allSatisfy { $0.group == .chest })
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "")) == ["Meu Supino", "Minha Remada"])
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "").count == 422)
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
        #expect(ExerciseCatalog.equipment(for: .group(.chest), in: all) == [.barbell, .dumbbell, .machine, .cable, .smith, .bodyweight, .band, .plate])
        #expect(ExerciseCatalog.equipment(for: .group(.glutes), in: all) == [.barbell, .dumbbell, .machine, .cable, .smith, .bodyweight, .kettlebell, .band])
        #expect(ExerciseCatalog.equipment(for: .group(.fullBody), in: all) == [.barbell, .dumbbell, .bodyweight, .kettlebell])
        #expect(ExerciseCatalog.equipment(for: .group(.lowerBack), in: all) == [.barbell, .dumbbell, .machine, .bodyweight, .kettlebell, .plate])
        #expect(ExerciseCatalog.equipment(for: .group(.adductors), in: all) == [.machine, .cable, .bodyweight, .band])
        // Custom exercises have no equipment.
        #expect(ExerciseCatalog.equipment(for: .mine, in: all).isEmpty)
    }

    @Test("The chosen equipment is unselected when the new group has none of it, and kept otherwise")
    func unavailableEquipmentIsUnselected() {
        let all = items(library)

        #expect(ExerciseCatalog.equipment(.kettlebell, for: .group(.chest), in: all) == nil)
        #expect(ExerciseCatalog.equipment(.kettlebell, for: .group(.glutes), in: all) == .kettlebell)
        #expect(ExerciseCatalog.equipment(.band, for: .group(.chest), in: all) == .band)
        #expect(ExerciseCatalog.equipment(.dumbbell, for: .group(.chest), in: all) == .dumbbell)
        #expect(ExerciseCatalog.equipment(.kettlebell, for: .all, in: all) == .kettlebell)
        #expect(ExerciseCatalog.equipment(.barbell, for: .mine, in: all) == nil)
        #expect(ExerciseCatalog.equipment(nil, for: .group(.chest), in: all) == nil)
    }

    @Test("Peito with Halteres shows its 12 exercises, and a custom exercise never shows with an equipment")
    func groupWithEquipment() {
        let all = items(library + [custom("Meu Supino com Halter", .chest)])

        let chestDumbbells = ExerciseCatalog.filtered(all, group: .group(.chest), equipment: .dumbbell, search: "")
        #expect(names(chestDumbbells) == alphabetical([
            "Crucifixo (Halter)", "Crucifixo Declinado (Halter)", "Crucifixo Inclinado (Halter)",
            "Supino Declinado (Halter)", "Supino Inclinado (Halter)", "Supino Inclinado Pegada Neutra (Halter)",
            "Supino Inclinado Unilateral (Halter)", "Supino no Chão (Halter)", "Supino Reto (Halter)",
            "Supino Reto Pegada Neutra (Halter)", "Supino Reto Unilateral (Halter)", "Supino Squeeze (Halter)",
        ]))
        let dumbbells = ExerciseCatalog.filtered(all, group: .all, equipment: .dumbbell, search: "halter")
        #expect(!dumbbells.contains { $0.isCustom })
    }

    // MARK: - Search

    @Test("The search ignores case, diacritics and surrounding spaces, and matches any part of the name")
    func searchWithoutAccents() {
        let all = items(library)

        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "  ELEVACAO PELVICA ")) == alphabetical([
            "Elevação Pélvica (Barra)", "Elevação Pélvica (Halter)", "Elevação Pélvica (Máquina)", "Elevação Pélvica (Smith)",
            "Elevação Pélvica Unilateral", "Elevação Pélvica Unilateral (Máquina)",
        ]))
        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "graviton")) == [
            "Barra Fixa (Graviton)", "Barra Fixa Supinada (Graviton)", "Peito na Paralela (Graviton)", "Tríceps na Paralela (Graviton)",
        ])
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "supino xyz").isEmpty)
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "   ").count == 420)
    }

    @Test("The search finds the names with every word typed, in any order, ignoring case, diacritics and extra spaces")
    func searchByWords() {
        let all = items(library)
        func search(_ text: String) -> [String] {
            names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: text))
        }
        let benchWithBarbell = alphabetical([
            "Supino Declinado (Barra)", "Supino Fechado (Barra)", "Supino Guilhotina (Barra)", "Supino Inclinado (Barra)",
            "Supino Landmine (Barra)", "Supino no Chão (Barra)", "Supino Reto (Barra)", "Supino Reto Pegada Aberta (Barra)",
        ])

        // Any order.
        #expect(search("supino barra") == benchWithBarbell)
        #expect(search("barra supino") == benchWithBarbell)
        // Case, diacritics and extra spaces, tabs and line breaks between and around the words.
        #expect(search("  BARRA   Supino \t\n") == benchWithBarbell)
        #expect(search("EXTENSAO   triceps  CABEÇA") == alphabetical([
            "Extensão de Tríceps Acima da Cabeça (Barra W)", "Extensão de Tríceps Acima da Cabeça (Elástico)",
            "Extensão de Tríceps Acima da Cabeça (Halter)", "Extensão de Tríceps Acima da Cabeça (Máquina)",
            "Extensão de Tríceps Acima da Cabeça (Polia)", "Extensão de Tríceps Acima da Cabeça Unilateral (Polia)",
        ]))
        // Each word may be any part of the name, or of the name of a built-in exercise's equipment.
        #expect(search("sup barr") == alphabetical([
            "Barra Fixa (Pegada Supinada)", "Barra Fixa Supinada (Graviton)", "Barra Fixa Supinada com Peso (Anilha)",
            "Remada Curvada Supinada (Barra)",
        ] + benchWithBarbell))
        // A word that no name has leaves nothing, even with words that match.
        #expect(search("supino barra xyz").isEmpty)
        #expect(search("xyz").isEmpty)
        // An empty search keeps every exercise.
        #expect(search("").count == 420)
        #expect(search(" \t ").count == 420)
    }

    @Test("A built-in exercise is also found by the name of its equipment, in any order, ignoring case and diacritics; a custom one only by its name")
    func searchByEquipment() {
        let all = items(library + [custom("Meu Supino", .chest), custom("Meu Supino com Halteres", .chest)])
        func search(_ text: String) -> [ExerciseCatalog.Item] {
            ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: text)
        }

        // "halteres", the name of the filter, finds every exercise done with dumbbells, whose names say
        // "(Halter)", and the custom exercise whose own name has it.
        let dumbbells = all.filter { $0.equipment == .dumbbell }
        #expect(dumbbells.count == 78)
        #expect(names(search("halteres")) == alphabetical(names(dumbbells) + ["Meu Supino com Halteres"]))
        #expect(!search("halteres").contains { $0.name == "Meu Supino" })
        // With other words of the name, in any order, ignoring case and diacritics.
        let benchWithDumbbells = alphabetical([
            "Supino Declinado (Halter)", "Supino Fechado (Halter)", "Supino Inclinado (Halter)",
            "Supino Inclinado Pegada Neutra (Halter)", "Supino Inclinado Unilateral (Halter)", "Supino no Chão (Halter)",
            "Supino Reto (Halter)", "Supino Reto Pegada Neutra (Halter)", "Supino Reto Unilateral (Halter)",
            "Supino Squeeze (Halter)",
        ])
        #expect(names(search("supino halteres")) == alphabetical(benchWithDumbbells + ["Meu Supino com Halteres"]))
        #expect(names(search("HALTERES  supino")) == names(search("supino halteres")))
        // "peso do corpo" finds the exercises done with the body only, whose names have no equipment.
        let bodyweight = all.filter { $0.equipment == .bodyweight }
        #expect(bodyweight.count == 67)
        #expect(names(search("PESO DO CORPO")) == names(bodyweight))
        #expect(names(search("corpo peso")) == names(bodyweight))
        #expect(names(search("flexao peso do corpo")).allSatisfy { $0.hasPrefix("Flexão") })
        #expect(search("flexao peso do corpo").count == 12)
        // "maquina", without its accent, finds the machines, the Graviton ones too.
        #expect(names(search("graviton maquina")) == [
            "Barra Fixa (Graviton)", "Barra Fixa Supinada (Graviton)", "Peito na Paralela (Graviton)", "Tríceps na Paralela (Graviton)",
        ])
        // A custom exercise has no equipment: only its name counts.
        #expect(search("meu supino peso").isEmpty)
        #expect(search("meu polia").isEmpty)
    }

    @Test("Search, group and equipment work together")
    func combinedFilters() {
        let all = items(library + [custom("Meu Supino Inclinado", .chest)])

        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: .dumbbell, search: "inclinado")) == alphabetical([
            "Crucifixo Inclinado (Halter)", "Supino Inclinado (Halter)", "Supino Inclinado Pegada Neutra (Halter)",
            "Supino Inclinado Unilateral (Halter)",
        ]))
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "inclinado")) == alphabetical([
            "Crucifixo Inclinado (Halter)", "Crucifixo Inclinado (Máquina)", "Crucifixo Inclinado (Polia)",
            "Meu Supino Inclinado", "Supino Inclinado (Barra)", "Supino Inclinado (Halter)", "Supino Inclinado (Máquina)",
            "Supino Inclinado (Polia)", "Supino Inclinado (Smith)", "Supino Inclinado Iso-Lateral (Máquina)",
            "Supino Inclinado Pegada Neutra (Halter)", "Supino Inclinado Unilateral (Halter)",
            "Supino Inclinado Unilateral (Máquina)", "Supino Inclinado Unilateral (Polia)",
        ]))
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "inclinado")) == ["Meu Supino Inclinado"])
        #expect(ExerciseCatalog.filtered(all, group: .group(.back), equipment: .smith, search: "supino").isEmpty)
        // Several words with a group or an equipment.
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "barra supino")) == alphabetical([
            "Supino Declinado (Barra)", "Supino Guilhotina (Barra)", "Supino Inclinado (Barra)", "Supino Landmine (Barra)",
            "Supino no Chão (Barra)", "Supino Reto (Barra)", "Supino Reto Pegada Aberta (Barra)",
        ]))
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.triceps), equipment: nil, search: "fechado supino")) == [
            "Supino Fechado (Barra)", "Supino Fechado (Halter)", "Supino Fechado (Smith)",
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

    @Test("The count reads 420 exercícios, 1 exercício and 0 exercícios, never 0 exercício")
    func countText() {
        #expect(ExerciseCatalog.countText(420) == "420 exercícios")
        #expect(ExerciseCatalog.countText(6) == "6 exercícios")
        #expect(ExerciseCatalog.countText(2) == "2 exercícios")
        #expect(ExerciseCatalog.countText(1) == "1 exercício")
        #expect(ExerciseCatalog.countText(0) == "0 exercícios")
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
        #expect(first.count == 421)

        exercises[420].name = "Meu Supino Reto"
        #expect(cache.items(for: exercises).contains { $0.name == "Meu Supino Reto" })
        #expect(cache.builds == 2)

        exercises[420].isArchived = true
        #expect(cache.items(for: exercises).count == 420)
        #expect(cache.builds == 3)
    }

    // MARK: - Exercises of the user's own

    private func custom(_ name: String, _ group: MuscleGroup, equipment: Equipment?, archived: Bool = false) -> Exercise {
        let exercise = custom(name, group, archived: archived)
        exercise.equipment = equipment
        return exercise
    }

    private func lists(_ exercises: [Exercise]) -> ExerciseCatalog.Lists {
        ExerciseCatalog.lists(from: exercises.map { ExerciseCatalog.Source($0) })
    }

    @Test("An exercise of the user's own shows its equipment and no focus; its equipment filter keeps it")
    func customEquipment() {
        let all = items(library + [custom("Puxada na Máquina Articulada", .back, equipment: .machine), custom("Meu Outro", .back, equipment: nil)])
        let machine = all.first { $0.name == "Puxada na Máquina Articulada" }
        #expect(machine?.equipment == .machine)
        #expect(machine?.focus == nil)
        let other = all.first { $0.name == "Meu Outro" }
        #expect(other != nil)
        #expect(other?.equipment == nil)

        let mine = ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "")
        #expect(names(mine) == ["Meu Outro", "Puxada na Máquina Articulada"])
        #expect(ExerciseCatalog.equipment(for: .mine, in: all) == [.machine])
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: .machine, search: "")) == ["Puxada na Máquina Articulada"])
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.back), equipment: .machine, search: "puxada articulada")) == ["Puxada na Máquina Articulada"])
    }

    @Test("An exercise of the user's own is found by its equipment's name, never by \"Outro\"")
    func customSearchByEquipment() {
        let all = items([custom("Remada Cavalinho", .upperBack, equipment: .machine), custom("Remada Livre", .upperBack, equipment: nil)])
        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "remada maquina")) == ["Remada Cavalinho"])
        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "MÁQUINA")) == ["Remada Cavalinho"])
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "outro").isEmpty)
        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "livre")) == ["Remada Livre"])
    }

    @Test("The archived exercises of the user's own are apart: out of the count and the filters, at the end of Meus without search or equipment")
    func archivedCustom() {
        let active = custom("Agachamento Pêndulo", .quadriceps, equipment: .machine)
        let archived = custom("Puxada na Máquina Articulada", .back, equipment: .machine, archived: true)
        let archivedBuiltIn = builtIn(DefaultExerciseLibrary.all[0])
        archivedBuiltIn.isArchived = true
        let result = lists(Array(library.dropFirst()) + [active, archived, archivedBuiltIn])

        #expect(result.active.count == DefaultExerciseLibrary.all.count)
        #expect(names(result.archived) == ["Puxada na Máquina Articulada"])
        #expect(result.archived.allSatisfy { $0.isArchived })
        #expect(result.hasCustom)
        #expect(ExerciseCatalog.archivedShown(result.archived, group: .mine, equipment: nil, search: "  ").map(\.name) == ["Puxada na Máquina Articulada"])
        #expect(ExerciseCatalog.archivedShown(result.archived, group: .mine, equipment: .machine, search: "").isEmpty)
        #expect(ExerciseCatalog.archivedShown(result.archived, group: .mine, equipment: nil, search: "puxada").isEmpty)
        #expect(ExerciseCatalog.archivedShown(result.archived, group: .all, equipment: nil, search: "").isEmpty)
        // Never in the active list nor found by the search.
        #expect(ExerciseCatalog.filtered(result.active, group: .all, equipment: nil, search: "puxada na maquina articulada").isEmpty)
    }

    @Test("Meus is offered in the tab with an archived exercise of the user's own only; in the picker only with an active one")
    func mineWithArchivedOnly() {
        let archived = custom("Puxada na Máquina Articulada", .back, equipment: .machine, archived: true)
        let result = lists(library + [archived])
        #expect(result.hasCustom)
        #expect(ExerciseCatalog.groupFilters(in: result.active, hasArchivedCustom: !result.archived.isEmpty).contains(.mine))
        #expect(ExerciseCatalog.groupFilter(.mine, in: result.active, hasArchivedCustom: true) == .mine)
        // The picker reads only the active exercises.
        #expect(ExerciseCatalog.groupFilters(in: result.active).contains(.mine) == false)
        #expect(ExerciseCatalog.groupFilter(.mine, in: result.active) == .all)
        // Nothing of the user's own: no Meus anywhere.
        #expect(lists(library).hasCustom == false)
    }
}
