import Foundation

/// One exercise of the built-in library.
struct DefaultExercise: Equatable, Sendable {
    /// Stable business identity. Never changed, removed or reused.
    let key: String
    /// Fixed UUID, the same on every install. Never changed or reused.
    let id: String
    let name: String
    let muscleGroup: MuscleGroup
    /// What the exercise is done with. Library data only, never stored: the exercise screen finds it
    /// through the stored `libraryKey` (`DefaultExerciseLibrary.byKey`).
    let equipment: Equipment
    /// The muscles it works the most ("Peitoral superior"). Library data only, like `equipment`.
    let focus: String
}

/// The built-in exercise library, controlled by the app, in the order of the approved list.
///
/// Rules: keys and ids are never changed, removed or reused. Name and muscle group may be
/// corrected in a later version. Entries that leave this list stay in existing stores.
///
/// Names: the equipment goes in parentheses ("Supino Reto (Barra)"); a bodyweight exercise has none, and
/// its load is the extra weight (0 is the body alone). Barra W uses the barbell equipment. Each exercise
/// is in the group of the muscle it works the most.
enum DefaultExerciseLibrary {
    static let all: [DefaultExercise] = [
        // MARK: Peito
        DefaultExercise(key: "bench-press-barbell", id: "2A8DF1B0-3059-46E9-8A28-0249DFFF35A3", name: "Supino Reto (Barra)", muscleGroup: .chest, equipment: .barbell, focus: "Peitoral médio"),
        DefaultExercise(key: "bench-press-dumbbell", id: "8BE65287-7F57-42CE-9FC1-25932355AE5A", name: "Supino Reto (Halter)", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral médio"),
        DefaultExercise(key: "chest-press-machine", id: "916E8492-AC56-49B2-8459-A029513409C3", name: "Supino Reto (Máquina)", muscleGroup: .chest, equipment: .machine, focus: "Peitoral médio"),
        DefaultExercise(key: "bench-press-smith", id: "4FDC80AD-759B-469B-9107-6D496BB31AF0", name: "Supino Reto (Smith)", muscleGroup: .chest, equipment: .smith, focus: "Peitoral médio"),
        DefaultExercise(key: "bench-press-cable", id: "A14779F1-530A-4C91-9EED-FD747EC88C85", name: "Supino Reto (Polia)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral médio"),
        DefaultExercise(key: "chest-press-lever", id: "8D00B5A8-6463-409E-9995-81A2734A88E4", name: "Supino Reto Iso-Lateral (Máquina)", muscleGroup: .chest, equipment: .machine, focus: "Peitoral médio"),
        DefaultExercise(key: "incline-bench-press-barbell", id: "EFE20D78-2A00-4EFB-BED3-024357710F23", name: "Supino Inclinado (Barra)", muscleGroup: .chest, equipment: .barbell, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-bench-press-dumbbell", id: "F207C734-07C0-41E5-8310-AA1611CFB38C", name: "Supino Inclinado (Halter)", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-chest-press-machine", id: "A31F129E-B3D3-4540-96D9-BC0E463C01C3", name: "Supino Inclinado (Máquina)", muscleGroup: .chest, equipment: .machine, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-bench-press-smith", id: "F003A695-A21E-4C35-A0B1-E672FA2F474D", name: "Supino Inclinado (Smith)", muscleGroup: .chest, equipment: .smith, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-bench-press-cable", id: "139A7832-60F5-4D7C-9009-311F92BE01E2", name: "Supino Inclinado (Polia)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral superior"),
        DefaultExercise(key: "decline-bench-press-barbell", id: "5F72F996-41A5-4D32-AEB2-2154411A4566", name: "Supino Declinado (Barra)", muscleGroup: .chest, equipment: .barbell, focus: "Peitoral inferior"),
        DefaultExercise(key: "decline-bench-press-dumbbell", id: "57CF4F47-8D59-4D7C-9993-A99768C40F2A", name: "Supino Declinado (Halter)", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral inferior"),
        DefaultExercise(key: "decline-chest-press-machine", id: "C320DD5B-A263-4D26-8A88-2D1557BB46B1", name: "Supino Declinado (Máquina)", muscleGroup: .chest, equipment: .machine, focus: "Peitoral inferior"),
        DefaultExercise(key: "decline-bench-press-smith", id: "75F2205B-0DE6-4384-BC01-9CD9918674D7", name: "Supino Declinado (Smith)", muscleGroup: .chest, equipment: .smith, focus: "Peitoral inferior"),
        DefaultExercise(key: "decline-bench-press-cable", id: "D1AABBEB-1EEF-40A9-9A2E-5C444FCB21E8", name: "Supino Declinado (Polia)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral inferior"),
        DefaultExercise(key: "seated-chest-press-machine", id: "DFAF5159-F81D-4C31-B766-DBDD1DD45F91", name: "Supino Sentado (Máquina)", muscleGroup: .chest, equipment: .machine, focus: "Peitoral médio"),
        DefaultExercise(key: "seated-chest-press-cable", id: "26A9D91B-3600-41CE-B1F3-79F34199E07D", name: "Supino Sentado (Polia)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral médio"),
        DefaultExercise(key: "fly-dumbbell", id: "EF31C314-C1EB-48CD-9FF8-D3E0A2A16B69", name: "Crucifixo (Halter)", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral (alongamento)"),
        DefaultExercise(key: "fly-machine", id: "432E6DC6-193A-4B02-8CBA-0AD196069BB7", name: "Crucifixo (Máquina)", muscleGroup: .chest, equipment: .machine, focus: "Peitoral (contração)"),
        DefaultExercise(key: "fly-cable", id: "3396FD56-4170-44B4-A65D-E885B036292F", name: "Crucifixo (Polia)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral médio"),
        DefaultExercise(key: "incline-fly-dumbbell", id: "D714DEA6-1CFB-4A0E-A62C-5014005E60AA", name: "Crucifixo Inclinado (Halter)", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-fly-machine", id: "BC5BC023-E74A-4F72-8DFF-60E8A53371E2", name: "Crucifixo Inclinado (Máquina)", muscleGroup: .chest, equipment: .machine, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-fly-cable", id: "A8FEFECE-4E10-40D6-9964-8E072A142957", name: "Crucifixo Inclinado (Polia)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral superior"),
        DefaultExercise(key: "cable-crossover", id: "EE3EBFB6-1880-439A-83FD-CE25C4026E91", name: "Crossover (Polia Alta)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral inferior"),
        DefaultExercise(key: "cable-crossover-mid", id: "256DF723-7783-41B1-A8D8-18F1551FA20C", name: "Crossover (Polia Média)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral médio"),
        DefaultExercise(key: "cable-crossover-low", id: "BF0FC340-7B1B-42F2-AC72-801F3D257584", name: "Crossover (Polia Baixa)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral superior"),
        DefaultExercise(key: "single-arm-cable-crossover", id: "59C29ADB-6DFB-436C-8155-E516DF366841", name: "Crossover Unilateral (Polia)", muscleGroup: .chest, equipment: .cable, focus: "Peitoral (contração)"),
        DefaultExercise(key: "push-up", id: "1E3B1E6B-B655-42CC-946E-6DE1DD17C934", name: "Flexão", muscleGroup: .chest, equipment: .bodyweight, focus: "Peitoral e tríceps"),
        DefaultExercise(key: "decline-push-up", id: "7F7C8AB2-57D8-497E-963D-2EEFFA5922BE", name: "Flexão Declinada", muscleGroup: .chest, equipment: .bodyweight, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-push-up", id: "3E49E429-B361-433A-BBBC-50DD1306305E", name: "Flexão Inclinada", muscleGroup: .chest, equipment: .bodyweight, focus: "Peitoral inferior"),
        DefaultExercise(key: "knee-push-up", id: "5873429C-978A-45E8-A529-2F6B64C746B9", name: "Flexão com Joelhos Apoiados", muscleGroup: .chest, equipment: .bodyweight, focus: "Peitoral e tríceps"),
        DefaultExercise(key: "chest-dips", id: "13BD9806-A427-4B3C-82AB-C417AA95A806", name: "Peito na Paralela", muscleGroup: .chest, equipment: .bodyweight, focus: "Peitoral inferior"),

        // MARK: Dorsais
        DefaultExercise(key: "pull-up", id: "B4C39763-E2C4-4115-86D8-46FDEB6897CD", name: "Barra Fixa (Pegada Aberta)", muscleGroup: .back, equipment: .bodyweight, focus: "Dorsal (largura)"),
        DefaultExercise(key: "close-grip-pull-up", id: "28F1B731-96E6-4877-8E2B-F45B56AE386E", name: "Barra Fixa (Pegada Fechada)", muscleGroup: .back, equipment: .bodyweight, focus: "Dorsal (parte baixa)"),
        DefaultExercise(key: "chin-up", id: "226CC388-4C45-4948-9A2B-A8BFA9D5B616", name: "Barra Fixa (Pegada Supinada)", muscleGroup: .back, equipment: .bodyweight, focus: "Dorsal e bíceps"),
        DefaultExercise(key: "assisted-pull-up", id: "F63EB411-7950-450A-A723-AFA3955583D3", name: "Barra Fixa (Graviton)", muscleGroup: .back, equipment: .machine, focus: "Dorsal (largura)"),
        DefaultExercise(key: "lat-pulldown", id: "EF0C3EAD-71E2-427F-8DE1-CB1CAF6B6043", name: "Puxada Alta Aberta (Polia)", muscleGroup: .back, equipment: .cable, focus: "Dorsal (largura)"),
        DefaultExercise(key: "close-grip-lat-pulldown", id: "B9CA24BD-12BE-477A-8004-7A366D6A6BD4", name: "Puxada Alta Fechada (Polia)", muscleGroup: .back, equipment: .cable, focus: "Dorsal (parte baixa)"),
        DefaultExercise(key: "reverse-grip-lat-pulldown", id: "6910FFBA-DBFF-4A09-872B-C74A183058AB", name: "Puxada Alta Supinada (Polia)", muscleGroup: .back, equipment: .cable, focus: "Dorsal e bíceps"),
        DefaultExercise(key: "lat-pulldown-machine", id: "AD589024-E54E-447F-A92F-B555CD8DFD3D", name: "Puxada Alta (Máquina)", muscleGroup: .back, equipment: .machine, focus: "Dorsal (largura)"),
        DefaultExercise(key: "single-arm-lat-pulldown", id: "C160A719-3F0E-4996-8075-E4B20F9C9F0E", name: "Puxada Unilateral (Polia)", muscleGroup: .back, equipment: .cable, focus: "Dorsal (amplitude total)"),
        DefaultExercise(key: "single-arm-lat-pulldown-machine", id: "CAF97DF2-C7CB-4DDC-9ED4-821006EA3559", name: "Puxada Unilateral (Máquina)", muscleGroup: .back, equipment: .machine, focus: "Dorsal (amplitude total)"),
        DefaultExercise(key: "reverse-grip-bent-over-row", id: "B813F95A-5E05-44E8-A1B4-5725C56F662A", name: "Remada Curvada Supinada (Barra)", muscleGroup: .back, equipment: .barbell, focus: "Dorsal (parte baixa)"),
        DefaultExercise(key: "one-arm-row-dumbbell", id: "6DA533D8-9699-49C1-8BC9-CA31E0DC926E", name: "Remada Serrote (Halter)", muscleGroup: .back, equipment: .dumbbell, focus: "Dorsal"),
        DefaultExercise(key: "single-arm-row-cable", id: "24488176-1FE8-4030-8D4A-AF4F9C37C673", name: "Remada Unilateral (Polia)", muscleGroup: .back, equipment: .cable, focus: "Dorsal"),
        DefaultExercise(key: "single-arm-row-machine", id: "992C150B-3DF9-4B5D-8F40-E80836A7127A", name: "Remada Unilateral (Máquina)", muscleGroup: .back, equipment: .machine, focus: "Dorsal"),
        DefaultExercise(key: "seated-cable-row", id: "96192D2A-5DD7-4CF0-9A09-7C7476B4BC0E", name: "Remada Baixa (Polia)", muscleGroup: .back, equipment: .cable, focus: "Dorsal e meio das costas"),
        DefaultExercise(key: "high-row-machine", id: "6790D887-711C-4CA6-B5AD-86C60C439940", name: "Remada Alta (Máquina)", muscleGroup: .back, equipment: .machine, focus: "Dorsal"),
        DefaultExercise(key: "pullover-dumbbell", id: "343A595A-3830-4FA3-83BA-C7B7F7C5F8CA", name: "Pullover (Halter)", muscleGroup: .back, equipment: .dumbbell, focus: "Dorsal e peitoral"),
        DefaultExercise(key: "pullover-barbell", id: "7F8D6F93-5C43-4622-82D0-BC499D9A8F53", name: "Pullover (Barra)", muscleGroup: .back, equipment: .barbell, focus: "Dorsal e peitoral"),
        DefaultExercise(key: "straight-arm-pulldown", id: "4EC1E018-0130-4B5E-A989-DF527139405B", name: "Pullover (Polia)", muscleGroup: .back, equipment: .cable, focus: "Dorsal (isolado)"),
        DefaultExercise(key: "pullover-machine", id: "A5E6EA3B-0329-4CC8-A28D-2E0F7651432A", name: "Pullover (Máquina)", muscleGroup: .back, equipment: .machine, focus: "Dorsal (isolado)"),

        // MARK: Costas superiores
        DefaultExercise(key: "bent-over-row-barbell", id: "C4052FD4-1A83-4B58-A863-1C27F9E68B03", name: "Remada Curvada (Barra)", muscleGroup: .upperBack, equipment: .barbell, focus: "Espessura das costas"),
        DefaultExercise(key: "bent-over-row-dumbbell", id: "015C9D09-72E3-4D4F-9AC3-D61ED3DFE569", name: "Remada Curvada (Halter)", muscleGroup: .upperBack, equipment: .dumbbell, focus: "Espessura das costas"),
        DefaultExercise(key: "bent-over-row-smith", id: "31C75782-4934-46F0-BD80-087C7EF98244", name: "Remada Curvada (Smith)", muscleGroup: .upperBack, equipment: .smith, focus: "Espessura das costas"),
        DefaultExercise(key: "t-bar-row", id: "1014C215-8E06-44CE-AA3B-8DC7CA8682F1", name: "Remada Cavalinho (Barra)", muscleGroup: .upperBack, equipment: .barbell, focus: "Meio das costas"),
        DefaultExercise(key: "t-bar-row-machine", id: "61049916-7CE1-4CDF-86B3-17ADA76E2255", name: "Remada T-Bar (Máquina)", muscleGroup: .upperBack, equipment: .machine, focus: "Meio das costas"),
        DefaultExercise(key: "row-lever-machine", id: "445F1828-40F5-4C66-900C-050E47840613", name: "Remada Baixa Iso-Lateral (Máquina)", muscleGroup: .upperBack, equipment: .machine, focus: "Espessura das costas"),
        DefaultExercise(key: "wide-grip-seated-cable-row", id: "237903F3-4280-4E88-9673-33F54C3DAC2B", name: "Remada Sentada Aberta (Polia)", muscleGroup: .upperBack, equipment: .cable, focus: "Costas superiores e romboides"),
        DefaultExercise(key: "row-machine", id: "F7C34293-0230-4D7E-93F8-A66EDAA878EB", name: "Remada Sentada Aberta (Máquina)", muscleGroup: .upperBack, equipment: .machine, focus: "Costas superiores e romboides"),
        DefaultExercise(key: "v-grip-row-machine", id: "CFA196F2-588C-4DDD-A56A-C553E1E24ECE", name: "Remada Sentada Pegada V (Máquina)", muscleGroup: .upperBack, equipment: .machine, focus: "Meio das costas"),
        DefaultExercise(key: "seal-row", id: "A6A4E293-7C3E-48B8-B042-675D3C12CD31", name: "Remada Apoiada no Banco (Halter)", muscleGroup: .upperBack, equipment: .dumbbell, focus: "Meio das costas"),

        // MARK: Trapézio
        DefaultExercise(key: "shrug-barbell", id: "AF64B90F-C342-4466-A672-6236E54316A7", name: "Encolhimento (Barra)", muscleGroup: .traps, equipment: .barbell, focus: "Trapézio superior"),
        DefaultExercise(key: "shrug-dumbbell", id: "1B22DE68-44A1-4DD4-B93D-4E0AE489E439", name: "Encolhimento (Halter)", muscleGroup: .traps, equipment: .dumbbell, focus: "Trapézio superior"),
        DefaultExercise(key: "shrug-smith", id: "50590B97-3AA4-4B88-8825-49C2C9BDA4B6", name: "Encolhimento (Smith)", muscleGroup: .traps, equipment: .smith, focus: "Trapézio superior"),
        DefaultExercise(key: "shrug-machine", id: "20D4403C-6C92-427D-A6AB-986BC77C9179", name: "Encolhimento (Máquina)", muscleGroup: .traps, equipment: .machine, focus: "Trapézio superior"),
        DefaultExercise(key: "shrug-cable", id: "A3C747BD-8736-412A-A716-702604858160", name: "Encolhimento (Polia)", muscleGroup: .traps, equipment: .cable, focus: "Trapézio superior"),

        // MARK: Lombar
        DefaultExercise(key: "back-extension", id: "D22B881D-624B-439F-9AE1-22EADD865A0D", name: "Extensão Lombar", muscleGroup: .lowerBack, equipment: .bodyweight, focus: "Lombar"),
        DefaultExercise(key: "back-extension-plate", id: "A27B4AFA-87E5-4C42-A0E0-2E3C13FD1725", name: "Extensão Lombar (Anilha)", muscleGroup: .lowerBack, equipment: .plate, focus: "Lombar"),
        DefaultExercise(key: "back-extension-machine", id: "64C30AF4-D275-47F3-B5C6-C0C0F83C4811", name: "Extensão Lombar (Máquina)", muscleGroup: .lowerBack, equipment: .machine, focus: "Lombar"),
        DefaultExercise(key: "superman", id: "49CE5F30-05F6-4046-B224-6C9A4E67B0CD", name: "Super-Homem", muscleGroup: .lowerBack, equipment: .bodyweight, focus: "Lombar"),
        DefaultExercise(key: "deadlift", id: "CC2B68C8-727F-49C9-AFDC-8B338BE8C692", name: "Levantamento Terra (Barra)", muscleGroup: .lowerBack, equipment: .barbell, focus: "Lombar e cadeia posterior"),
        DefaultExercise(key: "deadlift-dumbbell", id: "B961FC90-D332-4077-9AC0-7CFF63D97C53", name: "Levantamento Terra (Halter)", muscleGroup: .lowerBack, equipment: .dumbbell, focus: "Lombar e cadeia posterior"),

        // MARK: Ombros
        DefaultExercise(key: "overhead-press-barbell", id: "EBDDA760-71D6-4F7B-A96C-608A69A865D0", name: "Desenvolvimento (Barra)", muscleGroup: .shoulders, equipment: .barbell, focus: "Deltoide anterior"),
        DefaultExercise(key: "shoulder-press-dumbbell", id: "B245B003-04B8-45CC-AE95-1C32B437A8DC", name: "Desenvolvimento (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoides anterior e lateral"),
        DefaultExercise(key: "shoulder-press-machine", id: "76C03A25-36D5-4066-99BA-0854E91AED82", name: "Desenvolvimento (Máquina)", muscleGroup: .shoulders, equipment: .machine, focus: "Deltoide anterior"),
        DefaultExercise(key: "shoulder-press-smith", id: "D29F18D0-5913-455B-8BF2-6553739BF46D", name: "Desenvolvimento (Smith)", muscleGroup: .shoulders, equipment: .smith, focus: "Deltoide anterior"),
        DefaultExercise(key: "arnold-press", id: "75353C0D-F873-419C-98CA-C8BA0BD89B84", name: "Desenvolvimento Arnold (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide completo"),
        DefaultExercise(key: "lateral-raise-dumbbell", id: "EE3F5702-F5F8-473C-BA24-DD46766A8B87", name: "Elevação Lateral (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide lateral"),
        DefaultExercise(key: "lateral-raise-cable", id: "F8A98D05-8F42-41B1-85C5-08F15D814940", name: "Elevação Lateral (Polia)", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide lateral"),
        DefaultExercise(key: "lateral-raise-machine", id: "BE170859-477E-47B4-BBCF-C4494B125C2F", name: "Elevação Lateral (Máquina)", muscleGroup: .shoulders, equipment: .machine, focus: "Deltoide lateral"),
        DefaultExercise(key: "single-arm-lateral-raise-dumbbell", id: "0A7A2EC9-C85B-4278-A6C6-83CE08FAEE4C", name: "Elevação Lateral Unilateral (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide lateral"),
        DefaultExercise(key: "single-arm-lateral-raise-cable", id: "1895F788-5A94-4153-B17C-83CDCADFFFA6", name: "Elevação Lateral Unilateral (Polia)", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide lateral"),
        DefaultExercise(key: "front-raise-dumbbell", id: "3A1666E9-FAB2-4DE7-BD12-0C0DF6D92697", name: "Elevação Frontal (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide anterior"),
        DefaultExercise(key: "front-raise-barbell", id: "F56C9460-E524-472C-B6F7-695D9A201753", name: "Elevação Frontal (Barra)", muscleGroup: .shoulders, equipment: .barbell, focus: "Deltoide anterior"),
        DefaultExercise(key: "front-raise-plate", id: "634B168B-669C-4740-9C17-430F6B56F141", name: "Elevação Frontal (Anilha)", muscleGroup: .shoulders, equipment: .plate, focus: "Deltoide anterior"),
        DefaultExercise(key: "front-raise-cable", id: "E3E7E54D-0012-41E3-9556-2BAA053F9EA1", name: "Elevação Frontal (Polia)", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide anterior"),
        DefaultExercise(key: "reverse-fly-dumbbell", id: "0D0F986B-182E-414E-B879-7E2DF51C1071", name: "Crucifixo Invertido (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide posterior"),
        DefaultExercise(key: "reverse-fly-machine", id: "904E53C4-F290-416D-A21E-65A9528D1091", name: "Crucifixo Invertido (Máquina)", muscleGroup: .shoulders, equipment: .machine, focus: "Deltoide posterior"),
        DefaultExercise(key: "reverse-fly-cable", id: "18F19B1A-700D-411E-996E-428E336FD5DD", name: "Crucifixo Invertido (Polia)", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide posterior"),
        DefaultExercise(key: "single-arm-reverse-fly-cable", id: "1766A0C1-60BF-46D0-AB1B-84CA4D4B8230", name: "Crucifixo Invertido Unilateral (Polia)", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide posterior"),
        DefaultExercise(key: "face-pull", id: "10B33D70-0CC9-45B9-B2FA-B448603D6F77", name: "Face Pull (Polia)", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide posterior e manguito rotador"),
        DefaultExercise(key: "upright-row-barbell", id: "03438B07-81AD-4AD1-88AC-56349368A173", name: "Remada Alta (Barra)", muscleGroup: .shoulders, equipment: .barbell, focus: "Deltoide lateral e trapézio"),
        DefaultExercise(key: "upright-row-dumbbell", id: "770DA728-6956-4E8A-BDCB-9E66D645A6B0", name: "Remada Alta (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide lateral e trapézio"),
        DefaultExercise(key: "upright-row-cable", id: "8A98AE31-F2A6-4A12-BDC9-919347C016A8", name: "Remada Alta (Polia)", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide lateral e trapézio"),
        DefaultExercise(key: "external-rotation-cable", id: "E4274798-D911-4BCF-BABD-33FC00F37304", name: "Rotação Externa (Polia)", muscleGroup: .shoulders, equipment: .cable, focus: "Manguito rotador"),

        // MARK: Bíceps
        DefaultExercise(key: "curl-barbell", id: "5DE24313-22D9-4860-A20E-BC4593835349", name: "Rosca Direta (Barra)", muscleGroup: .biceps, equipment: .barbell, focus: "Bíceps (geral)"),
        DefaultExercise(key: "curl-ez-bar", id: "79084BA0-A64E-4C03-B6F2-77E5A43A076B", name: "Rosca Direta (Barra W)", muscleGroup: .biceps, equipment: .barbell, focus: "Bíceps (geral, menos tensão no punho)"),
        DefaultExercise(key: "curl-dumbbell", id: "AC7033DF-B837-4881-B1D7-6E8BAB84D129", name: "Rosca Direta (Halter)", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (geral)"),
        DefaultExercise(key: "alternating-curl-dumbbell", id: "165B5981-72A7-4405-B4C5-62E9BEEE0A54", name: "Rosca Alternada (Halter)", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (geral)"),
        DefaultExercise(key: "curl-cable", id: "61D5ACA4-FD2B-4F00-BC53-AA2170579306", name: "Rosca Direta (Polia)", muscleGroup: .biceps, equipment: .cable, focus: "Bíceps (tensão contínua)"),
        DefaultExercise(key: "single-arm-curl-cable", id: "4C3B63B3-455B-4129-AC31-BB3714AD87E6", name: "Rosca Unilateral (Polia)", muscleGroup: .biceps, equipment: .cable, focus: "Bíceps (tensão contínua)"),
        DefaultExercise(key: "bayesian-curl-cable", id: "705997F2-9C59-40BE-B348-FB6A6C2A29CE", name: "Rosca Bayesiana (Polia)", muscleGroup: .biceps, equipment: .cable, focus: "Bíceps (cabeça longa)"),
        DefaultExercise(key: "preacher-curl", id: "8C7A9E79-6136-4E37-9DB8-E3E51BF794BA", name: "Rosca Scott (Barra W)", muscleGroup: .biceps, equipment: .barbell, focus: "Bíceps (cabeça curta)"),
        DefaultExercise(key: "preacher-curl-machine", id: "74CCF9C2-8B8D-477A-9DE2-F9ADE4FE0D4A", name: "Rosca Scott (Máquina)", muscleGroup: .biceps, equipment: .machine, focus: "Bíceps (cabeça curta)"),
        DefaultExercise(key: "preacher-curl-cable", id: "DC34389A-6210-43FE-A403-3E6A9D79396D", name: "Rosca Scott (Polia)", muscleGroup: .biceps, equipment: .cable, focus: "Bíceps (cabeça curta)"),
        DefaultExercise(key: "preacher-curl-dumbbell", id: "6FA7E0CF-73B6-4C33-8644-7AB6E8CAF88A", name: "Rosca Scott Unilateral (Halter)", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (cabeça curta)"),
        DefaultExercise(key: "concentration-curl", id: "D1A7BD27-C7FC-46A3-95C9-310050E31A6B", name: "Rosca Concentrada (Halter)", muscleGroup: .biceps, equipment: .dumbbell, focus: "Pico do bíceps"),
        DefaultExercise(key: "hammer-curl-dumbbell", id: "CB64654F-E743-425D-9CF0-564BBCD3F300", name: "Rosca Martelo (Halter)", muscleGroup: .biceps, equipment: .dumbbell, focus: "Braquial e braquiorradial"),
        DefaultExercise(key: "hammer-curl-rope", id: "90E8F1A7-00CA-4054-A4CB-C9B72CBD95B2", name: "Rosca Martelo (Polia)", muscleGroup: .biceps, equipment: .cable, focus: "Braquial e braquiorradial"),
        DefaultExercise(key: "incline-curl-dumbbell", id: "613574DD-43BB-4CAB-A56C-938BB9A22382", name: "Rosca Inclinada (Halter)", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (cabeça longa)"),
        DefaultExercise(key: "spider-curl-ez-bar", id: "07956F8F-C361-4F10-84E2-7DDADAFE8B23", name: "Rosca Spider (Barra W)", muscleGroup: .biceps, equipment: .barbell, focus: "Bíceps (cabeça curta)"),
        DefaultExercise(key: "spider-curl-dumbbell", id: "080B9377-7A85-478C-9ABD-83831CFE03CA", name: "Rosca Spider (Halter)", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (cabeça curta)"),

        // MARK: Tríceps
        DefaultExercise(key: "triceps-pushdown-bar", id: "129B6EDC-93B4-4969-AF26-8D014C4F23B5", name: "Tríceps Pulley (Polia)", muscleGroup: .triceps, equipment: .cable, focus: "Cabeças lateral e medial"),
        DefaultExercise(key: "triceps-pushdown-rope", id: "EA9F719C-A66E-4F78-9609-C4E5FE07E47C", name: "Tríceps Corda (Polia)", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça lateral"),
        DefaultExercise(key: "single-arm-triceps-pushdown", id: "7A1B220C-5CC8-48CE-A04D-7AC95DA90826", name: "Tríceps Unilateral (Polia)", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça lateral"),
        DefaultExercise(key: "single-arm-reverse-grip-pushdown", id: "0EFDC351-6501-41D3-BCC3-8438D6B2CC61", name: "Tríceps Unilateral Invertido (Polia)", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça medial"),
        DefaultExercise(key: "overhead-extension-dumbbell", id: "CD72E327-6CDA-4091-B035-8B52C888B229", name: "Extensão de Tríceps Acima da Cabeça (Halter)", muscleGroup: .triceps, equipment: .dumbbell, focus: "Cabeça longa"),
        DefaultExercise(key: "overhead-extension-ez-bar", id: "D05AC5FE-92AF-4967-BC4C-BA6555B03945", name: "Extensão de Tríceps Acima da Cabeça (Barra W)", muscleGroup: .triceps, equipment: .barbell, focus: "Cabeça longa"),
        DefaultExercise(key: "overhead-extension-rope", id: "E8412A75-8C36-44F6-8E4F-C6B2DD969DEB", name: "Extensão de Tríceps Acima da Cabeça (Polia)", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça longa"),
        DefaultExercise(key: "single-arm-overhead-extension-dumbbell", id: "0E9FD0FE-5C9D-4122-981D-6D868B997CE0", name: "Extensão de Tríceps Unilateral (Halter)", muscleGroup: .triceps, equipment: .dumbbell, focus: "Cabeça longa"),
        DefaultExercise(key: "triceps-extension-machine", id: "F67686F3-EAD6-40EE-93C3-28000E1B8AE9", name: "Extensão de Tríceps (Máquina)", muscleGroup: .triceps, equipment: .machine, focus: "Tríceps (geral)"),
        DefaultExercise(key: "skull-crusher-barbell", id: "B3BF4DA4-9FA0-4675-8FC8-ABC089E49DBC", name: "Tríceps Testa (Barra W)", muscleGroup: .triceps, equipment: .barbell, focus: "Cabeça longa"),
        DefaultExercise(key: "skull-crusher-dumbbell", id: "FB59F4CD-A2B7-497A-A397-C03BA7E3F46D", name: "Tríceps Testa (Halter)", muscleGroup: .triceps, equipment: .dumbbell, focus: "Cabeça longa"),
        DefaultExercise(key: "skull-crusher-cable", id: "1C296FCF-E863-460A-9988-853473C2D813", name: "Tríceps Testa (Polia)", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça longa"),
        DefaultExercise(key: "skull-crusher-smith", id: "38A960C6-5A73-4276-B8F9-A205201DD068", name: "Tríceps Testa (Smith)", muscleGroup: .triceps, equipment: .smith, focus: "Cabeça longa"),
        DefaultExercise(key: "kickback-dumbbell", id: "8244BCB7-6383-4770-8AE4-E1279D81E50F", name: "Tríceps Coice (Halter)", muscleGroup: .triceps, equipment: .dumbbell, focus: "Cabeça lateral"),
        DefaultExercise(key: "kickback-cable", id: "545C9509-08EF-456A-B7DF-D18C2676ECD5", name: "Tríceps Coice (Polia)", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça lateral"),
        DefaultExercise(key: "jm-press-barbell", id: "1E2466F8-B5E9-4263-B55A-7656392C229D", name: "JM Press (Barra)", muscleGroup: .triceps, equipment: .barbell, focus: "Tríceps (geral)"),
        DefaultExercise(key: "jm-press-smith", id: "FB8883F5-4167-45EA-B82D-3A5460B0845B", name: "JM Press (Smith)", muscleGroup: .triceps, equipment: .smith, focus: "Tríceps (geral)"),
        DefaultExercise(key: "close-grip-bench-press", id: "B49164A1-A952-4A3D-9F75-FBAB2E78375B", name: "Supino Fechado (Barra)", muscleGroup: .triceps, equipment: .barbell, focus: "Tríceps e peitoral"),
        DefaultExercise(key: "close-grip-bench-press-smith", id: "EEBBA5E2-8F5E-4F44-A03B-F48D6F5B73D1", name: "Supino Fechado (Smith)", muscleGroup: .triceps, equipment: .smith, focus: "Tríceps e peitoral"),
        DefaultExercise(key: "seated-dip-machine", id: "49E05F8F-300F-4E7C-AC51-333836C9ABBD", name: "Mergulho Sentado (Máquina)", muscleGroup: .triceps, equipment: .machine, focus: "Tríceps (geral)"),
        DefaultExercise(key: "dips", id: "1CFDD592-1E38-4415-86D8-12553A8465FE", name: "Tríceps na Paralela", muscleGroup: .triceps, equipment: .bodyweight, focus: "Tríceps (geral)"),
        DefaultExercise(key: "bench-dips", id: "0F6C0D6E-0503-4BE7-AC99-20980E90FE79", name: "Tríceps no Banco", muscleGroup: .triceps, equipment: .bodyweight, focus: "Tríceps (geral)"),
        DefaultExercise(key: "diamond-push-up", id: "1825336D-B071-47C5-83C1-AB4563135044", name: "Flexão Diamante", muscleGroup: .triceps, equipment: .bodyweight, focus: "Tríceps e peitoral"),

        // MARK: Antebraços
        DefaultExercise(key: "wrist-curl-barbell", id: "0481D3C9-EAEB-4264-88CA-685EC556BE60", name: "Rosca de Punho (Barra)", muscleGroup: .forearms, equipment: .barbell, focus: "Flexores do antebraço"),
        DefaultExercise(key: "wrist-curl-dumbbell", id: "5ED1B531-CB67-489C-910F-37D78085FB31", name: "Rosca de Punho (Halter)", muscleGroup: .forearms, equipment: .dumbbell, focus: "Flexores do antebraço"),
        DefaultExercise(key: "reverse-wrist-curl-barbell", id: "8470E422-59F5-4AC9-B0F3-8B09BA00C334", name: "Rosca de Punho Invertida (Barra)", muscleGroup: .forearms, equipment: .barbell, focus: "Extensores do antebraço"),
        DefaultExercise(key: "reverse-wrist-curl-dumbbell", id: "C5F2A423-5862-4484-BA78-A86F12B98E71", name: "Rosca de Punho Invertida (Halter)", muscleGroup: .forearms, equipment: .dumbbell, focus: "Extensores do antebraço"),
        DefaultExercise(key: "reverse-curl-barbell", id: "B60B986C-37C2-49F0-9047-8F6C93AD6348", name: "Rosca Invertida (Barra W)", muscleGroup: .forearms, equipment: .barbell, focus: "Braquiorradial"),
        DefaultExercise(key: "reverse-curl-dumbbell", id: "EEE5EB96-6125-4896-9A61-56F84AE8C432", name: "Rosca Invertida (Halter)", muscleGroup: .forearms, equipment: .dumbbell, focus: "Braquiorradial"),
        DefaultExercise(key: "reverse-curl-cable", id: "7B240C7E-6DA9-45D0-A6AD-0BEFCEA9A576", name: "Rosca Invertida (Polia)", muscleGroup: .forearms, equipment: .cable, focus: "Braquiorradial"),

        // MARK: Abdômen
        DefaultExercise(key: "crunch", id: "A281DFB5-CBE2-4467-B060-483E68E55F64", name: "Abdominal", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte superior)"),
        DefaultExercise(key: "weighted-crunch-plate", id: "9B6A83BD-199F-46C5-9E0C-F9384D1FCB27", name: "Abdominal (Anilha)", muscleGroup: .abs, equipment: .plate, focus: "Reto abdominal (parte superior)"),
        DefaultExercise(key: "cable-crunch", id: "557BF24B-D9F8-4DFE-B03C-23B713BE6F92", name: "Abdominal (Polia)", muscleGroup: .abs, equipment: .cable, focus: "Reto abdominal"),
        DefaultExercise(key: "crunch-machine", id: "E5B1AE85-EFA8-4B27-879A-E9C22B867ADE", name: "Abdominal (Máquina)", muscleGroup: .abs, equipment: .machine, focus: "Reto abdominal"),
        DefaultExercise(key: "decline-crunch", id: "448C4290-B9B6-4F14-AB34-F11022EC9452", name: "Abdominal Declinado", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal"),
        DefaultExercise(key: "reverse-crunch", id: "A4181692-FC6C-4276-BC3D-C538ED8C330D", name: "Abdominal Infra", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte inferior)"),
        DefaultExercise(key: "oblique-crunch", id: "79B0FFFD-A439-40CC-BCBE-8C548415D6FB", name: "Abdominal Oblíquo", muscleGroup: .abs, equipment: .bodyweight, focus: "Oblíquos"),
        DefaultExercise(key: "bicycle-crunch", id: "AF0DF957-B16D-47C1-820B-F92E8BE7AFC7", name: "Abdominal Bicicleta", muscleGroup: .abs, equipment: .bodyweight, focus: "Oblíquos"),
        DefaultExercise(key: "scissor-kick", id: "0E1ED61D-280E-4AB5-A6A2-C5836607DB52", name: "Abdominal Tesoura", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte inferior)"),
        DefaultExercise(key: "ab-wheel-rollout", id: "2E2A3077-0EA9-4359-AC59-9EFD034500AD", name: "Roda Abdominal", muscleGroup: .abs, equipment: .bodyweight, focus: "Core (estabilidade)"),
        DefaultExercise(key: "dragon-flag", id: "AFD2254B-F118-410F-81E9-CC52C30623F5", name: "Dragon Flag", muscleGroup: .abs, equipment: .bodyweight, focus: "Core (força)"),
        DefaultExercise(key: "lying-leg-raise", id: "F1BF928F-6C2E-44F5-AEE0-F37C000E1211", name: "Elevação de Pernas Deitado", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte inferior)"),
        DefaultExercise(key: "hanging-leg-raise", id: "9E16015B-C0AB-4D4A-987D-017E7F6C4626", name: "Elevação de Pernas na Barra Fixa", muscleGroup: .abs, equipment: .bodyweight, focus: "Parte inferior e flexores do quadril"),
        DefaultExercise(key: "captains-chair-knee-raise", id: "0C39A349-EADF-408F-8AEE-44E6849179DB", name: "Elevação de Joelhos na Paralela", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte inferior)"),
        DefaultExercise(key: "russian-twist", id: "D82081B2-5DCC-4F63-AE83-F5BA93D70A9C", name: "Rotação Russa (Anilha)", muscleGroup: .abs, equipment: .plate, focus: "Oblíquos"),
        DefaultExercise(key: "cable-woodchop", id: "D185F7C8-060E-4C6D-A08A-6B0E6873DB5C", name: "Lenhador (Polia)", muscleGroup: .abs, equipment: .cable, focus: "Oblíquos (rotação)"),
        DefaultExercise(key: "dead-bug", id: "FCC96AF0-F1D0-46A0-AA66-D28CAC9E6251", name: "Dead Bug", muscleGroup: .abs, equipment: .bodyweight, focus: "Core (estabilidade)"),

        // MARK: Quadríceps
        DefaultExercise(key: "back-squat", id: "C517F588-CCE9-43C9-A1E9-2DBCFCAF2EB4", name: "Agachamento Livre (Barra)", muscleGroup: .quadriceps, equipment: .barbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "front-squat", id: "7C1C3F6C-94B2-48ED-A61D-98186E652811", name: "Agachamento Frontal (Barra)", muscleGroup: .quadriceps, equipment: .barbell, focus: "Quadríceps"),
        DefaultExercise(key: "squat-smith", id: "7D3DD7C9-576C-4707-955A-C6A39E3CD371", name: "Agachamento (Smith)", muscleGroup: .quadriceps, equipment: .smith, focus: "Quadríceps"),
        DefaultExercise(key: "hack-squat", id: "BB7E8880-925B-4C74-973E-70184E481B73", name: "Agachamento Hack (Máquina)", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps"),
        DefaultExercise(key: "pendulum-squat", id: "B2D2E4C7-4B4A-4CCF-8E43-83B2BF911D9D", name: "Agachamento Pendular (Máquina)", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps"),
        DefaultExercise(key: "goblet-squat", id: "4BE239F6-9A5D-4ED0-97B3-1D3C32325917", name: "Agachamento Goblet (Kettlebell)", muscleGroup: .quadriceps, equipment: .kettlebell, focus: "Quadríceps"),
        DefaultExercise(key: "goblet-squat-dumbbell", id: "F5BF0562-FF37-4359-BBD3-AA19B6912F86", name: "Agachamento Goblet (Halter)", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps"),
        DefaultExercise(key: "bulgarian-split-squat", id: "2045FEDA-CA84-4BDD-ACAD-D6C73AC04A51", name: "Agachamento Búlgaro (Halter)", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "bulgarian-split-squat-smith", id: "825104FE-299A-42E7-AE09-712FB01DC895", name: "Agachamento Búlgaro (Smith)", muscleGroup: .quadriceps, equipment: .smith, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "bodyweight-squat", id: "75F5466E-D1C9-47CE-8A9B-E229C5C82BB4", name: "Agachamento sem Peso", muscleGroup: .quadriceps, equipment: .bodyweight, focus: "Quadríceps"),
        DefaultExercise(key: "sissy-squat", id: "0B8ED39E-E9C9-412D-9617-799F06A6DA6B", name: "Sissy Squat", muscleGroup: .quadriceps, equipment: .bodyweight, focus: "Reto femoral"),
        DefaultExercise(key: "leg-press", id: "CE7E1B81-9AB5-4526-8CCD-3BAE65186FA5", name: "Leg Press 45° (Máquina)", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "leg-press-horizontal", id: "7F69E303-32A6-4143-8039-CDF8BF6FF5D2", name: "Leg Press Horizontal (Máquina)", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps"),
        DefaultExercise(key: "single-leg-press", id: "BC25AD7A-BA53-41D9-823C-3E93F9613448", name: "Leg Press Unilateral (Máquina)", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "leg-extension", id: "C63B1D0E-9341-4FD1-B6F5-6B7BD8A6666E", name: "Cadeira Extensora (Máquina)", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps (isolado)"),
        DefaultExercise(key: "single-leg-extension", id: "A5D56C6E-66DA-4DA8-A091-EE1C88092436", name: "Cadeira Extensora Unilateral (Máquina)", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps (isolado)"),
        DefaultExercise(key: "lunge-dumbbell", id: "40D00DD6-61B9-4799-9499-F70F299E2BBB", name: "Afundo (Halter)", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "lunge-barbell", id: "55B29EF1-74F2-4C8C-A036-25C35BB2F3B4", name: "Afundo (Barra)", muscleGroup: .quadriceps, equipment: .barbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "lunge-smith", id: "D1B06BA4-E46E-4115-A94C-A0FA56D6CFBE", name: "Afundo (Smith)", muscleGroup: .quadriceps, equipment: .smith, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "walking-lunge-dumbbell", id: "70B05664-01F6-4ABB-894A-40B97DA68216", name: "Passada (Halter)", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "walking-lunge-barbell", id: "2ECDE858-BBD3-40D1-BC84-49B6418805EB", name: "Passada (Barra)", muscleGroup: .quadriceps, equipment: .barbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "step-up-dumbbell", id: "9B8D4982-AD47-4B50-BBAB-57A67F6FEF44", name: "Subida no Banco (Halter)", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps e glúteos"),

        // MARK: Posteriores de coxa
        DefaultExercise(key: "lying-leg-curl", id: "BA642AA8-6477-47CB-BAD2-EE698617D7CC", name: "Mesa Flexora (Máquina)", muscleGroup: .hamstrings, equipment: .machine, focus: "Posteriores (isolado)"),
        DefaultExercise(key: "seated-leg-curl", id: "6A33CF0A-0FA8-4000-B2E5-760F30BC5813", name: "Cadeira Flexora (Máquina)", muscleGroup: .hamstrings, equipment: .machine, focus: "Posteriores (isolado)"),
        DefaultExercise(key: "standing-leg-curl", id: "3BBE4B67-9413-461C-B92A-2E66F64557B6", name: "Flexora Unilateral em Pé (Máquina)", muscleGroup: .hamstrings, equipment: .machine, focus: "Posteriores (isolado)"),
        DefaultExercise(key: "romanian-deadlift-barbell", id: "070BF992-4700-4C2A-B6B6-DB2E3AA3740E", name: "Stiff (Barra)", muscleGroup: .hamstrings, equipment: .barbell, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "romanian-deadlift-dumbbell", id: "FDFB0C36-22A4-476A-A92D-2178DDAD7716", name: "Stiff (Halter)", muscleGroup: .hamstrings, equipment: .dumbbell, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "romanian-deadlift-smith", id: "03AD39F2-834B-462B-B4BA-A21F43A6BDBC", name: "Stiff (Smith)", muscleGroup: .hamstrings, equipment: .smith, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "single-leg-romanian-deadlift-dumbbell", id: "88E4BC9E-8248-48A3-9753-2BC5B9BD3E10", name: "Stiff Unilateral (Halter)", muscleGroup: .hamstrings, equipment: .dumbbell, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "rdl-barbell", id: "66A91C2E-EE56-422C-8018-1B594F0B0670", name: "Levantamento Terra Romeno (Barra)", muscleGroup: .hamstrings, equipment: .barbell, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "good-morning", id: "A0FEF74E-FA04-419F-A24C-8373963B385B", name: "Good Morning (Barra)", muscleGroup: .hamstrings, equipment: .barbell, focus: "Posteriores e lombar"),
        DefaultExercise(key: "good-morning-smith", id: "260397E6-BC71-4C8D-9959-46AF7863C31A", name: "Good Morning (Smith)", muscleGroup: .hamstrings, equipment: .smith, focus: "Posteriores e lombar"),
        DefaultExercise(key: "nordic-curl", id: "B90F4F41-9ACB-4056-B550-E6F00969FC17", name: "Flexão Nórdica", muscleGroup: .hamstrings, equipment: .bodyweight, focus: "Posteriores (fase excêntrica)"),

        // MARK: Glúteos
        DefaultExercise(key: "hip-thrust-barbell", id: "BAA2E068-F397-42D3-B12B-21A9B3527ABC", name: "Elevação Pélvica (Barra)", muscleGroup: .glutes, equipment: .barbell, focus: "Glúteo máximo"),
        DefaultExercise(key: "hip-thrust-machine", id: "6325A715-0BCB-4F51-93E9-D55684B56EB2", name: "Elevação Pélvica (Máquina)", muscleGroup: .glutes, equipment: .machine, focus: "Glúteo máximo"),
        DefaultExercise(key: "hip-thrust-smith", id: "F8C7BC93-4C73-4834-B963-E595024A5A2B", name: "Elevação Pélvica (Smith)", muscleGroup: .glutes, equipment: .smith, focus: "Glúteo máximo"),
        DefaultExercise(key: "glute-bridge", id: "3F432DB8-1C9B-4CB2-BCD9-2CDC72A6567A", name: "Ponte de Glúteo", muscleGroup: .glutes, equipment: .bodyweight, focus: "Glúteo máximo"),
        DefaultExercise(key: "cable-kickback", id: "01888996-9C1A-4661-B8FF-611A30F3A6D2", name: "Glúteo Coice (Polia)", muscleGroup: .glutes, equipment: .cable, focus: "Glúteo máximo"),
        DefaultExercise(key: "glute-kickback-machine", id: "7B3595F6-AE1C-421F-9D1C-92C77555EBCB", name: "Glúteo Coice (Máquina)", muscleGroup: .glutes, equipment: .machine, focus: "Glúteo máximo"),
        DefaultExercise(key: "hip-abduction-machine", id: "BE53D4D5-A142-4959-9770-CF7195BD098E", name: "Cadeira Abdutora (Máquina)", muscleGroup: .glutes, equipment: .machine, focus: "Glúteo médio"),
        DefaultExercise(key: "hip-abduction-cable", id: "157631E3-0E6D-4374-A672-472133A847BA", name: "Abdução de Quadril (Polia)", muscleGroup: .glutes, equipment: .cable, focus: "Glúteo médio"),
        DefaultExercise(key: "hip-abduction-band", id: "7FAB266A-4F9F-473C-8348-B061032A4E7B", name: "Abdução de Quadril (Elástico)", muscleGroup: .glutes, equipment: .band, focus: "Glúteo médio"),
        DefaultExercise(key: "lateral-band-walk", id: "259F1AD8-9863-4C12-AF74-FD217AAABB9A", name: "Caminhada Lateral (Elástico)", muscleGroup: .glutes, equipment: .band, focus: "Glúteo médio"),
        DefaultExercise(key: "sumo-squat-dumbbell", id: "4EE5DACD-EC24-41CA-A98C-AD2E064FB437", name: "Agachamento Sumô (Halter)", muscleGroup: .glutes, equipment: .dumbbell, focus: "Glúteos e adutores"),
        DefaultExercise(key: "sumo-deadlift", id: "E8D7AA94-B91B-4232-9334-7DF6BCE89F6E", name: "Levantamento Terra Sumô (Barra)", muscleGroup: .glutes, equipment: .barbell, focus: "Glúteos, adutores e posteriores"),

        // MARK: Adutores
        DefaultExercise(key: "hip-adduction-machine", id: "D70D3781-594F-4DD0-A391-A6491B960B06", name: "Cadeira Adutora (Máquina)", muscleGroup: .adductors, equipment: .machine, focus: "Adutores (parte interna da coxa)"),
        DefaultExercise(key: "hip-adduction-cable", id: "6C990FD1-E4AC-49EB-8ABC-C6FDA130AC20", name: "Adução de Quadril (Polia)", muscleGroup: .adductors, equipment: .cable, focus: "Adutores (parte interna da coxa)"),

        // MARK: Panturrilhas
        DefaultExercise(key: "standing-calf-raise", id: "7186818E-02B6-4AA3-88CD-5E3A9D4B243F", name: "Panturrilha em Pé (Máquina)", muscleGroup: .calves, equipment: .machine, focus: "Gastrocnêmio"),
        DefaultExercise(key: "calf-raise-smith", id: "5328D6F5-7D10-410C-8D23-D9955E5C652F", name: "Panturrilha em Pé (Smith)", muscleGroup: .calves, equipment: .smith, focus: "Gastrocnêmio"),
        DefaultExercise(key: "seated-calf-raise", id: "E8275D6E-BD2F-4D84-9B61-818997F78B5F", name: "Panturrilha Sentado (Máquina)", muscleGroup: .calves, equipment: .machine, focus: "Sóleo"),
        DefaultExercise(key: "leg-press-calf-raise", id: "23FD5256-DCB6-418D-8429-91F2E47CCF05", name: "Panturrilha no Leg Press (Máquina)", muscleGroup: .calves, equipment: .machine, focus: "Gastrocnêmio"),
        DefaultExercise(key: "single-leg-calf-raise-dumbbell", id: "0ADB917E-FE38-4460-8905-78A08B37AF41", name: "Panturrilha Unilateral (Halter)", muscleGroup: .calves, equipment: .dumbbell, focus: "Gastrocnêmio"),

        // MARK: Corpo inteiro
        DefaultExercise(key: "kettlebell-swing", id: "5768F1BF-317F-4944-92EB-08C9E84BF197", name: "Kettlebell Swing", muscleGroup: .fullBody, equipment: .kettlebell, focus: "Glúteos e posteriores (potência)"),
        DefaultExercise(key: "kettlebell-snatch", id: "ABCAC9B5-A370-4F48-9746-37DAB193BA56", name: "Arranco (Kettlebell)", muscleGroup: .fullBody, equipment: .kettlebell, focus: "Corpo inteiro (potência)"),
        DefaultExercise(key: "turkish-get-up", id: "C12663FE-8D07-4244-AE4B-7D76221D3C88", name: "Levantamento Turco (Kettlebell)", muscleGroup: .fullBody, equipment: .kettlebell, focus: "Estabilidade do corpo inteiro"),
        DefaultExercise(key: "thruster-barbell", id: "D3582270-5FAE-4B7D-99A3-F1DA1BE00431", name: "Thruster (Barra)", muscleGroup: .fullBody, equipment: .barbell, focus: "Pernas e ombros"),
        DefaultExercise(key: "thruster-dumbbell", id: "94F098B9-9AF6-4DCA-A9D1-0A96B5B5C1F5", name: "Thruster (Halter)", muscleGroup: .fullBody, equipment: .dumbbell, focus: "Pernas e ombros"),
        DefaultExercise(key: "power-clean", id: "372E8075-4DF9-4DC2-9EE2-4E50CFF9EA1A", name: "Power Clean (Barra)", muscleGroup: .fullBody, equipment: .barbell, focus: "Corpo inteiro (potência)"),
        DefaultExercise(key: "burpee", id: "E424EF0A-10C4-4C7C-97B4-944763A4884E", name: "Burpee", muscleGroup: .fullBody, equipment: .bodyweight, focus: "Condicionamento"),
    ]

    /// The entries by key, built once: what the library says of a built-in exercise that the store does
    /// not keep (its equipment and focus).
    static let byKey: [String: DefaultExercise] = Dictionary(all.map { ($0.key, $0) }) { first, _ in first }
}
