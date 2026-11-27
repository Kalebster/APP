import Foundation
import Testing
@testable import IronFlow

/// The library against the approved base list (design/lista-base-dados.json, the owner's approval of
/// 26/11/2026), read from the repository: what the app reads from its own `ExerciseLibrary.json` (the
/// combinations, with their muscles and kind of machine) and what its code has (the bases, the retired
/// exercises and the junctions) must be exactly what was approved.
struct DefaultExerciseLibraryTests {
    let library = DefaultExerciseLibrary.all
    let bases = ExerciseBaseLibrary.all

    // MARK: - The approved file

    private struct Approved: Decodable {
        struct Counts: Decodable {
            let bases: Int
            let combinacoes: Int
            let comuns: Int
            let biblioteca_de_hoje: Int
            let continuam_com_o_mesmo_nome: Int
            let renomeados: Int
            let juncoes: Int
            let saem: Int
            let combinacoes_novas: Int
        }

        struct SecondRow: Decodable {
            let titulo: String
            let opcoes: [String]
            let abre_em: String
        }

        struct Base: Decodable {
            let nome: String
            let grupo: String
            let busca_extra: String
            let equipamentos: [String]
            let comuns: [String]
            let segunda_fila: SecondRow?
        }

        struct Muscles: Decodable {
            let principais: [String]
            let secundarios: [String]
        }

        struct Combination: Decodable {
            let nome: String
            let base: String
            let grupo: String
            let equipamento: String
            let filtro_e_icone: String
            let segunda_fila: String?
            let foco: String
            let comum: Bool
            let musculos: Muscles
            let tipo_de_maquina: String?
            let na_biblioteca_de_hoje: [String]?
        }

        struct Junction: Decodable {
            let nome_novo: String
            let antigos: [String]
        }

        let conferencia: Counts
        let equipamentos_padrao: [String]
        let nomes_dos_musculos: [String: String]
        let tipos_de_maquina: [String: [String]]
        let bases: [Base]
        let combinacoes: [Combination]
        let renomeados: [String: String]
        let juncoes: [Junction]
        let saem: [String]
    }

