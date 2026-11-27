import Foundation
import Testing
@testable import IronFlow

/// The rows of the Exercícios tab and of the picker: the 103 bases of the library and the exercises of the
/// user's own, the filters and the search.
@MainActor
struct ExerciseCatalogTests {
    private func custom(_ name: String, _ group: MuscleGroup, equipment: Equipment? = nil, archived: Bool = false) -> Exercise {
        let exercise = Exercise(name: name, muscleGroup: group, isCustom: true)
        exercise.equipment = equipment
        exercise.isArchived = archived
        return exercise
    }

    private func lists(_ exercises: [Exercise] = []) -> ExerciseCatalog.Lists {
        ExerciseCatalog.lists(from: exercises.map { ExerciseCatalog.Source($0) })
    }

    private func items(_ exercises: [Exercise] = []) -> [ExerciseCatalog.Item] {
        lists(exercises).active
    }

    private func names(_ items: [ExerciseCatalog.Item]) -> [String] {
        items.map(\.name)
    }

    private func search(_ text: String, in items: [ExerciseCatalog.Item]? = nil) -> [String] {
        names(ExerciseCatalog.filtered(items ?? self.items(), group: .all, equipment: nil, search: text))
    }

    // MARK: - Rows

    @Test("The rows are the 103 bases, in alphabetical order, with the active exercises of the user's own among them")
    func basesInAlphabeticalOrder() {
        let all = items([custom("Meu Supino", .chest), custom("Abdominal Meu", .abs)])
        #expect(all.count == 105)
        #expect(all.filter { $0.base != nil }.count == 103)
        #expect(names(all) == names(all).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(Array(names(all).prefix(3)) == ["Abdominal", "Abdominal Bicicleta", "Abdominal Canivete"])
        #expect(names(all).contains("Abdominal Meu") && names(all).contains("Meu Supino"))
        #expect(Set(all.filter { $0.base != nil }.map(\.name)) == Set(ExerciseBaseLibrary.all.map(\.name)))
    }

    @Test("A base's row: its group, its common equipment (3 and +N) and the icon of its first combination; no exercise of its own")
    func baseRow() throws {
        let all = items()
        let bench = try #require(all.first { $0.name == "Supino Reto" })
        #expect(bench.id == "base:Supino Reto")
        #expect(bench.group == .chest)
        #expect(bench.detail == "Barra, Halteres, Máquina +3")
        #expect(bench.equipment == .barbell)
        #expect(bench.exerciseID == nil && !bench.isCustom)
        #expect(bench.filterEquipment == [.barbell, .dumbbell, .machine, .smith, .cable])
        // Up to 3 common ones, all of them.
        let crossHigh = try #require(all.first { $0.name == "Crucifixo Alto" })
        #expect(crossHigh.detail == "Polia")
        // Puxada Alta opens on the cable, its first combination.
        let pulldown = try #require(all.first { $0.name == "Puxada Alta" })
        #expect(pulldown.equipment == .cable)
        #expect(pulldown.group == .back)
    }

    @Test("An exercise of the user's own: its equipment, or Outro, after its group; the archived ones apart")
    func customRow() throws {
        let result = lists([
            custom("Puxada na Máquina Articulada", .back, equipment: .machine),
            custom("Meu Outro", .abs),
            custom("Arquivado", .chest, equipment: .barbell, archived: true),
        ])
        let machine = try #require(result.active.first { $0.name == "Puxada na Máquina Articulada" })
        #expect(machine.isCustom && machine.base == nil && machine.exerciseID != nil)
        #expect(machine.detail == "Máquina")
        #expect(machine.equipment == .machine)
        #expect(machine.filterEquipment == [.machine])
        let other = try #require(result.active.first { $0.name == "Meu Outro" })
        #expect(other.detail == "Outro" && other.equipment == nil && other.filterEquipment.isEmpty)
        #expect(names(result.archived) == ["Arquivado"])
        #expect(!names(result.active).contains("Arquivado"))
    }

