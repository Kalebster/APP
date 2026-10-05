import Foundation
import Testing
@testable import IronFlow

struct DefaultExerciseLibraryTests {
    let library = DefaultExerciseLibrary.all

    @Test("The library has the 71 approved exercises with the approved count per muscle group")
    func countsPerGroup() {
        #expect(library.count == 71)
        var counts: [MuscleGroup: Int] = [:]
        for entry in library {
            counts[entry.muscleGroup, default: 0] += 1
        }
        #expect(counts == [
            .chest: 9, .back: 7, .shoulders: 9, .biceps: 6, .triceps: 7, .forearms: 3, .quadriceps: 8,
            .hamstrings: 6, .glutes: 4, .calves: 3, .abs: 6, .fullBody: 2, .other: 1,
        ])
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

    @Test("Approved classifications and exclusions")
    func classifications() {
        func group(_ key: String) -> MuscleGroup? { library.first { $0.key == key }?.muscleGroup }
        #expect(group("deadlift") == .hamstrings)
        #expect(group("shrug-dumbbell") == .shoulders)
        #expect(group("dips") == .triceps)
        #expect(group("hammer-curl-dumbbell") == .biceps)
        #expect(group("hip-adduction-machine") == .other)
        #expect(group("power-clean") == nil)
        #expect(group("thruster-barbell") == nil)
        #expect(library.first { $0.key == "bench-press-barbell" }?.name == "Supino Reto com Barra")
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
    ]
}