    private static func approved() throws -> Approved {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appending(path: "design/lista-base-dados.json"))
        return try JSONDecoder().decode(Approved.self, from: data)
    }

    private static func text(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    @Test("The approved counts: 103 bases, 1,525 combinations, 391 common; of the 420 of before, 283 with the same name, 32 renamed, 4 junctions and 105 that leave; 1,214 new")
    func counts() throws {
        let approved = try Self.approved()
        #expect(approved.conferencia.bases == 103 && bases.count == 103)
        #expect(approved.conferencia.combinacoes == 1_525 && library.count == 1_525)
        #expect(approved.conferencia.comuns == 391 && library.filter(\.isCommon).count == 391)
        #expect(approved.conferencia.biblioteca_de_hoje == 420 && Library420Fixture.entries.count == 420)
        let before = Dictionary(uniqueKeysWithValues: Library420Fixture.entries.map { ($0.key, $0) })
        let stayed = library.filter { before[$0.key] != nil }
        #expect(stayed.count == 311)
        #expect(stayed.filter { before[$0.key]?.name == $0.name }.count == 283)
        #expect(approved.conferencia.continuam_com_o_mesmo_nome == 283)
        #expect(approved.conferencia.renomeados == 32 && approved.renomeados.count == 32)
        #expect(approved.conferencia.juncoes == 4 && RetiredExercises.junctions.count == 4)
        #expect(approved.conferencia.saem == 105 && RetiredExercises.all.count == 105)
        #expect(approved.conferencia.combinacoes_novas == 1_214 && library.count - stayed.count == 1_214)
    }

    @Test("The bases are the approved ones, in their order: name, group, extra search words, the fixed order of the equipment, the common ones and the second row")
    func basesAreTheApprovedOnes() throws {
        let approved = try Self.approved()
        #expect(bases.map(\.name) == approved.bases.map(\.nome))
        for (base, line) in zip(bases, approved.bases) {
            #expect(Self.text(base.group.displayName) == line.grupo, "\(base.name)")
            #expect(base.extraSearch == line.busca_extra, "\(base.name)")
            #expect(base.equipment.map { Self.text($0.displayName) } == line.equipamentos, "\(base.name)")
            #expect(base.common.map { Self.text($0.displayName) } == line.comuns, "\(base.name)")
            #expect(base.secondRow?.options == line.segunda_fila?.opcoes, "\(base.name)")
            #expect(base.secondRow?.opensOn == line.segunda_fila?.abre_em, "\(base.name)")
            let title = base.secondRow.map { $0.kind == .grip ? "PEGADA" : "VARIAÇÃO" }
            #expect(title == line.segunda_fila?.titulo, "\(base.name)")
        }
    }

    @Test("The combinations are the approved ones, in their order: name, base, group, equipment, filter, variation, focus, common, muscles and kind of machine")
    func combinationsAreTheApprovedOnes() throws {
        let approved = try Self.approved()
        #expect(library.map(\.name) == approved.combinacoes.map(\.nome))
        let muscleIDs = Dictionary(uniqueKeysWithValues: Muscle.allCases.map { (Self.text($0.displayName), $0) })
        let muscles: (String) -> Muscle? = { id in approved.nomes_dos_musculos[id].flatMap { muscleIDs[$0] } }
        let machines = Dictionary(uniqueKeysWithValues: MachineType.allCases.map { (Self.text($0.displayName), $0) })
        for (entry, line) in zip(library, approved.combinacoes) {
            #expect(entry.base == line.base, "\(entry.name)")
            #expect(Self.text(entry.muscleGroup.displayName) == line.grupo, "\(entry.name)")
            #expect(Self.text(entry.option.displayName) == line.equipamento, "\(entry.name)")
            #expect(Self.text(entry.equipment.displayName) == line.filtro_e_icone, "\(entry.name)")
            #expect(entry.variation == line.segunda_fila, "\(entry.name)")
            #expect(entry.focus == line.foco, "\(entry.name)")
            #expect(entry.isCommon == line.comum, "\(entry.name)")
            let table = try #require(DefaultExerciseMuscles.byKey[entry.key], "\(entry.name)")
            #expect(table.primary == line.musculos.principais.compactMap(muscles), "\(entry.name)")
            #expect(table.primary.count == line.musculos.principais.count, "\(entry.name)")
            #expect(table.secondary == line.musculos.secundarios.compactMap(muscles), "\(entry.name)")
            #expect(table.secondary.count == line.musculos.secundarios.count, "\(entry.name)")
            let machine = line.tipo_de_maquina.flatMap { approved.tipos_de_maquina[$0]?.first }.flatMap { machines[$0] }
            #expect(table.machine == machine, "\(entry.name)")
            #expect((line.tipo_de_maquina == nil) == (machine == nil), "\(entry.name)")
        }
    }

    @Test("Each base has every combination of its equipment and second row, once, and the first one is the one it opens on: an equipment, with the second row's first option when it has one")
    func everyCombinationOnce() throws {
        var byBase: [String: [DefaultExercise]] = [:]
        for entry in library {
            byBase[entry.base, default: []].append(entry)
        }
        #expect(Set(byBase.keys) == Set(bases.map(\.name)))
        for base in bases {
            let combinations = try #require(byBase[base.name])
            let options: [String?] = base.secondRow.map { $0.options.map { Optional($0) } } ?? [nil]
            #expect(combinations.count == base.equipment.count * options.count, "\(base.name)")
            for equipment in base.equipment {
                for option in options {
                    let found = combinations.filter { $0.option == equipment && $0.variation == option }
                    #expect(found.count == 1, "\(base.name): \(equipment) \(String(describing: option))")
                    #expect(found.first?.isCommon == base.common.contains(equipment), "\(base.name): \(equipment)")
                    #expect(found.first?.muscleGroup == base.group, "\(base.name)")
                }
            }
            #expect(combinations.first?.variation == base.secondRow?.opensOn, "\(base.name)")
        }
    }

    @Test("Every base shows the 10 general equipment, the common ones first and then the grey ones, each in the standard order, where Barra W comes right after Barra (in its 6 bases) and Graviton right after Peso do corpo (in its 3)")
    func equipmentOrder() throws {
        let approved = try Self.approved()
        let standard: [LibraryEquipment] = [
            .barbell, .dumbbell, .machine, .isoLateralMachine, .smith, .cable, .band, .kettlebell, .plate, .bodyweight,
        ]
        #expect(standard.map { Self.text($0.displayName) } == approved.equipamentos_padrao)
        let ezBar: Set<String> = ["Rosca Direta", "Rosca Scott", "Rosca Spider", "Rosca Invertida", "Tríceps Francês", "Tríceps Testa"]
        let graviton: Set<String> = ["Barra Fixa", "Peito na Paralela", "Tríceps na Paralela"]
        for base in bases {
            var general = standard
            if ezBar.contains(base.name) {
                general.insert(.ezBar, at: 1)
            }
            if graviton.contains(base.name) {
                general.append(.graviton)
            }
            let commonFirst = general.filter(base.common.contains) + general.filter { !base.common.contains($0) }
            #expect(base.equipment.count == (ezBar.contains(base.name) || graviton.contains(base.name) ? 11 : 10), "\(base.name)")
            #expect(Set(base.equipment) == Set(general), "\(base.name)")
            // Barra W and Graviton are always common where they are.
            #expect(!base.equipment.contains(.ezBar) || base.common.contains(.ezBar), "\(base.name)")
            #expect(!base.equipment.contains(.graviton) || base.common.contains(.graviton), "\(base.name)")
            #expect(base.equipment == commonFirst, "\(base.name)")
            #expect(base.common == base.equipment.filter(base.common.contains), "\(base.name)")
        }
        #expect(Set(bases.filter { $0.equipment.contains(.ezBar) }.map(\.name)) == ezBar)
        #expect(Set(bases.filter { $0.equipment.contains(.graviton) }.map(\.name)) == graviton)
    }

    @Test("PEGADA in Puxada Alta, Barra Fixa, Remada Baixa and Remada; VARIAÇÃO in 24 others")
    func secondRows() {
        let grip = bases.filter { $0.secondRow?.kind == .grip }.map(\.name)
        #expect(Set(grip) == ["Puxada Alta", "Barra Fixa", "Remada Baixa", "Remada"])
        #expect(bases.filter { $0.secondRow?.kind == .variation }.count == 24)
    }

    // MARK: - Keys, ids and names

    @Test("Keys are unique: those of before are English words with hyphens, the new ones the base, the equipment and the variation, with dots")
    func keys() {
        #expect(Set(library.map(\.key)).count == library.count)
        let before = Set(Library420Fixture.entries.map(\.key))
        for entry in library {
            let pattern = before.contains(entry.key) ? #/[a-z0-9]+(?:-[a-z0-9]+)*/# : #/[a-z0-9-]+\.[a-z0-9-]+(?:\.[a-z0-9-]+)?/#
            #expect(entry.key.wholeMatch(of: pattern) != nil, "\(entry.key)")
        }
    }

    @Test("Ids are valid and unique UUIDs, none of them used before by another exercise")
    func ids() {
        let ids = library.compactMap { UUID(uuidString: $0.id) }
        #expect(ids.count == library.count)
        #expect(Set(ids).count == library.count)
        let retired = Set(RetiredExercises.all.compactMap { UUID(uuidString: $0.id) })
        #expect(retired.count == RetiredExercises.all.count)
        #expect(retired.isDisjoint(with: ids))
    }

    @Test("Names are unique ignoring case and diacritics, without spaces around them, with up to 62 characters; only one has more than 60")
    func names() {
        #expect(Set(library.map { Validation.comparisonKey(forName: $0.name) }).count == library.count)
        for entry in library {
            #expect(entry.name.trimmingCharacters(in: .whitespacesAndNewlines) == entry.name, "\(entry.name)")
            #expect(!entry.name.isEmpty && entry.name.count <= DefaultExerciseLibrary.maxNameLength, "\(entry.name)")
            #expect(!entry.focus.isEmpty && entry.focus.trimmingCharacters(in: .whitespaces) == entry.focus, "\(entry.name)")
        }
        #expect(library.filter { $0.name.count > Validation.maxNameLength }.map(\.name) == [
            "Elevação de Pernas Joelhos na Barra Fixa Iso-Lateral (Máquina)",
        ])
    }

    @Test("Each entry is found by its key")
    func byKey() {
        #expect(DefaultExerciseLibrary.byKey.count == library.count)
        for entry in library {
            #expect(DefaultExerciseLibrary.byKey[entry.key] == entry)
        }
    }

    // MARK: - Against the libraries of before

    @Test("Each of the 420 of before has one destination: the same key and id in the library (same name, renamed or the first of a junction), merged into a junction, or retired with its name, group and id")
    func everyExerciseOfBeforeHasADestination() throws {
        let approved = try Self.approved()
        let now = Dictionary(uniqueKeysWithValues: library.map { ($0.key, $0) })
        let retired = Dictionary(uniqueKeysWithValues: RetiredExercises.all.map { ($0.key, $0) })
        let merged = Dictionary(uniqueKeysWithValues: RetiredExercises.junctions.map { ($0.merged, $0.kept) })
        let destination = Dictionary(approved.combinacoes.flatMap { line in (line.na_biblioteca_de_hoje ?? []).map { ($0, line.nome) } }) { first, _ in first }
        for old in Library420Fixture.entries {
            let places = [now[old.key] != nil, retired[old.key] != nil, merged[old.key] != nil].filter { $0 }.count
            #expect(places == 1, "\(old.name)")
            if let entry = now[old.key] {
                #expect(entry.id == old.id, "\(old.name)")
                #expect(destination[old.name] == entry.name, "\(old.name)")
                #expect(entry.name == (approved.renomeados[old.name] ?? old.name), "\(old.name)")
            } else if let gone = retired[old.key] {
                #expect(approved.saem.contains(old.name), "\(old.name)")
                #expect(gone.id == old.id && gone.name == old.name && gone.muscleGroup == old.muscleGroup, "\(old.name)")
                #expect(gone.equipment == old.equipment, "\(old.name)")
            } else if let keptKey = merged[old.key] {
                let kept = try #require(now[keptKey])
                #expect(destination[old.name] == kept.name, "\(old.name)")
            }
        }
    }

    @Test("The 4 junctions: the combination keeps the key and id of the first exercise, the second is merged into it")
    func junctions() throws {
        let approved = try Self.approved()
        let before = Dictionary(uniqueKeysWithValues: Library420Fixture.entries.map { ($0.name, $0) })
        let pairs = try approved.juncoes.map { junction in
            (try #require(before[junction.antigos[0]]).key, try #require(before[junction.antigos[1]]).key)
        }
        #expect(RetiredExercises.junctions.map { [$0.kept, $0.merged] } == pairs.map { [$0.0, $0.1] })
        for (junction, line) in zip(RetiredExercises.junctions, approved.juncoes) {
            #expect(DefaultExerciseLibrary.byKey[junction.kept]?.name == line.nome_novo)
            #expect(DefaultExerciseLibrary.byKey[junction.merged] == nil)
        }
    }

    @Test("The retired exercises keep, for the migration, the muscles and the kind of machine they had, and a kind of machine only with Máquina")
    func retiredExercises() {
        let keys = Set(library.map(\.key))
        for exercise in RetiredExercises.all {
            #expect(!keys.contains(exercise.key), "\(exercise.name)")
            #expect(!exercise.primary.isEmpty, "\(exercise.name)")
            #expect(Set(exercise.primary).isDisjoint(with: exercise.secondary), "\(exercise.name)")
            #expect(exercise.machine == nil || exercise.equipment == .machine, "\(exercise.name)")
        }
        #expect(Set(RetiredExercises.all.map(\.key)).count == 105)
    }

    @Test("The old names the search knows are those of the renamed and merged exercises, by the combination's key")
    func oldNames() throws {
        let approved = try Self.approved()
        var expected: [String: [String]] = [:]
        for (line, entry) in zip(approved.combinacoes, library) {
            let old = (line.na_biblioteca_de_hoje ?? []).filter { $0 != line.nome }
            if !old.isEmpty {
                expected[entry.key] = old
            }
        }
        #expect(RetiredExercises.oldNames == expected)
        #expect(Set(RetiredExercises.oldNames.values.flatMap { $0 }) == Set(approved.renomeados.keys))
    }

    @Test("Against the older libraries (71, 157 and 220), every exercise is in the library with its id, retired or merged")
    func olderLibraries() {
        let now = Dictionary(uniqueKeysWithValues: library.map { ($0.key, $0.id) })
        let retired = Dictionary(uniqueKeysWithValues: RetiredExercises.all.map { ($0.key, $0.id) })
        let merged = Set(RetiredExercises.junctions.map(\.merged))
        let fourHundred = Dictionary(uniqueKeysWithValues: Library420Fixture.entries.map { ($0.key, $0.id) })
        for old in LibraryV1Fixture.entries + Library157Fixture.entries + Library220Fixture.entries {
            #expect(now[old.key] == old.id || retired[old.key] == old.id || (merged.contains(old.key) && fourHundred[old.key] == old.id), "\(old.name)")
        }
    }
}
