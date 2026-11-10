import Foundation
import Testing
@testable import IronFlow

struct DefaultExerciseLibraryTests {
    let library = DefaultExerciseLibrary.all

    @Test("The library has the 220 approved exercises with the approved count per muscle group, none in Outro")
    func countsPerGroup() {
        #expect(library.count == 220)
        var counts: [MuscleGroup: Int] = [:]
        for entry in library {
            counts[entry.muscleGroup, default: 0] += 1
        }
        #expect(counts == [
            .chest: 33, .back: 20, .upperBack: 10, .traps: 5, .lowerBack: 6, .shoulders: 23, .biceps: 17,
            .triceps: 23, .forearms: 7, .abs: 17, .quadriceps: 22, .hamstrings: 11, .glutes: 12, .adductors: 2,
            .calves: 5, .fullBody: 7,
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

    @Test("The library is the approved list, in its order: each name, group, equipment and focus")
    func approvedList() throws {
        let approved = try Self.approvedLines()
        let before = Dictionary(uniqueKeysWithValues: Library157Fixture.entries.map { ($0.key, $0) })
        #expect(approved.count == 220)
        #expect(approved.filter { $0.key == nil }.count == 63)
        try #require(library.count == approved.count)
        for (entry, line) in zip(library, approved) {
            #expect(entry.name == line.name, "Name of \(entry.key)")
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
    ]
}