    @Test("A library exercise among the sources (a hidden one) is no row: its base is")
    func hiddenLibraryExerciseIsNoRow() {
        let hidden = Exercise(name: "Supino Reto (Kettlebell)", muscleGroup: .chest, isCustom: false, libraryKey: "supino-reto.kettlebell")
        hidden.isArchived = true
        let result = lists([hidden])
        #expect(result.active.count == 103 && result.archived.isEmpty)
        #expect(!result.hasCustom)
    }

    // MARK: - Group filters

    @Test("The group filters are Todos, the 16 groups in the approved order, and Meus only with an exercise of the user's own")
    func groupFilters() {
        let groups: [ExerciseCatalog.GroupFilter] = [
            .group(.chest), .group(.back), .group(.upperBack), .group(.traps), .group(.lowerBack), .group(.shoulders),
            .group(.biceps), .group(.triceps), .group(.forearms), .group(.abs), .group(.quadriceps),
            .group(.hamstrings), .group(.glutes), .group(.adductors), .group(.calves), .group(.fullBody),
        ]
        #expect(ExerciseCatalog.groupFilters(in: items()) == [.all] + groups)
        #expect(ExerciseCatalog.groupFilters(in: items([custom("Meu Supino", .chest)])) == [.all, .mine] + groups)
        // A custom exercise of a group no base has adds it.
        #expect(ExerciseCatalog.groupFilters(in: items([custom("Meu", .other)])).last == .group(.other))
    }

