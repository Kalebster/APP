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

        #expect(all.count == 157)
        #expect(!all.contains { $0.name == "Meu Arquivado" })
        #expect(Array(names(all).prefix(10)) == [
            "Abdominal Bicicleta", "Abdominal com Anilha", "Abdominal com Roda", "Abdominal Infra",
            "Abdominal na Máquina", "Abdominal na Polia", "Abdominal Oblíquo", "Abdominal Supra",
            "Abdução com Elástico", "Abdução de Quadril na Polia",
        ])
        let sorted = names(all).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        #expect(names(all) == sorted)
    }

    @Test("A built-in exercise shows the equipment and focus of the library; a custom one has none")
    func equipmentAndFocus() throws {
        let all = items(library + [custom("Meu Supino", .chest)])

        let bench = try #require(all.first { $0.name == "Supino Reto com Barra" })
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

    @Test("The group filters are Todos, the groups with an exercise in the group order, and Meus only with a custom exercise")
    func groupFilters() {
        let groups = MuscleGroup.allCases.filter { $0 != .other }.map(ExerciseCatalog.GroupFilter.group)
        let withoutMine: [ExerciseCatalog.GroupFilter] = [.all] + groups
        let withMine: [ExerciseCatalog.GroupFilter] = [.all, .mine] + groups
        #expect(ExerciseCatalog.groupFilters(in: items(library)) == withoutMine)
        #expect(ExerciseCatalog.groupFilters(in: items(library + [custom("Meu Supino", .chest)])) == withMine)
        // An archived custom exercise does not count; a group without exercises is not offered.
        let few = items([custom("Arquivado", .abs, archived: true), builtIn(DefaultExerciseLibrary.all[0])])
        #expect(ExerciseCatalog.groupFilters(in: few) == [.all, .group(.chest)])
    }

    @Test("A group keeps its exercises; Meus keeps the custom ones of every group")
    func groupAndMine() {
        let all = items(library + [custom("Meu Supino", .chest), custom("Minha Remada", .back)])

        let chest = ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "")
        #expect(chest.count == 22)
        #expect(chest.allSatisfy { $0.group == .chest })
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "")) == ["Meu Supino", "Minha Remada"])
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "").count == 159)
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

    @Test("Peito with Halteres shows the 6 exercises of the model, and a custom exercise never shows with an equipment")
    func groupWithEquipment() {
        let all = items(library + [custom("Meu Supino com Halteres", .chest)])

        let chestDumbbells = ExerciseCatalog.filtered(all, group: .group(.chest), equipment: .dumbbell, search: "")
        #expect(names(chestDumbbells) == [
            "Crucifixo Inclinado com Halteres", "Crucifixo Reto com Halteres", "Pullover com Halter",
            "Supino Declinado com Halteres", "Supino Inclinado com Halteres", "Supino Reto com Halteres",
        ])
        let dumbbells = ExerciseCatalog.filtered(all, group: .all, equipment: .dumbbell, search: "halteres")
        #expect(!dumbbells.contains { $0.isCustom })
    }

    // MARK: - Search

    @Test("The search ignores case, diacritics and surrounding spaces, and matches any part of the name")
    func searchWithoutAccents() {
        let all = items(library)

        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "  ELEVACAO PELVICA ")) == [
            "Elevação Pélvica com Barra", "Elevação Pélvica na Máquina", "Elevação Pélvica no Smith",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "pronada")) == ["Barra Fixa Pronada"])
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "supino xyz").isEmpty)
        #expect(ExerciseCatalog.filtered(all, group: .all, equipment: nil, search: "   ").count == 157)
    }

    @Test("Search, group and equipment work together")
    func combinedFilters() {
        let all = items(library + [custom("Meu Supino Inclinado", .chest)])

        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: .dumbbell, search: "inclinado")) == [
            "Crucifixo Inclinado com Halteres", "Supino Inclinado com Halteres",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .group(.chest), equipment: nil, search: "inclinado")) == [
            "Crucifixo Inclinado com Halteres", "Meu Supino Inclinado", "Supino Inclinado com Barra",
            "Supino Inclinado com Halteres", "Supino Inclinado na Máquina", "Supino Inclinado no Smith",
        ])
        #expect(names(ExerciseCatalog.filtered(all, group: .mine, equipment: nil, search: "inclinado")) == ["Meu Supino Inclinado"])
        #expect(ExerciseCatalog.filtered(all, group: .group(.back), equipment: .smith, search: "supino").isEmpty)
    }

    @Test("Only a group other than Todos or an equipment counts as filtering, never the search")
    func isFiltering() {
        #expect(!ExerciseCatalog.isFiltering(group: .all, equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .mine, equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .group(.chest), equipment: nil))
        #expect(ExerciseCatalog.isFiltering(group: .all, equipment: .band))
    }

    @Test("The count reads 157 exercícios, 1 exercício")
    func countText() {
        #expect(ExerciseCatalog.countText(157) == "157 exercícios")
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
        #expect(first.count == 158)

        exercises[157].name = "Meu Supino Reto"
        #expect(cache.items(for: exercises).contains { $0.name == "Meu Supino Reto" })
        #expect(cache.builds == 2)

        exercises[157].isArchived = true
        #expect(cache.items(for: exercises).count == 157)
        #expect(cache.builds == 3)
    }
}
