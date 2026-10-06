import Foundation
import Testing
@testable import IronFlow

@MainActor
struct ExerciseListFilterTests {
    private func exercise(_ name: String, _ group: MuscleGroup, custom: Bool = false, archived: Bool = false) -> Exercise {
        let exercise = Exercise(name: name, muscleGroup: group, isCustom: custom)
        exercise.isArchived = archived
        return exercise
    }

    private func names(_ sections: [ExerciseListFilter.Section]) -> [[String]] {
        sections.map { $0.exercises.map(\.name) }
    }

    private var sample: [Exercise] {
        [
            exercise("Remada Curvada com Barra", .back),
            exercise("Supino Reto com Barra", .chest),
            exercise("Elevação Pélvica com Barra", .glutes),
            exercise("Barra Fixa", .back),
            exercise("Crucifixo com Halteres", .chest),
            exercise("Meu Supino", .chest, custom: true),
        ]
    }

    @Test("Without search or filter, all active exercises appear in sections following the group order")
    func allInGroupOrder() {
        let sections = ExerciseListFilter.sections(from: sample, search: "", group: nil)

        #expect(sections.map(\.group) == [.chest, .back, .glutes])
        #expect(sections.flatMap(\.exercises).count == 6)
    }

    @Test("Inside a section, names follow Portuguese alphabetical order")
    func alphabeticalInsideSections() {
        let exercises = [
            exercise("Barra", .back),
            exercise("Ábaco", .back),
            exercise("abdominal", .back),
            exercise("Zebra", .back),
        ]

        let sections = ExerciseListFilter.sections(from: exercises, search: "", group: nil)
        #expect(names(sections) == [["Ábaco", "abdominal", "Barra", "Zebra"]])
    }

    @Test("Archived exercises never appear")
    func archivedHidden() {
        let exercises = sample + [exercise("Supino Antigo", .chest, archived: true)]

        let all = ExerciseListFilter.sections(from: exercises, search: "", group: nil)
        let searched = ExerciseListFilter.sections(from: exercises, search: "antigo", group: nil)

        #expect(!all.flatMap(\.exercises).contains { $0.name == "Supino Antigo" })
        #expect(searched.isEmpty)
    }

    @Test("Search matches part of the name ignoring case and diacritics")
    func searchIgnoresCaseAndDiacritics() {
        #expect(names(ExerciseListFilter.sections(from: sample, search: "SUPINO", group: nil)) == [["Meu Supino", "Supino Reto com Barra"]])
        #expect(names(ExerciseListFilter.sections(from: sample, search: "elevacao", group: nil)) == [["Elevação Pélvica com Barra"]])
        #expect(names(ExerciseListFilter.sections(from: sample, search: "PÉLV", group: nil)) == [["Elevação Pélvica com Barra"]])
    }

    @Test("Search ignores leading and trailing whitespace; blank search shows everything")
    func searchWhitespace() {
        #expect(names(ExerciseListFilter.sections(from: sample, search: "  fixa \n", group: nil)) == [["Barra Fixa"]])
        #expect(ExerciseListFilter.sections(from: sample, search: "   ", group: nil).flatMap(\.exercises).count == 6)
    }

    @Test("A group filter keeps only that group, in a single section")
    func groupFilter() {
        let sections = ExerciseListFilter.sections(from: sample, search: "", group: .back)

        #expect(sections.map(\.group) == [.back])
        #expect(names(sections) == [["Barra Fixa", "Remada Curvada com Barra"]])
    }

    @Test("Search and group filter work together")
    func searchAndFilter() {
        #expect(names(ExerciseListFilter.sections(from: sample, search: "barra", group: .chest)) == [["Supino Reto com Barra"]])
        #expect(ExerciseListFilter.sections(from: sample, search: "supino", group: .back).isEmpty)
    }

    @Test("Groups without matching exercises have no section")
    func noEmptySections() {
        let sections = ExerciseListFilter.sections(from: sample, search: "crucifixo", group: nil)

        #expect(sections.map(\.group) == [.chest])
        #expect(sections.allSatisfy { !$0.exercises.isEmpty })
    }

    @Test("Custom exercises keep their custom flag for the label")
    func customFlagKept() {
        let chest = ExerciseListFilter.sections(from: sample, search: "", group: .chest)
        let flags = Dictionary(uniqueKeysWithValues: chest.flatMap(\.exercises).map { ($0.name, $0.isCustom) })

        #expect(flags["Meu Supino"] == true)
        #expect(flags["Supino Reto com Barra"] == false)
    }

    @Test("With the real library, every group shows its approved number of exercises")
    func realLibraryCounts() {
        let library = DefaultExerciseLibrary.all.map { exercise($0.name, $0.muscleGroup) }

        let sections = ExerciseListFilter.sections(from: library, search: "", group: nil)

        #expect(sections.map(\.group) == MuscleGroup.allCases)
        let counts = Dictionary(uniqueKeysWithValues: sections.map { ($0.group, $0.exercises.count) })
        let expected = Dictionary(grouping: DefaultExerciseLibrary.all, by: \.muscleGroup).mapValues(\.count)
        #expect(counts == expected)
    }
}