    @Test("A group keeps its bases and the user's own of it; Meus keeps the user's own of every group; a filter no longer offered falls back to Todos")
    func groupAndMine() {
        let all = items([custom("Meu Supino", .chest), custom("Minha Remada", .back)])
        let chest = ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "")
        #expect(chest.count == 10)
        #expect(chest.allSatisfy { $0.group == .chest })
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "")) == ["Meu Supino", "Minha Remada"])
        #expect(ExerciseCatalog.groupFilter(.mine, in: items()) == .all)
        #expect(ExerciseCatalog.groupFilter(.group(.other), in: items()) == .all)
        #expect(ExerciseCatalog.groupFilter(.group(.calves), in: items()) == .group(.calves))
    }

    @Test("A custom exercise stored with back, as every back exercise was before, shows as Dorsais and in its filter")
    func customBackShowsAsDorsais() throws {
        let remada = custom("Minha Remada", .back)
        #expect(remada.muscleGroupRaw == "back")
        let all = items([remada])
        let item = try #require(all.first { $0.name == "Minha Remada" })
        #expect(String(localized: item.group.displayName) == "Dorsais")
        let dorsais = ExerciseCatalog.filtered(all, group: .group(.back), equipment: nil, search: "")
        #expect(names(dorsais) == ["Barra Fixa", "Minha Remada", "Pullover", "Puxada Alta", "Remada Alta", "Remada Serrote"])
    }

    // MARK: - Equipment

    @Test("The equipment filter looks only at the common equipment of each base: none is offered that no base of the group has as common")
    func equipmentOnlyCommon() {
        let all = items()
        // No base of Peito has the kettlebell as common, though every one shows it in gray.
        #expect(!ExerciseCatalog.equipment(for: .group(.chest), in: all).contains(.kettlebell))
        #expect(ExerciseCatalog.equipment(.kettlebell, for: .group(.chest), in: all) == nil)
        #expect(ExerciseCatalog.equipment(.dumbbell, for: .group(.chest), in: all) == .dumbbell)
        let expected = Set(ExerciseBaseLibrary.all.filter { $0.group == .chest }.flatMap { $0.common.map(\.equipment) })
        #expect(Set(ExerciseCatalog.equipment(for: .group(.chest), in: all)) == expected)
        #expect(ExerciseCatalog.equipment(for: .group(.chest), in: all) == Equipment.allCases.filter(expected.contains))
        // Peito with Halteres: the bases with dumbbells as common.
        let chestDumbbells = ExerciseCatalog.filtered(all, group: .group(.chest), equipment: .dumbbell, search: "")
        #expect(names(chestDumbbells) == ["Crucifixo", "Supino Declinado", "Supino Inclinado", "Supino Reto"])
        // Barra W and Máquina iso-lateral count as Barra and Máquina; Graviton as Máquina.
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.biceps), equipment: .barbell, search: "spider")) == ["Rosca Spider"])
        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: .machine, search: "paralela")) == ["Peito na Paralela", "Tríceps na Paralela"])
        // An exercise of the user's own with "Outro" has no equipment, so choosing one leaves it out.
        let mine = items([custom("Meu Outro", .chest), custom("Minha Máquina", .chest, equipment: .machine)])
        #expect(names(ExerciseCatalog.filtered(mine, group: .mine, equipment: .machine, search: "")) == ["Minha Máquina"])
        #expect(ExerciseCatalog.equipment(for: .mine, in: mine) == [.machine])
    }

    // MARK: - Search

    @Test("The search finds a base by its name, ignoring case, diacritics and spaces around, with the words in any order")
    func searchByName() {
        #expect(search("  ELEVACAO PELVICA ") == ["Elevação Pélvica"])
        #expect(search("reto supino") == ["Supino Reto"])
        #expect(search("  SUPINO \t\n reto ") == ["Supino Reto"])
        #expect(search("pendular").contains("Agachamento Pendular"))
        #expect(search("").count == 103)
        #expect(search(" \t ").count == 103)
    }

    @Test("A base is found by the options of its second row, its common combinations and their equipment, never by a gray one")
    func searchByOptionsAndEquipment() {
        #expect(search("triangulo") == ["Puxada Alta", "Remada Baixa"])
        #expect(search("supinada barra fixa") == ["Barra Fixa"])
        #expect(search("puxada alta triângulo (polia)") == ["Puxada Alta"])
        #expect(search("rosca barra w").contains("Rosca Direta"))
        #expect(search("graviton barra fixa") == ["Barra Fixa"])
        // Kettlebell is only gray in Supino Reto: the search does not find it there.
        #expect(!search("supino kettlebell").contains("Supino Reto"))
        #expect(search("supino halteres") == ["Supino Declinado", "Supino Inclinado", "Supino Reto"])
        #expect(search("iso-lateral supino") == ["Supino Declinado", "Supino Inclinado", "Supino Reto"])
    }

    @Test("A base is found by its old names (renamed and merged exercises) and by its extra words (popular names)")
    func searchByOldAndPopularNames() {
        #expect(search("crossover polia alta") == ["Crucifixo Alto"])
        #expect(search("crossover polia media") == ["Crucifixo"])
        #expect(search("extensao triceps cabeca acima") == ["Tríceps Francês"])
        #expect(search("remada apoiada maquina").contains("Remada"))
        #expect(search("tibialis").isEmpty)
        #expect(search("elevacao de ponta dos pes") == ["Panturrilha em Pé"])
        #expect(search("hip thrust") == ["Elevação Pélvica"])
        #expect(search("terra romeno") == ["Stiff"])
        #expect(search("t-bar") == ["Remada na T-Bar"])
        #expect(search("mergulho").contains("Peito na Paralela"))
        #expect(search("pulley frente") == ["Puxada Alta"])
        // "Remada Alta (Barra)" was the upright row, now Remada Ombro: its old name finds it. The new Remada Alta
        // (Barra) is gray, so it does not.
        #expect(search("remada alta barra") == ["Remada Ombro"])
    }

    @Test("An exercise of the user's own is found by its name and its equipment's name, never by Outro")
    func searchCustom() {
        let all = items([custom("Remada Cavalinho Smart", .upperBack, equipment: .machine), custom("Remada Livre", .upperBack)])
        #expect(search("cavalinho smart maquina", in: all) == ["Remada Cavalinho Smart"])
        #expect(search("livre", in: all) == ["Remada Livre"])
        #expect(!search("outro", in: all).contains("Remada Livre"))
    }

    @Test("Search, group and equipment work together")
    func searchGroupAndEquipment() {
        let all = items()
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: .barbell, search: "supino")) == ["Supino Declinado", "Supino Inclinado", "Supino Reto"])
        #expect(ExerciseCatalog.filtered(all, group: .group(.biceps), equipment: nil, search: "supino").isEmpty)
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.triceps), equipment: nil, search: "supino")) == ["Supino Fechado"])
    }

    // MARK: - Counts, archived and the cache

    @Test("Only a group other than Todos or an equipment counts as filtering, never the search")
    func isFiltering() {
        #expect(!ExerciseCatalog.isFiltering(group: .all, equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .mine, equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .group(.chest), equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .all, equipment: .band))
    }

    @Test("The count reads 103 exercícios, 1 exercício and 0 exercícios, never 0 exercício")
    func countText() {
        #expect(ExerciseCatalog.countText(103) == "103 exercícios")
        #expect(ExerciseCatalog.countText(1) == "1 exercício")
        #expect(ExerciseCatalog.countText(0) == "0 exercícios")
    }

    @Test("The archived exercises of the user's own are apart: out of the count and the filters, at the end of Meus without search or equipment")
    func archivedCustom() {
        let result = lists([
            custom("Agachamento Pêndulo", .quadriceps, equipment: .machine),
            custom("Puxada na Máquina Articulada", .back, equipment: .machine, archived: true),
        ])
        #expect(result.active.count == 104)
        #expect(names(result.archived) == ["Puxada na Máquina Articulada"])
        #expect(ExerciseCatalog.archivedShown(result.archived, group: .mine, equipment: nil, search: "  ").map(\.name) == ["Puxada na Máquina Articulada"])
        #expect(ExerciseCatalog.archivedShown(result.archived, group: .mine, equipment: .machine, search: "").isEmpty)
        #expect(ExerciseCatalog.archivedShown(result.archived, group: .mine, equipment: nil, search: "puxada").isEmpty)
        #expect(ExerciseCatalog.archivedShown(result.archived, group: .all, equipment: nil, search: "").isEmpty)
        #expect(ExerciseCatalog.filtered(result.active, group: .all, equipment: nil, search: "puxada na maquina articulada").isEmpty)
    }

    @Test("Meus is offered in the tab with an archived exercise of the user's own only; in the picker only with an active one")
    func mineWithArchivedOnly() {
        let result = lists([custom("Puxada na Máquina Articulada", .back, equipment: .machine, archived: true)])
        #expect(result.hasCustom)
        #expect(ExerciseCatalog.groupFilters(in: result.active, hasArchivedCustom: !result.archived.isEmpty).contains(.mine))
        #expect(ExerciseCatalog.groupFilter(.mine, in: result.active, hasArchivedCustom: true) == .mine)
        #expect(!ExerciseCatalog.groupFilters(in: result.active).contains(.mine))
        #expect(lists().hasCustom == false)
    }

    @Test("The rows are built once for the same exercises of the user's own, again only when one of them changes, and never for the library's")
    func cacheBuildsOnlyOnChange() {
        let mine = custom("Meu Supino", .chest)
        let library = Exercise(name: "Supino Reto (Barra)", muscleGroup: .chest, isCustom: false, libraryKey: "bench-press-barbell")
        let cache = ExerciseCatalogCache()

        #expect(cache.items(for: [mine, library]).count == 104)
        _ = cache.items(for: [mine, library])
        _ = cache.items(for: [mine])
        #expect(cache.builds == 1)

        mine.name = "Meu Supino Reto"
        #expect(cache.items(for: [mine]).contains { $0.name == "Meu Supino Reto" })
        #expect(cache.builds == 2)

        mine.isArchived = true
        #expect(cache.items(for: [mine]).count == 103)
        #expect(cache.builds == 3)
    }

    @Test("The bases' search text is computed once: the same string object every time")
    func searchKeysComputedOnce() {
        #expect(ExerciseBaseIndex.searchKeys.count == 103)
        #expect(ExerciseCatalog.baseItems.map(\.searchKey) == ExerciseBaseLibrary.all.map { ExerciseBaseIndex.searchKeys[$0.name] ?? "" })
    }
}
