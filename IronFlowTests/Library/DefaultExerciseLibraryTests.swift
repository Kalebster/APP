import Foundation
import Testing
@testable import IronFlow

struct DefaultExerciseLibraryTests {
    let library = DefaultExerciseLibrary.all

    /// The names changed since the library of 220, by key.
    static let renamedSince220 = ["high-row-machine": "Remada Alta Articulada (Máquina)"]

    @Test("The library has the 420 approved exercises (220 + 200) with the approved count per muscle group, none in Outro")
    func countsPerGroup() {
        #expect(library.count == 420)
        var counts: [MuscleGroup: Int] = [:]
        for entry in library {
            counts[entry.muscleGroup, default: 0] += 1
        }
        // The first list's count plus the second's, group by group.
        #expect(counts == [
            .chest: 33 + 25, .back: 20 + 18, .upperBack: 10 + 10, .traps: 5 + 4, .lowerBack: 6 + 5,
            .shoulders: 23 + 25, .biceps: 17 + 13, .triceps: 23 + 16, .forearms: 7 + 5, .abs: 17 + 18,
            .quadriceps: 22 + 21, .hamstrings: 11 + 8, .glutes: 12 + 17, .adductors: 2 + 2, .calves: 5 + 7,
            .fullBody: 7 + 6,
        ])
    }

    /// The approved list, parsed: each line with its group, and for a new exercise its equipment and focus.
    private struct ApprovedLine {
        /// `nil` for a new exercise ("NOVO").
        let key: String?
        let name: String
        let group: MuscleGroup
        let equipment: Equipment?
        let focus: String?
    }

    private static func approvedLines() throws -> [ApprovedLine] {
        var lines: [ApprovedLine] = []
        var group: MuscleGroup?
        for line in ApprovedExerciseList.text.split(separator: "\n").map(String.init) {
            if !line.hasPrefix(" ") {
                // "Peito (chest):"
                let key = try #require(line.firstMatch(of: /\((\w+)\):$/)?.1, "Group line: \(line)")
                let parsed: MuscleGroup = try #require(MuscleGroup(rawValue: String(key)), "Group: \(key)")
                group = parsed
                continue
            }
            let lineGroup = try #require(group, "Line before a group: \(line)")
            let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " = ")
            try #require(parts.count == 2, "Line: \(line)")
            let fields = parts[1].components(separatedBy: " · ")
            if parts[0] == "NOVO" {
                try #require(fields.count == 3, "Line: \(line)")
                let equipment = try #require(Equipment(rawValue: fields[1]), "Equipment: \(line)")
                lines.append(ApprovedLine(key: nil, name: fields[0], group: lineGroup, equipment: equipment, focus: fields[2]))
            } else {
                try #require(fields.count <= 2, "Line: \(line)")
                var focus: String?
                if fields.count == 2 {
                    try #require(fields[1].hasPrefix("foco: "), "Line: \(line)")
                    focus = String(fields[1].dropFirst("foco: ".count))
                }
                lines.append(ApprovedLine(key: parts[0], name: fields[0], group: lineGroup, equipment: nil, focus: focus))
            }
        }
        return lines
    }

    @Test("The exercises of the first list are the approved list, in its order: each name, group, equipment and focus")
    func approvedList() throws {
        let approved = try Self.approvedLines()
        let before = Dictionary(uniqueKeysWithValues: Library157Fixture.entries.map { ($0.key, $0) })
        #expect(approved.count == 220)
        #expect(approved.filter { $0.key == nil }.count == 63)
        let firstListKeys = Set(Library220Fixture.entries.map(\.key))
        let firstList = library.filter { firstListKeys.contains($0.key) }
        try #require(firstList.count == approved.count)
        for (entry, line) in zip(firstList, approved) {
            #expect(entry.name == (Self.renamedSince220[entry.key] ?? line.name), "Name of \(entry.key)")
            #expect(entry.muscleGroup == line.group, "Group of \(entry.key)")
            if let key = line.key {
                // An exercise that already existed: key, id and equipment as before; the focus as before
                // unless the line gives one.
                let old = try #require(before[key], "Not in the library of 157: \(key)")
                #expect(entry.key == key)
                #expect(entry.id == old.id)
                #expect(entry.equipment == old.equipment, "Equipment of \(key)")
                #expect(entry.focus == (line.focus ?? old.focus), "Focus of \(key)")
            } else {
                // A new exercise: a key of its own, with the listed equipment and focus.
                #expect(before[entry.key] == nil, "New exercise with an existing key: \(entry.key)")
                #expect(entry.equipment == line.equipment, "Equipment of \(entry.key)")
                #expect(entry.focus == line.focus, "Focus of \(entry.key)")
            }
        }
    }

    /// The second approved list, parsed: each line with its group, name, equipment and focus.
    private static func secondListLines() throws -> [ApprovedLine] {
        var lines: [ApprovedLine] = []
        var group: MuscleGroup?
        for line in ApprovedExerciseList2.text.split(separator: "\n").map(String.init) {
            if !line.hasPrefix(" ") {
                let key = try #require(line.firstMatch(of: /\((\w+)\):$/)?.1, "Group line: \(line)")
                group = try #require(MuscleGroup(rawValue: String(key)), "Group: \(key)")
                continue
            }
            let lineGroup = try #require(group, "Line before a group: \(line)")
            let fields = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " · ")
            try #require(fields.count == 3, "Line: \(line)")
            let equipment = try #require(Equipment(rawValue: fields[1]), "Equipment: \(line)")
            lines.append(ApprovedLine(key: nil, name: fields[0], group: lineGroup, equipment: equipment, focus: fields[2]))
        }
        return lines
    }

    @Test("The 200 exercises of the second list are new, with the listed name, group, equipment and focus, in its order, each after the others of its group")
    func secondApprovedList() throws {
        let approved = try Self.secondListLines()
        #expect(approved.count == 200)
        let firstListKeys = Set(Library220Fixture.entries.map(\.key))
        let added = library.filter { !firstListKeys.contains($0.key) }
        try #require(added.count == approved.count)
        for (entry, line) in zip(added, approved) {
            #expect(entry.name == line.name, "Name of \(entry.key)")
            #expect(entry.muscleGroup == line.group, "Group of \(entry.key)")
            #expect(entry.equipment == line.equipment, "Equipment of \(entry.key)")
            #expect(entry.focus == line.focus, "Focus of \(entry.key)")
        }

        // The groups keep the order of the library of 220, and each group lists its exercises of the first
        // list first, as they were, then its new ones in the order of the second list.
        var groupOrder: [MuscleGroup] = []
        for entry in Library220Fixture.entries where groupOrder.last != entry.muscleGroup {
            groupOrder.append(entry.muscleGroup)
        }
        #expect(Set(groupOrder).count == groupOrder.count)
        let expectedKeys = groupOrder.flatMap { group in
            Library220Fixture.entries.filter { $0.muscleGroup == group }.map(\.key)
                + added.filter { $0.muscleGroup == group }.map(\.key)
        }
        #expect(library.map(\.key) == expectedKeys)
    }

    @Test("Against the library of 220, every exercise stays with its key, id, group, equipment and focus; only high-row-machine changes its name")
    func changesFromTheLibraryOf220() throws {
        #expect(Library220Fixture.entries.count == 220)
        var renamed: [String: String] = [:]
        for old in Library220Fixture.entries {
            let entry = try #require(DefaultExerciseLibrary.byKey[old.key], "Missing: \(old.key)")
            #expect(entry.id == old.id)
            #expect(entry.muscleGroup == old.muscleGroup, "Group of \(old.key)")
            #expect(entry.equipment == old.equipment, "Equipment of \(old.key)")
            #expect(entry.focus == old.focus, "Focus of \(old.key)")
            if entry.name != old.name { renamed[old.key] = entry.name }
        }
        #expect(renamed == Self.renamedSince220)
        #expect(Library220Fixture.entries.first { $0.key == "high-row-machine" }?.name == "Remada Alta (Máquina)")
    }

    @Test("Against the library of 157, every exercise stays with its key, id and equipment; 144 names, 13 groups and 4 focuses change")
    func changesFromTheLibraryOf157() throws {
        #expect(Library157Fixture.entries.count == 157)
        var renamed = 0
        var regrouped: Set<String> = []
        var refocused: Set<String> = []
        for old in Library157Fixture.entries {
            let entry = try #require(DefaultExerciseLibrary.byKey[old.key], "Missing: \(old.key)")
            #expect(entry.id == old.id)
            #expect(entry.equipment == old.equipment)
            if entry.name != old.name { renamed += 1 }
            if entry.muscleGroup != old.muscleGroup { regrouped.insert(old.key) }
            if entry.focus != old.focus { refocused.insert(old.key) }
        }
        #expect(renamed == 144)
        #expect(regrouped == [
            "pullover-dumbbell", "bent-over-row-barbell", "bent-over-row-smith", "t-bar-row", "row-lever-machine",
            "wide-grip-seated-cable-row", "row-machine", "seal-row", "shrug-barbell", "shrug-dumbbell",
            "back-extension", "deadlift", "hip-adduction-machine",
        ])
        #expect(refocused == ["seated-cable-row", "pullover-dumbbell", "wide-grip-seated-cable-row", "row-machine"])
    }

    @Test("Keys are unique, English lowercase words separated by hyphens")
    func keys() {
        let keys = library.map(\.key)
        #expect(Set(keys).count == keys.count)
        for key in keys {
            #expect(key.wholeMatch(of: /[a-z0-9]+(-[a-z0-9]+)*/) != nil, "Invalid key: \(key)")
        }
    }

    @Test("Ids are valid and unique UUIDs")
    func ids() {
        let ids = library.compactMap { UUID(uuidString: $0.id) }
        #expect(ids.count == library.count)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Names pass the name rules and are unique ignoring case and diacritics")
    func names() throws {
        for entry in library {
            #expect(try Validation.name(entry.name) == entry.name, "Invalid name: \(entry.name)")
        }
        let comparisonKeys = library.map { Validation.comparisonKey(forName: $0.name) }
        #expect(Set(comparisonKeys).count == comparisonKeys.count)
        // The longest name, which the interface tests show whole, has 54 of the 60 characters allowed.
        let longest = try #require(library.max { $0.name.count < $1.name.count })
        #expect(longest.name == "Extensão de Tríceps Acima da Cabeça Unilateral (Polia)")
        #expect(longest.name.count == 54)
    }

    @Test("Every exercise has its equipment and a focus without spaces around it")
    func equipmentAndFocus() {
        for entry in library {
            #expect(!entry.focus.isEmpty, "No focus: \(entry.key)")
            #expect(entry.focus == entry.focus.trimmingCharacters(in: .whitespacesAndNewlines), "Focus with spaces: \(entry.key)")
        }
        // Every kind of equipment is used by at least one exercise, so every filter has exercises.
        let used = Set(library.map(\.equipment))
        #expect(used == Set(Equipment.allCases))
    }

    @Test("Each entry is found by its key")
    func byKey() {
        #expect(DefaultExerciseLibrary.byKey.count == library.count)
        for entry in library {
            #expect(DefaultExerciseLibrary.byKey[entry.key] == entry)
        }
    }

    @Test("Approved classifications: each exercise in the group of the muscle it works the most")
    func classifications() {
        func group(_ key: String) -> MuscleGroup? { library.first { $0.key == key }?.muscleGroup }
        #expect(group("pull-up") == .back)
        #expect(group("pullover-dumbbell") == .back)
        #expect(group("bent-over-row-barbell") == .upperBack)
        #expect(group("shrug-dumbbell") == .traps)
        #expect(group("deadlift") == .lowerBack)
        #expect(group("hip-adduction-machine") == .adductors)
        #expect(group("dips") == .triceps)
        #expect(group("hammer-curl-dumbbell") == .biceps)
        #expect(group("power-clean") == .fullBody)
        #expect(group("thruster-barbell") == .fullBody)
        #expect(library.first { $0.key == "bench-press-barbell" }?.name == "Supino Reto (Barra)")
        #expect(library.first { $0.key == "pull-up" }?.name == "Barra Fixa (Pegada Aberta)")
    }

    @Test("Against the first library, its 71 exercises keep their ids; 67 names and 5 groups changed since then")
    func correctionsOfTheFirstLibrary() throws {
        var renamed: [String] = []
        var regrouped: [String] = []
        for old in LibraryV1Fixture.entries {
            let entry = try #require(DefaultExerciseLibrary.byKey[old.key], "Missing: \(old.key)")
            #expect(entry.id == old.id)
            if entry.name != old.name { renamed.append(old.key) }
            if entry.muscleGroup != old.muscleGroup { regrouped.append(old.key) }
        }
        #expect(LibraryV1Fixture.entries.count == 71)
        #expect(renamed.count == 67)
        #expect(Set(regrouped) == ["bent-over-row-barbell", "row-machine", "shrug-dumbbell", "deadlift", "hip-adduction-machine"])
    }

    /// Keys and ids are permanent. This list may only grow: changing or removing a pair
    /// would break existing stores and future sync.
    @Test("Every key keeps its fixed id")
    func frozenKeyToID() {
        let actual = Dictionary(uniqueKeysWithValues: library.map { ($0.key, $0.id) })
        #expect(actual == Self.frozenIDs)
    }

    static let frozenIDs: [String: String] = [
        "bench-press-barbell": "2A8DF1B0-3059-46E9-8A28-0249DFFF35A3",
        "bench-press-dumbbell": "8BE65287-7F57-42CE-9FC1-25932355AE5A",
        "incline-bench-press-barbell": "EFE20D78-2A00-4EFB-BED3-024357710F23",
        "incline-bench-press-dumbbell": "F207C734-07C0-41E5-8310-AA1611CFB38C",
        "decline-bench-press-barbell": "5F72F996-41A5-4D32-AEB2-2154411A4566",
        "chest-press-machine": "916E8492-AC56-49B2-8459-A029513409C3",
        "fly-dumbbell": "EF31C314-C1EB-48CD-9FF8-D3E0A2A16B69",
        "fly-machine": "432E6DC6-193A-4B02-8CBA-0AD196069BB7",
        "cable-crossover": "EE3EBFB6-1880-439A-83FD-CE25C4026E91",
        "pull-up": "B4C39763-E2C4-4115-86D8-46FDEB6897CD",
        "lat-pulldown": "EF0C3EAD-71E2-427F-8DE1-CB1CAF6B6043",
        "bent-over-row-barbell": "C4052FD4-1A83-4B58-A863-1C27F9E68B03",
        "one-arm-row-dumbbell": "6DA533D8-9699-49C1-8BC9-CA31E0DC926E",
        "seated-cable-row": "96192D2A-5DD7-4CF0-9A09-7C7476B4BC0E",
        "row-machine": "F7C34293-0230-4D7E-93F8-A66EDAA878EB",
        "straight-arm-pulldown": "4EC1E018-0130-4B5E-A989-DF527139405B",
        "overhead-press-barbell": "EBDDA760-71D6-4F7B-A96C-608A69A865D0",
        "shoulder-press-dumbbell": "B245B003-04B8-45CC-AE95-1C32B437A8DC",
        "shoulder-press-machine": "76C03A25-36D5-4066-99BA-0854E91AED82",
        "lateral-raise-dumbbell": "EE3F5702-F5F8-473C-BA24-DD46766A8B87",
        "lateral-raise-cable": "F8A98D05-8F42-41B1-85C5-08F15D814940",
        "front-raise-dumbbell": "3A1666E9-FAB2-4DE7-BD12-0C0DF6D92697",
        "reverse-fly-dumbbell": "0D0F986B-182E-414E-B879-7E2DF51C1071",
        "face-pull": "10B33D70-0CC9-45B9-B2FA-B448603D6F77",
        "shrug-dumbbell": "1B22DE68-44A1-4DD4-B93D-4E0AE489E439",
        "curl-barbell": "5DE24313-22D9-4860-A20E-BC4593835349",
        "alternating-curl-dumbbell": "165B5981-72A7-4405-B4C5-62E9BEEE0A54",
        "hammer-curl-dumbbell": "CB64654F-E743-425D-9CF0-564BBCD3F300",
        "preacher-curl": "8C7A9E79-6136-4E37-9DB8-E3E51BF794BA",
        "curl-cable": "61D5ACA4-FD2B-4F00-BC53-AA2170579306",
        "concentration-curl": "D1A7BD27-C7FC-46A3-95C9-310050E31A6B",
        "triceps-pushdown-bar": "129B6EDC-93B4-4969-AF26-8D014C4F23B5",
        "triceps-pushdown-rope": "EA9F719C-A66E-4F78-9609-C4E5FE07E47C",
        "skull-crusher-barbell": "B3BF4DA4-9FA0-4675-8FC8-ABC089E49DBC",
        "overhead-extension-dumbbell": "CD72E327-6CDA-4091-B035-8B52C888B229",
        "close-grip-bench-press": "B49164A1-A952-4A3D-9F75-FBAB2E78375B",
        "dips": "1CFDD592-1E38-4415-86D8-12553A8465FE",
        "kickback-dumbbell": "8244BCB7-6383-4770-8AE4-E1279D81E50F",
        "wrist-curl-barbell": "0481D3C9-EAEB-4264-88CA-685EC556BE60",
        "reverse-wrist-curl-barbell": "8470E422-59F5-4AC9-B0F3-8B09BA00C334",
        "reverse-curl-barbell": "B60B986C-37C2-49F0-9047-8F6C93AD6348",
        "back-squat": "C517F588-CCE9-43C9-A1E9-2DBCFCAF2EB4",
        "front-squat": "7C1C3F6C-94B2-48ED-A61D-98186E652811",
        "goblet-squat": "4BE239F6-9A5D-4ED0-97B3-1D3C32325917",
        "hack-squat": "BB7E8880-925B-4C74-973E-70184E481B73",
        "leg-press": "CE7E1B81-9AB5-4526-8CCD-3BAE65186FA5",
        "leg-extension": "C63B1D0E-9341-4FD1-B6F5-6B7BD8A6666E",
        "lunge-dumbbell": "40D00DD6-61B9-4799-9499-F70F299E2BBB",
        "bulgarian-split-squat": "2045FEDA-CA84-4BDD-ACAD-D6C73AC04A51",
        "deadlift": "CC2B68C8-727F-49C9-AFDC-8B338BE8C692",
        "romanian-deadlift-barbell": "070BF992-4700-4C2A-B6B6-DB2E3AA3740E",
        "romanian-deadlift-dumbbell": "FDFB0C36-22A4-476A-A92D-2178DDAD7716",
        "lying-leg-curl": "BA642AA8-6477-47CB-BAD2-EE698617D7CC",
        "seated-leg-curl": "6A33CF0A-0FA8-4000-B2E5-760F30BC5813",
        "good-morning": "A0FEF74E-FA04-419F-A24C-8373963B385B",
        "hip-thrust-barbell": "BAA2E068-F397-42D3-B12B-21A9B3527ABC",
        "glute-bridge": "3F432DB8-1C9B-4CB2-BCD9-2CDC72A6567A",
        "hip-abduction-machine": "BE53D4D5-A142-4959-9770-CF7195BD098E",
        "cable-kickback": "01888996-9C1A-4661-B8FF-611A30F3A6D2",
        "standing-calf-raise": "7186818E-02B6-4AA3-88CD-5E3A9D4B243F",
        "seated-calf-raise": "E8275D6E-BD2F-4D84-9B61-818997F78B5F",
        "leg-press-calf-raise": "23FD5256-DCB6-418D-8429-91F2E47CCF05",
        "crunch": "A281DFB5-CBE2-4467-B060-483E68E55F64",
        "cable-crunch": "557BF24B-D9F8-4DFE-B03C-23B713BE6F92",
        "hanging-leg-raise": "9E16015B-C0AB-4D4A-987D-017E7F6C4626",
        "lying-leg-raise": "F1BF928F-6C2E-44F5-AEE0-F37C000E1211",
        "russian-twist": "D82081B2-5DCC-4F63-AE83-F5BA93D70A9C",
        "ab-wheel-rollout": "2E2A3077-0EA9-4359-AC59-9EFD034500AD",
        "kettlebell-swing": "5768F1BF-317F-4944-92EB-08C9E84BF197",
        "burpee": "E424EF0A-10C4-4C7C-97B4-944763A4884E",
        "hip-adduction-machine": "D70D3781-594F-4DD0-A391-A6491B960B06",
        // Added with the library of 157 (S4-B).
        "bench-press-smith": "4FDC80AD-759B-469B-9107-6D496BB31AF0",
        "incline-chest-press-machine": "A31F129E-B3D3-4540-96D9-BC0E463C01C3",
        "incline-bench-press-smith": "F003A695-A21E-4C35-A0B1-E672FA2F474D",
        "decline-bench-press-dumbbell": "57CF4F47-8D59-4D7C-9993-A99768C40F2A",
        "chest-press-lever": "8D00B5A8-6463-409E-9995-81A2734A88E4",
        "incline-fly-dumbbell": "D714DEA6-1CFB-4A0E-A62C-5014005E60AA",
        "cable-crossover-mid": "256DF723-7783-41B1-A8D8-18F1551FA20C",
        "cable-crossover-low": "BF0FC340-7B1B-42F2-AC72-801F3D257584",
        "push-up": "1E3B1E6B-B655-42CC-946E-6DE1DD17C934",
        "decline-push-up": "7F7C8AB2-57D8-497E-963D-2EEFFA5922BE",
        "chest-dips": "13BD9806-A427-4B3C-82AB-C417AA95A806",
        "pullover-dumbbell": "343A595A-3830-4FA3-83BA-C7B7F7C5F8CA",
        "chin-up": "226CC388-4C45-4948-9A2B-A8BFA9D5B616",
        "assisted-pull-up": "F63EB411-7950-450A-A723-AFA3955583D3",
        "close-grip-lat-pulldown": "B9CA24BD-12BE-477A-8004-7A366D6A6BD4",
        "reverse-grip-lat-pulldown": "6910FFBA-DBFF-4A09-872B-C74A183058AB",
        "single-arm-lat-pulldown": "C160A719-3F0E-4996-8075-E4B20F9C9F0E",
        "reverse-grip-bent-over-row": "B813F95A-5E05-44E8-A1B4-5725C56F662A",
        "t-bar-row": "1014C215-8E06-44CE-AA3B-8DC7CA8682F1",
        "wide-grip-seated-cable-row": "237903F3-4280-4E88-9673-33F54C3DAC2B",
        "row-lever-machine": "445F1828-40F5-4C66-900C-050E47840613",
        "seal-row": "A6A4E293-7C3E-48B8-B042-675D3C12CD31",
        "bent-over-row-smith": "31C75782-4934-46F0-BD80-087C7EF98244",
        "back-extension": "D22B881D-624B-439F-9AE1-22EADD865A0D",
        "shrug-barbell": "AF64B90F-C342-4466-A672-6236E54316A7",
        "shoulder-press-smith": "D29F18D0-5913-455B-8BF2-6553739BF46D",
        "arnold-press": "75353C0D-F873-419C-98CA-C8BA0BD89B84",
        "lateral-raise-machine": "BE170859-477E-47B4-BBCF-C4494B125C2F",
        "front-raise-plate": "634B168B-669C-4740-9C17-430F6B56F141",
        "front-raise-cable": "E3E7E54D-0012-41E3-9556-2BAA053F9EA1",
        "reverse-fly-machine": "904E53C4-F290-416D-A21E-65A9528D1091",
        "reverse-fly-cable": "18F19B1A-700D-411E-996E-428E336FD5DD",
        "upright-row-barbell": "03438B07-81AD-4AD1-88AC-56349368A173",
        "upright-row-cable": "8A98AE31-F2A6-4A12-BDC9-919347C016A8",
        "external-rotation-cable": "E4274798-D911-4BCF-BABD-33FC00F37304",
        "curl-ez-bar": "79084BA0-A64E-4C03-B6F2-77E5A43A076B",
        "curl-dumbbell": "AC7033DF-B837-4881-B1D7-6E8BAB84D129",
        "hammer-curl-rope": "90E8F1A7-00CA-4054-A4CB-C9B72CBD95B2",
        "preacher-curl-machine": "74CCF9C2-8B8D-477A-9DE2-F9ADE4FE0D4A",
        "preacher-curl-dumbbell": "6FA7E0CF-73B6-4C33-8644-7AB6E8CAF88A",
        "incline-curl-dumbbell": "613574DD-43BB-4CAB-A56C-938BB9A22382",
        "bayesian-curl-cable": "705997F2-9C59-40BE-B348-FB6A6C2A29CE",
        "spider-curl-ez-bar": "07956F8F-C361-4F10-84E2-7DDADAFE8B23",
        "single-arm-reverse-grip-pushdown": "0EFDC351-6501-41D3-BCC3-8438D6B2CC61",
        "overhead-extension-rope": "E8412A75-8C36-44F6-8E4F-C6B2DD969DEB",
        "skull-crusher-dumbbell": "FB59F4CD-A2B7-497A-A397-C03BA7E3F46D",
        "kickback-cable": "545C9509-08EF-456A-B7DF-D18C2676ECD5",
        "triceps-extension-machine": "F67686F3-EAD6-40EE-93C3-28000E1B8AE9",
        "bench-dips": "0F6C0D6E-0503-4BE7-AC99-20980E90FE79",
        "diamond-push-up": "1825336D-B071-47C5-83C1-AB4563135044",
        "wrist-curl-dumbbell": "5ED1B531-CB67-489C-910F-37D78085FB31",
        "squat-smith": "7D3DD7C9-576C-4707-955A-C6A39E3CD371",
        "bodyweight-squat": "75F5466E-D1C9-47CE-8A9B-E229C5C82BB4",
        "leg-press-horizontal": "7F69E303-32A6-4143-8039-CDF8BF6FF5D2",
        "lunge-smith": "D1B06BA4-E46E-4115-A94C-A0FA56D6CFBE",
        "walking-lunge-dumbbell": "70B05664-01F6-4ABB-894A-40B97DA68216",
        "walking-lunge-barbell": "2ECDE858-BBD3-40D1-BC84-49B6418805EB",
        "step-up-dumbbell": "9B8D4982-AD47-4B50-BBAB-57A67F6FEF44",
        "sissy-squat": "0B8ED39E-E9C9-412D-9617-799F06A6DA6B",
        "standing-leg-curl": "3BBE4B67-9413-461C-B92A-2E66F64557B6",
        "romanian-deadlift-smith": "03AD39F2-834B-462B-B4BA-A21F43A6BDBC",
        "rdl-barbell": "66A91C2E-EE56-422C-8018-1B594F0B0670",
        "nordic-curl": "B90F4F41-9ACB-4056-B550-E6F00969FC17",
        "hip-thrust-machine": "6325A715-0BCB-4F51-93E9-D55684B56EB2",
        "hip-thrust-smith": "F8C7BC93-4C73-4834-B963-E595024A5A2B",
        "glute-kickback-machine": "7B3595F6-AE1C-421F-9D1C-92C77555EBCB",
        "hip-abduction-cable": "157631E3-0E6D-4374-A672-472133A847BA",
        "hip-abduction-band": "7FAB266A-4F9F-473C-8348-B061032A4E7B",
        "lateral-band-walk": "259F1AD8-9863-4C12-AF74-FD217AAABB9A",
        "sumo-squat-dumbbell": "4EE5DACD-EC24-41CA-A98C-AD2E064FB437",
        "sumo-deadlift": "E8D7AA94-B91B-4232-9334-7DF6BCE89F6E",
        "calf-raise-smith": "5328D6F5-7D10-410C-8D23-D9955E5C652F",
        "single-leg-calf-raise-dumbbell": "0ADB917E-FE38-4460-8905-78A08B37AF41",
        "weighted-crunch-plate": "9B6A83BD-199F-46C5-9E0C-F9384D1FCB27",
        "crunch-machine": "E5B1AE85-EFA8-4B27-879A-E9C22B867ADE",
        "reverse-crunch": "A4181692-FC6C-4276-BC3D-C538ED8C330D",
        "captains-chair-knee-raise": "0C39A349-EADF-408F-8AEE-44E6849179DB",
        "oblique-crunch": "79B0FFFD-A439-40CC-BCBE-8C548415D6FB",
        "bicycle-crunch": "AF0DF957-B16D-47C1-820B-F92E8BE7AFC7",
        "cable-woodchop": "D185F7C8-060E-4C6D-A08A-6B0E6873DB5C",
        "dead-bug": "FCC96AF0-F1D0-46A0-AA66-D28CAC9E6251",
        "kettlebell-snatch": "ABCAC9B5-A370-4F48-9746-37DAB193BA56",
        "turkish-get-up": "C12663FE-8D07-4244-AE4B-7D76221D3C88",
        "thruster-barbell": "D3582270-5FAE-4B7D-99A3-F1DA1BE00431",
        "thruster-dumbbell": "94F098B9-9AF6-4DCA-A9D1-0A96B5B5C1F5",
        "power-clean": "372E8075-4DF9-4DC2-9EE2-4E50CFF9EA1A",
        // Added with the library of 220 (lista de exercícios).
        "bench-press-cable": "A14779F1-530A-4C91-9EED-FD747EC88C85",
        "incline-bench-press-cable": "139A7832-60F5-4D7C-9009-311F92BE01E2",
        "decline-chest-press-machine": "C320DD5B-A263-4D26-8A88-2D1557BB46B1",
        "decline-bench-press-smith": "75F2205B-0DE6-4384-BC01-9CD9918674D7",
        "decline-bench-press-cable": "D1AABBEB-1EEF-40A9-9A2E-5C444FCB21E8",
        "seated-chest-press-machine": "DFAF5159-F81D-4C31-B766-DBDD1DD45F91",
        "seated-chest-press-cable": "26A9D91B-3600-41CE-B1F3-79F34199E07D",
        "fly-cable": "3396FD56-4170-44B4-A65D-E885B036292F",
        "incline-fly-machine": "BC5BC023-E74A-4F72-8DFF-60E8A53371E2",
        "incline-fly-cable": "A8FEFECE-4E10-40D6-9964-8E072A142957",
        "single-arm-cable-crossover": "59C29ADB-6DFB-436C-8155-E516DF366841",
        "incline-push-up": "3E49E429-B361-433A-BBBC-50DD1306305E",
        "knee-push-up": "5873429C-978A-45E8-A529-2F6B64C746B9",
        "close-grip-pull-up": "28F1B731-96E6-4877-8E2B-F45B56AE386E",
        "lat-pulldown-machine": "AD589024-E54E-447F-A92F-B555CD8DFD3D",
        "single-arm-lat-pulldown-machine": "CAF97DF2-C7CB-4DDC-9ED4-821006EA3559",
        "single-arm-row-cable": "24488176-1FE8-4030-8D4A-AF4F9C37C673",
        "single-arm-row-machine": "992C150B-3DF9-4B5D-8F40-E80836A7127A",
        "high-row-machine": "6790D887-711C-4CA6-B5AD-86C60C439940",
        "pullover-barbell": "7F8D6F93-5C43-4622-82D0-BC499D9A8F53",
        "pullover-machine": "A5E6EA3B-0329-4CC8-A28D-2E0F7651432A",
        "bent-over-row-dumbbell": "015C9D09-72E3-4D4F-9AC3-D61ED3DFE569",
        "t-bar-row-machine": "61049916-7CE1-4CDF-86B3-17ADA76E2255",
        "v-grip-row-machine": "CFA196F2-588C-4DDD-A56A-C553E1E24ECE",
        "shrug-smith": "50590B97-3AA4-4B88-8825-49C2C9BDA4B6",
        "shrug-machine": "20D4403C-6C92-427D-A6AB-986BC77C9179",
        "shrug-cable": "A3C747BD-8736-412A-A716-702604858160",
        "back-extension-plate": "A27B4AFA-87E5-4C42-A0E0-2E3C13FD1725",
        "back-extension-machine": "64C30AF4-D275-47F3-B5C6-C0C0F83C4811",
        "superman": "49CE5F30-05F6-4046-B224-6C9A4E67B0CD",
        "deadlift-dumbbell": "B961FC90-D332-4077-9AC0-7CFF63D97C53",
        "single-arm-lateral-raise-dumbbell": "0A7A2EC9-C85B-4278-A6C6-83CE08FAEE4C",
        "single-arm-lateral-raise-cable": "1895F788-5A94-4153-B17C-83CDCADFFFA6",
        "front-raise-barbell": "F56C9460-E524-472C-B6F7-695D9A201753",
        "single-arm-reverse-fly-cable": "1766A0C1-60BF-46D0-AB1B-84CA4D4B8230",
        "upright-row-dumbbell": "770DA728-6956-4E8A-BDCB-9E66D645A6B0",
        "single-arm-curl-cable": "4C3B63B3-455B-4129-AC31-BB3714AD87E6",
        "preacher-curl-cable": "DC34389A-6210-43FE-A403-3E6A9D79396D",
        "spider-curl-dumbbell": "080B9377-7A85-478C-9ABD-83831CFE03CA",
        "single-arm-triceps-pushdown": "7A1B220C-5CC8-48CE-A04D-7AC95DA90826",
        "overhead-extension-ez-bar": "D05AC5FE-92AF-4967-BC4C-BA6555B03945",
        "single-arm-overhead-extension-dumbbell": "0E9FD0FE-5C9D-4122-981D-6D868B997CE0",
        "skull-crusher-cable": "1C296FCF-E863-460A-9988-853473C2D813",
        "skull-crusher-smith": "38A960C6-5A73-4276-B8F9-A205201DD068",
        "jm-press-barbell": "1E2466F8-B5E9-4263-B55A-7656392C229D",
        "jm-press-smith": "FB8883F5-4167-45EA-B82D-3A5460B0845B",
        "close-grip-bench-press-smith": "EEBBA5E2-8F5E-4F44-A03B-F48D6F5B73D1",
        "seated-dip-machine": "49E05F8F-300F-4E7C-AC51-333836C9ABBD",
        "reverse-wrist-curl-dumbbell": "C5F2A423-5862-4484-BA78-A86F12B98E71",
        "reverse-curl-dumbbell": "EEE5EB96-6125-4896-9A61-56F84AE8C432",
        "reverse-curl-cable": "7B240C7E-6DA9-45D0-A6AD-0BEFCEA9A576",
        "decline-crunch": "448C4290-B9B6-4F14-AB34-F11022EC9452",
        "scissor-kick": "0E1ED61D-280E-4AB5-A6A2-C5836607DB52",
        "dragon-flag": "AFD2254B-F118-410F-81E9-CC52C30623F5",
        "pendulum-squat": "B2D2E4C7-4B4A-4CCF-8E43-83B2BF911D9D",
        "goblet-squat-dumbbell": "F5BF0562-FF37-4359-BBD3-AA19B6912F86",
        "bulgarian-split-squat-smith": "825104FE-299A-42E7-AE09-712FB01DC895",
        "single-leg-press": "BC25AD7A-BA53-41D9-823C-3E93F9613448",
        "single-leg-extension": "A5D56C6E-66DA-4DA8-A091-EE1C88092436",
        "lunge-barbell": "55B29EF1-74F2-4C8C-A036-25C35BB2F3B4",
        "single-leg-romanian-deadlift-dumbbell": "88E4BC9E-8248-48A3-9753-2BC5B9BD3E10",
        "good-morning-smith": "260397E6-BC71-4C8D-9959-46AF7863C31A",
        "hip-adduction-cable": "6C990FD1-E4AC-49EB-8ABC-C6FDA130AC20",
        "single-arm-bench-press-dumbbell": "37972895-1F79-4E2D-B408-17BD39B782D2",
        "neutral-grip-bench-press-dumbbell": "51F31EB6-9804-4CD8-BB47-E419CEBA8988",
        "wide-grip-bench-press-barbell": "93BF9A4C-D4B1-444C-88F4-CC2E367C43A2",
        "single-arm-chest-press-machine": "57CFDC55-F452-4164-838C-A239DD242468",
        "single-arm-bench-press-cable": "3720757B-F8EF-4191-9AB1-A893128861FC",
        "single-arm-incline-bench-press-dumbbell": "5132CC95-543E-42AD-9D4F-1487F01218C5",
        "neutral-grip-incline-bench-press-dumbbell": "5D9899F9-DC43-4513-9C8F-6D2D3AC2F3D2",
        "incline-chest-press-lever": "4A3E7D03-FC26-4B51-B752-57D683D7E5E2",
        "single-arm-incline-chest-press-machine": "1453A24D-8C25-46F5-A59B-047091E0D426",
        "single-arm-incline-bench-press-cable": "53FE34F8-AB73-4E29-B632-539035CA506C",
        "decline-chest-press-lever": "EAA4DC9B-EA4E-47D4-A9BF-9E0E9A677B49",
        "squeeze-press-dumbbell": "149BACA9-4D85-48A5-9F3E-D9A092AE91C1",
        "guillotine-press-barbell": "C4AC98AD-0733-4E62-92D4-AB3E70634E05",
        "floor-press-barbell": "D5CC21C9-E89D-4EE5-88B0-FFBF39DE7046",
        "floor-press-dumbbell": "F67A1090-8E67-4F1C-B0E5-B4E1EAC18008",
        "landmine-chest-press": "896B0866-605B-4B73-966C-758527F8FACF",
        "decline-fly-dumbbell": "8D79EF76-2A10-4A45-8273-5D251459D02E",
        "fly-band": "83B70343-0840-4F39-BE0B-58A2699AD118",
        "svend-press": "8E5B0429-5056-40F6-8D89-452DDEB220F9",
        "assisted-chest-dips": "5A1059F1-9BD4-4016-AE88-049B69A83489",
        "wide-push-up": "9A5F728D-0ED4-439F-9D92-4814B21AF25B",
        "weighted-push-up-plate": "AA6CC8B2-D59E-403E-89A7-2E14660B0BDD",
        "band-push-up": "8F9D2552-2E53-447F-B0FF-4C0073027EB2",
        "archer-push-up": "E134E58A-96DA-443C-A6B1-619B2C70FFD0",
        "plyometric-push-up": "72C496DF-1E4F-483E-9230-CFB24BA20CB8",
        "neutral-grip-pull-up": "A4DB71B0-2375-41EB-B7F0-312CA0930792",
        "weighted-pull-up": "EA086BE6-ABB0-4C76-BE0D-A6920117EF47",
        "weighted-chin-up": "5DB9913E-F37C-4D94-B353-963D27525188",
        "band-assisted-pull-up": "A461D98B-58DE-4CD2-8130-77FADF126C72",
        "assisted-chin-up": "2C0A9E23-2038-440E-9ECE-963EC45915C1",
        "neutral-grip-lat-pulldown": "17A8F3DD-264A-4D21-99B3-D07FD2F824A0",
        "behind-the-neck-lat-pulldown": "28E9476D-39AE-4B15-B126-AACF71B9A846",
        "reverse-grip-lat-pulldown-machine": "CB71DCBE-33C8-4C3A-8817-14F762492F6B",
        "close-grip-lat-pulldown-machine": "9A79FD4D-7E44-46F6-9076-EF2D3D7B42F6",
        "lat-pulldown-band": "D192B650-0C7D-4525-80D4-AC8BBDD52404",
        "rope-pullover-cable": "139D530C-AFCE-4D4C-B4F0-60C11437306D",
        "single-arm-pullover-cable": "C1281954-00A3-4031-BBAC-663510BB5C4D",
        "kroc-row": "57CDE3AC-3F16-4054-A2FA-1A51232D29AE",
        "meadows-row": "5570942F-4458-4F66-8135-7881442BB7DF",
        "single-arm-high-row-machine": "DE32238A-3687-408A-B6C5-938767B1B62C",
        "reverse-grip-seated-cable-row": "D7B55485-851C-41C0-8C37-D20230E90EB6",
        "reverse-grip-bent-over-row-dumbbell": "96D20437-22BF-456D-8423-67BB7E774BD0",
        "reverse-grip-bent-over-row-smith": "285E02C8-9E42-4557-A640-85A728BAD880",
        "pendlay-row": "267DEEBF-4E22-4E62-A4D6-1A4763046127",
        "inverted-row": "87DCC79B-6A5C-4D4F-900F-3A10011006A2",
        "seal-row-barbell": "5F097598-C4A7-4A1C-A523-CCD7B3724059",
        "chest-supported-row-machine": "5CC53827-418E-48B2-8248-DBA45FB5647D",
        "single-arm-row-smith": "442BB5A9-81F4-4724-A87A-05A39109C6AB",
        "bent-over-row-band": "FE22BFC8-DC9A-4ECE-8768-EAE9FE156AF6",
        "seated-row-band": "9AF8DE43-CC76-4F23-941D-7660C8BF1A27",
        "gorilla-row": "9882958F-199B-4A7B-802A-53A9511AED9E",
        "renegade-row": "5C029D5A-E7BE-4FD6-8530-ACB4F0846555",
        "scapular-pull-up": "9408ED0C-A25C-4FA4-9C3B-1682467C57C4",
        "behind-the-back-shrug": "4AA4E858-9101-48E6-ACEC-855958B7EA97",
        "incline-shrug-dumbbell": "B34B36C5-4E70-443F-BFC1-15A416ECD6F1",
        "y-raise-dumbbell": "5E762F55-019E-407E-8F8D-EF4862985D79",
        "y-raise-cable": "D929C0D1-1EA4-4767-A2E3-0C2078F25869",
        "trap-bar-deadlift": "FE7C4B4E-EE85-4CF2-A4DA-B8437E7B0B00",
        "deficit-deadlift": "50DB2074-1BC2-4EDE-9B79-A87BAB17A087",
        "rack-pull": "7341EEB8-D433-4255-BE4C-AE9D8313C568",
        "deadlift-kettlebell": "818B76D7-9263-494A-B460-36D63D254B76",
        "bird-dog": "356570FF-2054-437E-8CD8-9CA7519AEDF7",
        "seated-overhead-press-barbell": "4939E190-2875-422D-96A3-B91A1C53B1CD",
        "behind-the-neck-press-barbell": "4903E1DC-3240-4681-B2C4-ABB810679924",
        "behind-the-neck-press-smith": "D8E15EEB-E4EB-49AB-8542-364AF95A01E0",
        "single-arm-shoulder-press-dumbbell": "1D51D4BB-A75D-4F37-A730-0AE15D474277",
        "neutral-grip-shoulder-press-dumbbell": "39529995-8B14-4797-9F12-2E4F6275AB63",
        "shoulder-press-lever": "00697E2A-1C03-4083-8394-1B46A1F29582",
        "single-arm-shoulder-press-machine": "75D815BB-566F-469D-9A94-CD111E7553EE",
        "shoulder-press-kettlebell": "CC5D181B-0902-4ECB-8FA6-AAB472BEB8E1",
        "shoulder-press-band": "75E569E5-F4B8-48B2-B1D9-2ED8E88DA922",
        "landmine-shoulder-press": "03FA10BD-B78E-4D5C-9F9D-E998E9665189",
        "push-press": "072A69DE-7EFD-4FE3-9A55-C884F69AC9DD",
        "seated-lateral-raise-dumbbell": "C7883059-A317-41AE-8CF6-16C9E6B61181",
        "lateral-raise-band": "9A1FC1BE-537F-4BB0-8DDA-476B121E852C",
        "alternating-front-raise-dumbbell": "733EEEE6-E24E-44A5-B7B3-C2857E6BB675",
        "single-arm-front-raise-cable": "4B16AD3B-F198-497C-B0F8-F7D7F51E3DC2",
        "front-raise-band": "E6F7E189-5921-4490-845B-62D59DC8E6DD",
        "incline-reverse-fly-dumbbell": "8E5C22FD-761C-463D-A953-2109836049E6",
        "reverse-fly-band": "7073E06F-0A94-4CB8-8DD0-BBC7C7D79982",
        "face-pull-band": "DD4B7EE6-2FA8-4A9E-AAAD-5C6B437C2213",
        "upright-row-smith": "686CEB1E-F69E-4E23-9941-F77A9A7BC566",
        "external-rotation-dumbbell": "8955FFBC-DF4D-41A2-8882-593F133E1AA1",
        "external-rotation-band": "BF07800A-5E19-496D-B8BD-A15C9EF18D12",
        "internal-rotation-cable": "97F8BB8E-D813-4467-A0F9-BEDDA981BDA0",
        "pike-push-up": "1CC05137-4836-46EB-AF9C-669BA7457123",
        "handstand-push-up": "ECD22BC8-899E-4F11-BF30-B1A82183FABD",
        "curl-machine": "8F95ACDF-64FD-4AFF-84C8-7376F4FD7C45",
        "curl-band": "730984C6-53E4-4B61-B47C-5A9831CF8382",
        "close-grip-curl-ez-bar": "F516869D-6226-434A-91C6-C684AD3B8D15",
        "curl-21s-barbell": "38B4CCCD-9B78-4842-A941-2DEA160FAC2A",
        "drag-curl-barbell": "2284CB51-6D80-490B-80FB-2F67B804558D",
        "alternating-hammer-curl-dumbbell": "BC357B72-4721-483F-9EE7-E76E7A16BABE",
        "cross-body-hammer-curl": "220DFE5B-DF34-49B4-944A-9E11BFCE27AC",
        "preacher-curl-barbell": "A7747478-AD64-4EF8-844F-D0B5A6AAB0F7",
        "single-arm-preacher-curl-cable": "5EED939E-978C-4F81-AE9E-83848FC40377",
        "single-arm-preacher-curl-machine": "475FC504-CB54-4DA3-8E97-0D510E057D95",
        "concentration-curl-cable": "BE74676F-2D09-46DD-8C1B-6885B3F93B39",
        "zottman-curl": "10694303-1E8E-41C8-BC7C-526D9FF00E33",
        "high-cable-curl": "CB6661BE-6028-4DCD-A828-D4175CF49196",
        "reverse-grip-pushdown": "AEF685CB-0EFA-4124-8EAF-D01C069B2C4B",
        "triceps-pushdown-v-bar": "F04DE973-11DA-48CA-A34C-6D6F8AB5D429",
        "cross-body-triceps-extension-cable": "EF2EC54C-BA82-4CBE-9B8A-DDDC12EC57E9",
        "triceps-pushdown-band": "F588831B-3944-4CA9-8F60-806DAABC44E3",
        "single-arm-overhead-extension-cable": "41C546F6-858D-4228-8038-543BC7673F3C",
        "overhead-extension-machine": "D9EDB1FF-AD39-4766-9E30-20F8CE1DE07F",
        "overhead-extension-band": "4794F87D-69A0-400B-A944-B2E39A9ADDD6",
        "skull-crusher-straight-bar": "CBBECD32-E8A6-46E0-A193-EBB0A81C34DF",
        "incline-skull-crusher-ez-bar": "238ABAA2-6174-4BDD-8AFC-CF04BDE9BF0F",
        "single-arm-skull-crusher-dumbbell": "DE773437-FBDD-4FBB-85E4-A100235A991B",
        "tate-press": "8345ADAD-FC96-46AA-B687-2BA765ACC8AF",
        "close-grip-bench-press-dumbbell": "746382AB-51AE-4452-B72F-A57880160EDB",
        "weighted-dips": "EFB1DC35-37A9-4136-8997-3DF3DF7ABEAE",
        "assisted-dips": "D44471E5-0887-4750-85AA-2612CBDF612D",
        "weighted-bench-dips": "891CFE84-4D5B-41D6-B477-B24C8005B0C8",
        "close-grip-push-up": "593637DD-8037-4208-92D7-901C3F8E31B1",
        "wrist-curl-cable": "A7FBED22-BD31-4DBE-A30F-FC957358D35C",
        "behind-the-back-wrist-curl": "E27AADEC-08B4-4DDA-8AC0-D55D25D6BD0B",
        "reverse-curl-straight-bar": "48378A0A-2CAA-4130-B2DD-BFFFCA624EAD",
        "wrist-roller": "9262742A-3738-49E1-84E1-23C55BB461A7",
        "wrist-rotation-dumbbell": "C589F864-C491-45BB-933A-ADF0DAC0CE78",
        "sit-up": "EFCADE80-10A1-46A7-9F97-5FCADEF2372A",
        "weighted-decline-crunch": "A4010807-7B1B-4691-B523-24567C195D2C",
        "v-up": "1C007C7E-1596-4527-93EB-83B7F9DE34C8",
        "rowing-crunch": "5019E787-079A-4121-A035-C92F0FD306F9",
        "heel-touch": "CB89A2D8-B9D8-4841-A57E-4EF671491641",
        "stability-ball-crunch": "7235E620-0306-4AE9-ABD6-8C54C3BCF724",
        "hanging-knee-raise": "087460FD-C5C7-40DD-8997-5A8FA3099EDA",
        "captains-chair-leg-raise": "EAF1CC34-3A39-4398-BAC6-C549B4D127B0",
        "decline-leg-raise": "91EAB8B9-671A-4BF3-A931-636F638DC7C1",
        "toes-to-bar": "79439BA9-44D5-402A-8336-171E9C83EA2D",
        "windshield-wiper": "91F005A1-74A6-4D41-9F33-15263216983C",
        "mountain-climber": "70ABB43F-4F7F-42CC-A629-EFDC179C664B",
        "side-bend-dumbbell": "691DF7BA-94FB-43EB-B42E-B867B11151DB",
        "side-bend-cable": "D15395C4-9128-40E5-A566-E9982781804B",
        "russian-twist-dumbbell": "833A426A-13EF-431E-A863-50858429AC6D",
        "torso-rotation-machine": "9B3811FC-12B3-4ECD-9487-401972309CE5",
        "reverse-cable-woodchop": "3E7F8F85-2F5E-4AF7-AC95-4E1730617011",
        "pallof-press": "9AC40950-6C31-4C03-90CF-502B61E73258",
        "squat-dumbbell": "8045D489-74CF-4D75-9FD9-545912C6722A",
        "box-squat": "3F9F16F0-A0E1-4E23-8FB2-0DE73F919D7E",
        "zercher-squat": "C85FE94A-01E6-4009-A4AB-F529294744B5",
        "overhead-squat": "D8C49719-BD95-4EC3-827D-CCE279F4A327",
        "front-squat-smith": "CACE2152-B0FA-4926-AE8C-0CB9FE11A3B0",
        "v-squat-machine": "E1D2DB9C-33B2-476A-A7D6-B3E5DD0554F2",
        "belt-squat-machine": "5301E290-9EFC-4464-8FC0-BC2733872D08",
        "bulgarian-split-squat-barbell": "03B70297-C662-4F45-A569-32243A4F526B",
        "bulgarian-split-squat-bodyweight": "05782DDE-CD21-41FE-9650-AF987FBDCD30",
        "pistol-squat": "84CBD686-1D00-41D0-93DE-258F610B5513",
        "cossack-squat": "FE459584-48DF-4BF1-96A0-5B27F44FDEED",
        "jump-squat": "1CBA35C0-6C3E-467D-A4B5-D2CA694FB829",
        "vertical-leg-press": "E6CE1B9B-1F8D-452A-AD85-040A09BB5B14",
        "lunge-bodyweight": "35072D46-D3CA-4C2F-AE70-C9F6B5ED28C2",
        "reverse-lunge-dumbbell": "96277DF1-0C3E-455C-9E45-11B5BCC81C5A",
        "reverse-lunge-barbell": "D2018202-A7A1-4AF6-8056-8191AC650F1A",
        "reverse-lunge-smith": "102C6327-0092-4B24-BB34-B3C742EB2758",
        "lateral-lunge-dumbbell": "BF0AF26F-0614-4F6E-99D3-A92093550C3B",
        "walking-lunge-bodyweight": "EBFA0BC5-75DF-4EA9-9C1D-1D7C74D0591B",
        "step-up-bodyweight": "A274B4D6-6910-4A62-A665-EFA51E95ACEA",
        "step-up-barbell": "CCCBEE74-E23B-487B-8DC3-F681E2563F96",
        "single-leg-lying-leg-curl": "5534EBDC-91C2-492E-A06F-3908A40AD972",
        "single-leg-seated-leg-curl": "E0D72F60-C42A-496F-A66B-A5BA0C5955A1",
        "kneeling-leg-curl": "B9B2FBA4-E1A0-4D1A-9F20-E4EF0725D5CC",
        "lying-leg-curl-dumbbell": "120F4BFC-3232-4654-A20D-F1F8BFDAB0C5",
        "standing-leg-curl-cable": "2E32153E-7E6C-482C-9FDA-7398943C1FB4",
        "stability-ball-leg-curl": "FEF97402-8059-441B-AED7-455D8AD3ADD2",
        "romanian-deadlift-kettlebell": "CF69D782-F259-44C2-A4F4-1105A2874016",
        "glute-ham-raise": "08837A9C-2DF3-495D-AB44-155FFFD90B28",
        "hip-thrust-dumbbell": "7B84F970-7CBB-4548-B691-49329FBFEF5C",
        "single-leg-hip-thrust": "FE38F720-2974-4F4D-9DDE-A2E701033562",
        "single-leg-hip-thrust-machine": "66692DAE-988A-4BFC-9B2F-F2F7CC9F5D1D",
        "glute-bridge-barbell": "A803F344-CC5B-476C-AEBD-1C219A22CD9C",
        "single-leg-glute-bridge": "B621FD84-9765-4E23-81ED-FC2D31692527",
        "quadruped-kickback": "05B23B2F-2329-41E0-8F9C-E3072D831991",
        "glute-kickback-smith": "B74F69B8-2BA5-4268-A6B3-AB0EE621B2D6",
        "reverse-hyperextension": "CD2244B9-52D7-4869-A222-CC224626F9DB",
        "cable-pull-through": "D9395DE5-8675-404A-81D5-40DBAE5967B7",
        "reverse-hack-squat": "E0905767-458C-458C-BDF7-7797FD90A634",
        "sumo-squat-kettlebell": "D247B473-6B47-4464-AAC7-F05F7E23D44B",
        "sumo-squat-smith": "8BEAD648-CC95-4AB4-9710-2DD4B4EE5B09",
        "curtsy-lunge-dumbbell": "D87FC72F-FCFF-4274-9B5E-D31D70C10CAD",
        "standing-hip-abduction-machine": "0C0BBF49-2B58-439B-8B35-B653A6068B25",
        "side-lying-hip-abduction": "BFE45AFC-D496-4151-B647-6955361D2CBB",
        "clamshell-band": "E015BF7B-89CC-4656-8716-B3921838418A",
        "fire-hydrant": "D99D8F2C-FA96-41C1-9845-81A322661440",
        "hip-adduction-band": "A852ECEE-53F0-437A-B531-27742133CCB6",
        "side-lying-hip-adduction": "F67FE5B5-F38F-4BED-9E52-5337B0F684E7",
        "standing-calf-raise-bodyweight": "A5A80189-1A36-44B6-AEEB-2E991626D47D",
        "standing-calf-raise-dumbbell": "8155CC18-978D-4054-9B64-A2037B864510",
        "standing-calf-raise-barbell": "99D5962A-78C8-4AD2-9FD0-62689B411B6A",
        "seated-calf-raise-dumbbell": "1D092482-613C-4822-9161-40B6595883B6",
        "hack-squat-calf-raise": "E5C908E8-18AB-489E-B4FE-8EC6244A1AFF",
        "donkey-calf-raise": "6F8FF0BA-9879-4BC0-BA39-E98D72C08459",
        "tibialis-raise": "F449F243-5DB1-4FE5-BA8B-AFED69DB9472",
        "clean-and-jerk": "2055A6E7-3AB8-49A4-B20B-0D19FD953A93",
        "snatch-barbell": "288DF240-84E6-4E11-8B22-570E18FB2937",
        "snatch-dumbbell": "C6396DC6-92CB-40DB-8B44-0B4FC3A794E3",
        "kettlebell-clean": "E99672D6-F4F3-40B1-B0A1-00BAB937F3FB",
        "thruster-kettlebell": "8FF8A8B1-A091-4141-BB6C-15B39D674C46",
        "single-arm-kettlebell-swing": "1C46EB31-03EC-48F0-A776-C36324F3E1AB",
    ]
}
