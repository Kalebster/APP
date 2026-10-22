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

/// The built-in exercise library, controlled by the app.
///
/// Rules: keys and ids are never changed, removed or reused. Name and muscle group may be
/// corrected in a later version. Entries that leave this list stay in existing stores.
enum DefaultExerciseLibrary {
    static let all: [DefaultExercise] = [
        // MARK: Peito
        DefaultExercise(key: "bench-press-barbell", id: "2A8DF1B0-3059-46E9-8A28-0249DFFF35A3", name: "Supino Reto com Barra", muscleGroup: .chest, equipment: .barbell, focus: "Peitoral médio"),
        DefaultExercise(key: "bench-press-dumbbell", id: "8BE65287-7F57-42CE-9FC1-25932355AE5A", name: "Supino Reto com Halteres", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral médio"),
        DefaultExercise(key: "chest-press-machine", id: "916E8492-AC56-49B2-8459-A029513409C3", name: "Supino Reto na Máquina", muscleGroup: .chest, equipment: .machine, focus: "Peitoral médio"),
        DefaultExercise(key: "bench-press-smith", id: "4FDC80AD-759B-469B-9107-6D496BB31AF0", name: "Supino Reto no Smith", muscleGroup: .chest, equipment: .smith, focus: "Peitoral médio"),
        DefaultExercise(key: "incline-bench-press-barbell", id: "EFE20D78-2A00-4EFB-BED3-024357710F23", name: "Supino Inclinado com Barra", muscleGroup: .chest, equipment: .barbell, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-bench-press-dumbbell", id: "F207C734-07C0-41E5-8310-AA1611CFB38C", name: "Supino Inclinado com Halteres", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-chest-press-machine", id: "A31F129E-B3D3-4540-96D9-BC0E463C01C3", name: "Supino Inclinado na Máquina", muscleGroup: .chest, equipment: .machine, focus: "Peitoral superior"),
        DefaultExercise(key: "incline-bench-press-smith", id: "F003A695-A21E-4C35-A0B1-E672FA2F474D", name: "Supino Inclinado no Smith", muscleGroup: .chest, equipment: .smith, focus: "Peitoral superior"),
        DefaultExercise(key: "decline-bench-press-barbell", id: "5F72F996-41A5-4D32-AEB2-2154411A4566", name: "Supino Declinado com Barra", muscleGroup: .chest, equipment: .barbell, focus: "Peitoral inferior"),
        DefaultExercise(key: "decline-bench-press-dumbbell", id: "57CF4F47-8D59-4D7C-9993-A99768C40F2A", name: "Supino Declinado com Halteres", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral inferior"),
        DefaultExercise(key: "chest-press-lever", id: "8D00B5A8-6463-409E-9995-81A2734A88E4", name: "Supino Articulado", muscleGroup: .chest, equipment: .machine, focus: "Peitoral médio"),
        DefaultExercise(key: "fly-dumbbell", id: "EF31C314-C1EB-48CD-9FF8-D3E0A2A16B69", name: "Crucifixo Reto com Halteres", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral (alongamento)"),
        DefaultExercise(key: "incline-fly-dumbbell", id: "D714DEA6-1CFB-4A0E-A62C-5014005E60AA", name: "Crucifixo Inclinado com Halteres", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral superior"),
        DefaultExercise(key: "fly-machine", id: "432E6DC6-193A-4B02-8CBA-0AD196069BB7", name: "Crucifixo na Máquina (Peck Deck)", muscleGroup: .chest, equipment: .machine, focus: "Peitoral (contração)"),
        DefaultExercise(key: "cable-crossover", id: "EE3EBFB6-1880-439A-83FD-CE25C4026E91", name: "Crossover na Polia Alta", muscleGroup: .chest, equipment: .cable, focus: "Peitoral inferior"),
        DefaultExercise(key: "cable-crossover-mid", id: "256DF723-7783-41B1-A8D8-18F1551FA20C", name: "Crossover na Polia Média", muscleGroup: .chest, equipment: .cable, focus: "Peitoral médio"),
        DefaultExercise(key: "cable-crossover-low", id: "BF0FC340-7B1B-42F2-AC72-801F3D257584", name: "Crossover na Polia Baixa", muscleGroup: .chest, equipment: .cable, focus: "Peitoral superior"),
        DefaultExercise(key: "push-up", id: "1E3B1E6B-B655-42CC-946E-6DE1DD17C934", name: "Flexão de Braço", muscleGroup: .chest, equipment: .bodyweight, focus: "Peitoral e tríceps"),
        DefaultExercise(key: "decline-push-up", id: "7F7C8AB2-57D8-497E-963D-2EEFFA5922BE", name: "Flexão com Pés Elevados", muscleGroup: .chest, equipment: .bodyweight, focus: "Peitoral superior"),
        DefaultExercise(key: "chest-dips", id: "13BD9806-A427-4B3C-82AB-C417AA95A806", name: "Mergulho nas Paralelas (Peito)", muscleGroup: .chest, equipment: .bodyweight, focus: "Peitoral inferior"),
        DefaultExercise(key: "pullover-dumbbell", id: "343A595A-3830-4FA3-83BA-C7B7F7C5F8CA", name: "Pullover com Halter", muscleGroup: .chest, equipment: .dumbbell, focus: "Peitoral e dorsal"),

        // MARK: Costas
        DefaultExercise(key: "pull-up", id: "B4C39763-E2C4-4115-86D8-46FDEB6897CD", name: "Barra Fixa Pronada", muscleGroup: .back, equipment: .bodyweight, focus: "Dorsal (largura)"),
        DefaultExercise(key: "chin-up", id: "226CC388-4C45-4948-9A2B-A8BFA9D5B616", name: "Barra Fixa Supinada", muscleGroup: .back, equipment: .bodyweight, focus: "Dorsal e bíceps"),
        DefaultExercise(key: "assisted-pull-up", id: "F63EB411-7950-450A-A723-AFA3955583D3", name: "Barra Fixa Assistida", muscleGroup: .back, equipment: .machine, focus: "Dorsal (largura)"),
        DefaultExercise(key: "lat-pulldown", id: "EF0C3EAD-71E2-427F-8DE1-CB1CAF6B6043", name: "Puxada Frontal Aberta", muscleGroup: .back, equipment: .cable, focus: "Dorsal (largura)"),
        DefaultExercise(key: "close-grip-lat-pulldown", id: "B9CA24BD-12BE-477A-8004-7A366D6A6BD4", name: "Puxada Frontal com Triângulo", muscleGroup: .back, equipment: .cable, focus: "Dorsal (parte baixa)"),
        DefaultExercise(key: "reverse-grip-lat-pulldown", id: "6910FFBA-DBFF-4A09-872B-C74A183058AB", name: "Puxada Supinada", muscleGroup: .back, equipment: .cable, focus: "Dorsal e bíceps"),
        DefaultExercise(key: "single-arm-lat-pulldown", id: "C160A719-3F0E-4996-8075-E4B20F9C9F0E", name: "Puxada Unilateral na Polia", muscleGroup: .back, equipment: .cable, focus: "Dorsal (amplitude total)"),
        DefaultExercise(key: "straight-arm-pulldown", id: "4EC1E018-0130-4B5E-A989-DF527139405B", name: "Pulldown com Braços Estendidos", muscleGroup: .back, equipment: .cable, focus: "Dorsal (isolado)"),
        DefaultExercise(key: "bent-over-row-barbell", id: "C4052FD4-1A83-4B58-A863-1C27F9E68B03", name: "Remada Curvada com Barra", muscleGroup: .back, equipment: .barbell, focus: "Espessura das costas"),
        DefaultExercise(key: "reverse-grip-bent-over-row", id: "B813F95A-5E05-44E8-A1B4-5725C56F662A", name: "Remada Curvada Supinada", muscleGroup: .back, equipment: .barbell, focus: "Dorsal (parte baixa)"),
        DefaultExercise(key: "t-bar-row", id: "1014C215-8E06-44CE-AA3B-8DC7CA8682F1", name: "Remada Cavalinho", muscleGroup: .back, equipment: .barbell, focus: "Meio das costas"),
        DefaultExercise(key: "one-arm-row-dumbbell", id: "6DA533D8-9699-49C1-8BC9-CA31E0DC926E", name: "Remada Unilateral com Halter (Serrote)", muscleGroup: .back, equipment: .dumbbell, focus: "Dorsal"),
        DefaultExercise(key: "seated-cable-row", id: "96192D2A-5DD7-4CF0-9A09-7C7476B4BC0E", name: "Remada Baixa com Triângulo", muscleGroup: .back, equipment: .cable, focus: "Meio das costas"),
        DefaultExercise(key: "wide-grip-seated-cable-row", id: "237903F3-4280-4E88-9673-33F54C3DAC2B", name: "Remada Baixa Aberta", muscleGroup: .back, equipment: .cable, focus: "Dorsal superior e romboides"),
        DefaultExercise(key: "row-machine", id: "F7C34293-0230-4D7E-93F8-A66EDAA878EB", name: "Remada na Máquina", muscleGroup: .back, equipment: .machine, focus: "Meio das costas"),
        DefaultExercise(key: "row-lever-machine", id: "445F1828-40F5-4C66-900C-050E47840613", name: "Remada Articulada", muscleGroup: .back, equipment: .machine, focus: "Espessura das costas"),
        DefaultExercise(key: "seal-row", id: "A6A4E293-7C3E-48B8-B042-675D3C12CD31", name: "Remada Apoiada no Banco (Seal)", muscleGroup: .back, equipment: .dumbbell, focus: "Meio das costas"),
        DefaultExercise(key: "bent-over-row-smith", id: "31C75782-4934-46F0-BD80-087C7EF98244", name: "Remada no Smith", muscleGroup: .back, equipment: .smith, focus: "Espessura das costas"),
        DefaultExercise(key: "deadlift", id: "CC2B68C8-727F-49C9-AFDC-8B338BE8C692", name: "Levantamento Terra", muscleGroup: .back, equipment: .barbell, focus: "Lombar e cadeia posterior"),
        DefaultExercise(key: "back-extension", id: "D22B881D-624B-439F-9AE1-22EADD865A0D", name: "Hiperextensão Lombar (Banco Romano)", muscleGroup: .back, equipment: .bodyweight, focus: "Lombar"),
        DefaultExercise(key: "shrug-barbell", id: "AF64B90F-C342-4466-A672-6236E54316A7", name: "Encolhimento com Barra", muscleGroup: .back, equipment: .barbell, focus: "Trapézio superior"),
        DefaultExercise(key: "shrug-dumbbell", id: "1B22DE68-44A1-4DD4-B93D-4E0AE489E439", name: "Encolhimento com Halteres", muscleGroup: .back, equipment: .dumbbell, focus: "Trapézio superior"),

        // MARK: Ombros
        DefaultExercise(key: "overhead-press-barbell", id: "EBDDA760-71D6-4F7B-A96C-608A69A865D0", name: "Desenvolvimento com Barra", muscleGroup: .shoulders, equipment: .barbell, focus: "Deltoide anterior"),
        DefaultExercise(key: "shoulder-press-dumbbell", id: "B245B003-04B8-45CC-AE95-1C32B437A8DC", name: "Desenvolvimento com Halteres", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoides anterior e lateral"),
        DefaultExercise(key: "shoulder-press-machine", id: "76C03A25-36D5-4066-99BA-0854E91AED82", name: "Desenvolvimento na Máquina", muscleGroup: .shoulders, equipment: .machine, focus: "Deltoide anterior"),
        DefaultExercise(key: "shoulder-press-smith", id: "D29F18D0-5913-455B-8BF2-6553739BF46D", name: "Desenvolvimento no Smith", muscleGroup: .shoulders, equipment: .smith, focus: "Deltoide anterior"),
        DefaultExercise(key: "arnold-press", id: "75353C0D-F873-419C-98CA-C8BA0BD89B84", name: "Desenvolvimento Arnold", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide completo"),
        DefaultExercise(key: "lateral-raise-dumbbell", id: "EE3F5702-F5F8-473C-BA24-DD46766A8B87", name: "Elevação Lateral com Halteres", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide lateral"),
        DefaultExercise(key: "lateral-raise-cable", id: "F8A98D05-8F42-41B1-85C5-08F15D814940", name: "Elevação Lateral na Polia", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide lateral"),
        DefaultExercise(key: "lateral-raise-machine", id: "BE170859-477E-47B4-BBCF-C4494B125C2F", name: "Elevação Lateral na Máquina", muscleGroup: .shoulders, equipment: .machine, focus: "Deltoide lateral"),
        DefaultExercise(key: "front-raise-dumbbell", id: "3A1666E9-FAB2-4DE7-BD12-0C0DF6D92697", name: "Elevação Frontal com Halteres", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide anterior"),
        DefaultExercise(key: "front-raise-plate", id: "634B168B-669C-4740-9C17-430F6B56F141", name: "Elevação Frontal com Anilha", muscleGroup: .shoulders, equipment: .plate, focus: "Deltoide anterior"),
        DefaultExercise(key: "front-raise-cable", id: "E3E7E54D-0012-41E3-9556-2BAA053F9EA1", name: "Elevação Frontal na Polia", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide anterior"),
        DefaultExercise(key: "reverse-fly-dumbbell", id: "0D0F986B-182E-414E-B879-7E2DF51C1071", name: "Crucifixo Inverso com Halteres", muscleGroup: .shoulders, equipment: .dumbbell, focus: "Deltoide posterior"),
        DefaultExercise(key: "reverse-fly-machine", id: "904E53C4-F290-416D-A21E-65A9528D1091", name: "Crucifixo Inverso na Máquina", muscleGroup: .shoulders, equipment: .machine, focus: "Deltoide posterior"),
        DefaultExercise(key: "reverse-fly-cable", id: "18F19B1A-700D-411E-996E-428E336FD5DD", name: "Crucifixo Inverso na Polia", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide posterior"),
        DefaultExercise(key: "face-pull", id: "10B33D70-0CC9-45B9-B2FA-B448603D6F77", name: "Face Pull na Polia", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide posterior e manguito rotador"),
        DefaultExercise(key: "upright-row-barbell", id: "03438B07-81AD-4AD1-88AC-56349368A173", name: "Remada Alta com Barra", muscleGroup: .shoulders, equipment: .barbell, focus: "Deltoide lateral e trapézio"),
        DefaultExercise(key: "upright-row-cable", id: "8A98AE31-F2A6-4A12-BDC9-919347C016A8", name: "Remada Alta na Polia", muscleGroup: .shoulders, equipment: .cable, focus: "Deltoide lateral e trapézio"),
        DefaultExercise(key: "external-rotation-cable", id: "E4274798-D911-4BCF-BABD-33FC00F37304", name: "Rotação Externa na Polia", muscleGroup: .shoulders, equipment: .cable, focus: "Manguito rotador"),

        // MARK: Bíceps
        DefaultExercise(key: "curl-barbell", id: "5DE24313-22D9-4860-A20E-BC4593835349", name: "Rosca Direta com Barra", muscleGroup: .biceps, equipment: .barbell, focus: "Bíceps (geral)"),
        DefaultExercise(key: "curl-ez-bar", id: "79084BA0-A64E-4C03-B6F2-77E5A43A076B", name: "Rosca Direta com Barra W", muscleGroup: .biceps, equipment: .barbell, focus: "Bíceps (geral, menos tensão no punho)"),
        DefaultExercise(key: "alternating-curl-dumbbell", id: "165B5981-72A7-4405-B4C5-62E9BEEE0A54", name: "Rosca Alternada com Halteres", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (geral)"),
        DefaultExercise(key: "curl-dumbbell", id: "AC7033DF-B837-4881-B1D7-6E8BAB84D129", name: "Rosca Simultânea com Halteres", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (geral)"),
        DefaultExercise(key: "hammer-curl-dumbbell", id: "CB64654F-E743-425D-9CF0-564BBCD3F300", name: "Rosca Martelo com Halteres", muscleGroup: .biceps, equipment: .dumbbell, focus: "Braquial e braquiorradial"),
        DefaultExercise(key: "hammer-curl-rope", id: "90E8F1A7-00CA-4054-A4CB-C9B72CBD95B2", name: "Rosca Martelo na Polia com Corda", muscleGroup: .biceps, equipment: .cable, focus: "Braquial e braquiorradial"),
        DefaultExercise(key: "preacher-curl", id: "8C7A9E79-6136-4E37-9DB8-E3E51BF794BA", name: "Rosca Scott com Barra W", muscleGroup: .biceps, equipment: .barbell, focus: "Bíceps (cabeça curta)"),
        DefaultExercise(key: "preacher-curl-machine", id: "74CCF9C2-8B8D-477A-9DE2-F9ADE4FE0D4A", name: "Rosca Scott na Máquina", muscleGroup: .biceps, equipment: .machine, focus: "Bíceps (cabeça curta)"),
        DefaultExercise(key: "preacher-curl-dumbbell", id: "6FA7E0CF-73B6-4C33-8644-7AB6E8CAF88A", name: "Rosca Scott Unilateral com Halter", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (cabeça curta)"),
        DefaultExercise(key: "incline-curl-dumbbell", id: "613574DD-43BB-4CAB-A56C-938BB9A22382", name: "Rosca Inclinada com Halteres", muscleGroup: .biceps, equipment: .dumbbell, focus: "Bíceps (cabeça longa)"),
        DefaultExercise(key: "concentration-curl", id: "D1A7BD27-C7FC-46A3-95C9-310050E31A6B", name: "Rosca Concentrada", muscleGroup: .biceps, equipment: .dumbbell, focus: "Pico do bíceps"),
        DefaultExercise(key: "curl-cable", id: "61D5ACA4-FD2B-4F00-BC53-AA2170579306", name: "Rosca na Polia Baixa", muscleGroup: .biceps, equipment: .cable, focus: "Bíceps (tensão contínua)"),
        DefaultExercise(key: "bayesian-curl-cable", id: "705997F2-9C59-40BE-B348-FB6A6C2A29CE", name: "Rosca Bayesiana na Polia", muscleGroup: .biceps, equipment: .cable, focus: "Bíceps (cabeça longa)"),
        DefaultExercise(key: "spider-curl-ez-bar", id: "07956F8F-C361-4F10-84E2-7DDADAFE8B23", name: "Rosca Spider com Barra W", muscleGroup: .biceps, equipment: .barbell, focus: "Bíceps (cabeça curta)"),

        // MARK: Tríceps
        DefaultExercise(key: "triceps-pushdown-bar", id: "129B6EDC-93B4-4969-AF26-8D014C4F23B5", name: "Tríceps na Polia com Barra", muscleGroup: .triceps, equipment: .cable, focus: "Cabeças lateral e medial"),
        DefaultExercise(key: "triceps-pushdown-rope", id: "EA9F719C-A66E-4F78-9609-C4E5FE07E47C", name: "Tríceps na Polia com Corda", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça lateral"),
        DefaultExercise(key: "single-arm-reverse-grip-pushdown", id: "0EFDC351-6501-41D3-BCC3-8438D6B2CC61", name: "Tríceps na Polia Unilateral (Pegada Inversa)", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça medial"),
        DefaultExercise(key: "overhead-extension-dumbbell", id: "CD72E327-6CDA-4091-B035-8B52C888B229", name: "Tríceps Francês com Halter", muscleGroup: .triceps, equipment: .dumbbell, focus: "Cabeça longa"),
        DefaultExercise(key: "overhead-extension-rope", id: "E8412A75-8C36-44F6-8E4F-C6B2DD969DEB", name: "Tríceps Francês na Polia com Corda", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça longa"),
        DefaultExercise(key: "skull-crusher-barbell", id: "B3BF4DA4-9FA0-4675-8FC8-ABC089E49DBC", name: "Tríceps Testa com Barra W", muscleGroup: .triceps, equipment: .barbell, focus: "Cabeça longa"),
        DefaultExercise(key: "skull-crusher-dumbbell", id: "FB59F4CD-A2B7-497A-A397-C03BA7E3F46D", name: "Tríceps Testa com Halteres", muscleGroup: .triceps, equipment: .dumbbell, focus: "Cabeça longa"),
        DefaultExercise(key: "kickback-dumbbell", id: "8244BCB7-6383-4770-8AE4-E1279D81E50F", name: "Tríceps Coice com Halter", muscleGroup: .triceps, equipment: .dumbbell, focus: "Cabeça lateral"),
        DefaultExercise(key: "kickback-cable", id: "545C9509-08EF-456A-B7DF-D18C2676ECD5", name: "Tríceps Coice na Polia", muscleGroup: .triceps, equipment: .cable, focus: "Cabeça lateral"),
        DefaultExercise(key: "triceps-extension-machine", id: "F67686F3-EAD6-40EE-93C3-28000E1B8AE9", name: "Tríceps na Máquina", muscleGroup: .triceps, equipment: .machine, focus: "Tríceps (geral)"),
        DefaultExercise(key: "close-grip-bench-press", id: "B49164A1-A952-4A3D-9F75-FBAB2E78375B", name: "Supino Fechado", muscleGroup: .triceps, equipment: .barbell, focus: "Tríceps e peitoral"),
        DefaultExercise(key: "bench-dips", id: "0F6C0D6E-0503-4BE7-AC99-20980E90FE79", name: "Mergulho no Banco", muscleGroup: .triceps, equipment: .bodyweight, focus: "Tríceps (geral)"),
        DefaultExercise(key: "dips", id: "1CFDD592-1E38-4415-86D8-12553A8465FE", name: "Mergulho nas Paralelas (Tríceps)", muscleGroup: .triceps, equipment: .bodyweight, focus: "Tríceps (geral)"),
        DefaultExercise(key: "diamond-push-up", id: "1825336D-B071-47C5-83C1-AB4563135044", name: "Flexão Diamante", muscleGroup: .triceps, equipment: .bodyweight, focus: "Tríceps e peitoral"),

        // MARK: Antebraços
        DefaultExercise(key: "wrist-curl-barbell", id: "0481D3C9-EAEB-4264-88CA-685EC556BE60", name: "Rosca de Punho com Barra", muscleGroup: .forearms, equipment: .barbell, focus: "Flexores do antebraço"),
        DefaultExercise(key: "reverse-wrist-curl-barbell", id: "8470E422-59F5-4AC9-B0F3-8B09BA00C334", name: "Rosca de Punho Invertida com Barra", muscleGroup: .forearms, equipment: .barbell, focus: "Extensores do antebraço"),
        DefaultExercise(key: "wrist-curl-dumbbell", id: "5ED1B531-CB67-489C-910F-37D78085FB31", name: "Rosca de Punho com Halteres", muscleGroup: .forearms, equipment: .dumbbell, focus: "Flexores do antebraço"),
        DefaultExercise(key: "reverse-curl-barbell", id: "B60B986C-37C2-49F0-9047-8F6C93AD6348", name: "Rosca Inversa com Barra W", muscleGroup: .forearms, equipment: .barbell, focus: "Braquiorradial"),

        // MARK: Quadríceps
        DefaultExercise(key: "back-squat", id: "C517F588-CCE9-43C9-A1E9-2DBCFCAF2EB4", name: "Agachamento Livre com Barra", muscleGroup: .quadriceps, equipment: .barbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "front-squat", id: "7C1C3F6C-94B2-48ED-A61D-98186E652811", name: "Agachamento Frontal com Barra", muscleGroup: .quadriceps, equipment: .barbell, focus: "Quadríceps"),
        DefaultExercise(key: "squat-smith", id: "7D3DD7C9-576C-4707-955A-C6A39E3CD371", name: "Agachamento no Smith", muscleGroup: .quadriceps, equipment: .smith, focus: "Quadríceps"),
        DefaultExercise(key: "hack-squat", id: "BB7E8880-925B-4C74-973E-70184E481B73", name: "Agachamento Hack", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps"),
        DefaultExercise(key: "goblet-squat", id: "4BE239F6-9A5D-4ED0-97B3-1D3C32325917", name: "Agachamento Goblet", muscleGroup: .quadriceps, equipment: .kettlebell, focus: "Quadríceps"),
        DefaultExercise(key: "bulgarian-split-squat", id: "2045FEDA-CA84-4BDD-ACAD-D6C73AC04A51", name: "Agachamento Búlgaro com Halteres", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "bodyweight-squat", id: "75F5466E-D1C9-47CE-8A9B-E229C5C82BB4", name: "Agachamento Livre sem Peso", muscleGroup: .quadriceps, equipment: .bodyweight, focus: "Quadríceps"),
        DefaultExercise(key: "leg-press", id: "CE7E1B81-9AB5-4526-8CCD-3BAE65186FA5", name: "Leg Press 45°", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "leg-press-horizontal", id: "7F69E303-32A6-4143-8039-CDF8BF6FF5D2", name: "Leg Press Horizontal", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps"),
        DefaultExercise(key: "leg-extension", id: "C63B1D0E-9341-4FD1-B6F5-6B7BD8A6666E", name: "Cadeira Extensora", muscleGroup: .quadriceps, equipment: .machine, focus: "Quadríceps (isolado)"),
        DefaultExercise(key: "lunge-dumbbell", id: "40D00DD6-61B9-4799-9499-F70F299E2BBB", name: "Afundo com Halteres", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "lunge-smith", id: "D1B06BA4-E46E-4115-A94C-A0FA56D6CFBE", name: "Afundo no Smith", muscleGroup: .quadriceps, equipment: .smith, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "walking-lunge-dumbbell", id: "70B05664-01F6-4ABB-894A-40B97DA68216", name: "Avanço (Passada) com Halteres", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "walking-lunge-barbell", id: "2ECDE858-BBD3-40D1-BC84-49B6418805EB", name: "Avanço (Passada) com Barra", muscleGroup: .quadriceps, equipment: .barbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "step-up-dumbbell", id: "9B8D4982-AD47-4B50-BBAB-57A67F6FEF44", name: "Subida no Banco com Halteres", muscleGroup: .quadriceps, equipment: .dumbbell, focus: "Quadríceps e glúteos"),
        DefaultExercise(key: "sissy-squat", id: "0B8ED39E-E9C9-412D-9617-799F06A6DA6B", name: "Sissy Squat", muscleGroup: .quadriceps, equipment: .bodyweight, focus: "Reto femoral"),

        // MARK: Posteriores de coxa
        DefaultExercise(key: "lying-leg-curl", id: "BA642AA8-6477-47CB-BAD2-EE698617D7CC", name: "Mesa Flexora", muscleGroup: .hamstrings, equipment: .machine, focus: "Posteriores (isolado)"),
        DefaultExercise(key: "seated-leg-curl", id: "6A33CF0A-0FA8-4000-B2E5-760F30BC5813", name: "Cadeira Flexora", muscleGroup: .hamstrings, equipment: .machine, focus: "Posteriores (isolado)"),
        DefaultExercise(key: "standing-leg-curl", id: "3BBE4B67-9413-461C-B92A-2E66F64557B6", name: "Flexora em Pé Unilateral", muscleGroup: .hamstrings, equipment: .machine, focus: "Posteriores (isolado)"),
        DefaultExercise(key: "romanian-deadlift-barbell", id: "070BF992-4700-4C2A-B6B6-DB2E3AA3740E", name: "Stiff com Barra", muscleGroup: .hamstrings, equipment: .barbell, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "romanian-deadlift-dumbbell", id: "FDFB0C36-22A4-476A-A92D-2178DDAD7716", name: "Stiff com Halteres", muscleGroup: .hamstrings, equipment: .dumbbell, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "romanian-deadlift-smith", id: "03AD39F2-834B-462B-B4BA-A21F43A6BDBC", name: "Stiff no Smith", muscleGroup: .hamstrings, equipment: .smith, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "rdl-barbell", id: "66A91C2E-EE56-422C-8018-1B594F0B0670", name: "Levantamento Terra Romeno", muscleGroup: .hamstrings, equipment: .barbell, focus: "Posteriores e glúteos"),
        DefaultExercise(key: "good-morning", id: "A0FEF74E-FA04-419F-A24C-8373963B385B", name: "Good Morning", muscleGroup: .hamstrings, equipment: .barbell, focus: "Posteriores e lombar"),
        DefaultExercise(key: "nordic-curl", id: "B90F4F41-9ACB-4056-B550-E6F00969FC17", name: "Flexão Nórdica", muscleGroup: .hamstrings, equipment: .bodyweight, focus: "Posteriores (fase excêntrica)"),

        // MARK: Glúteos
        DefaultExercise(key: "hip-thrust-barbell", id: "BAA2E068-F397-42D3-B12B-21A9B3527ABC", name: "Elevação Pélvica com Barra", muscleGroup: .glutes, equipment: .barbell, focus: "Glúteo máximo"),
        DefaultExercise(key: "hip-thrust-machine", id: "6325A715-0BCB-4F51-93E9-D55684B56EB2", name: "Elevação Pélvica na Máquina", muscleGroup: .glutes, equipment: .machine, focus: "Glúteo máximo"),
        DefaultExercise(key: "hip-thrust-smith", id: "F8C7BC93-4C73-4834-B963-E595024A5A2B", name: "Elevação Pélvica no Smith", muscleGroup: .glutes, equipment: .smith, focus: "Glúteo máximo"),
        DefaultExercise(key: "glute-bridge", id: "3F432DB8-1C9B-4CB2-BCD9-2CDC72A6567A", name: "Ponte de Glúteo", muscleGroup: .glutes, equipment: .bodyweight, focus: "Glúteo máximo"),
        DefaultExercise(key: "cable-kickback", id: "01888996-9C1A-4661-B8FF-611A30F3A6D2", name: "Glúteo na Polia (Coice)", muscleGroup: .glutes, equipment: .cable, focus: "Glúteo máximo"),
        DefaultExercise(key: "glute-kickback-machine", id: "7B3595F6-AE1C-421F-9D1C-92C77555EBCB", name: "Glúteo na Máquina (Coice)", muscleGroup: .glutes, equipment: .machine, focus: "Glúteo máximo"),
        DefaultExercise(key: "hip-abduction-machine", id: "BE53D4D5-A142-4959-9770-CF7195BD098E", name: "Cadeira Abdutora", muscleGroup: .glutes, equipment: .machine, focus: "Glúteo médio"),
        DefaultExercise(key: "hip-abduction-cable", id: "157631E3-0E6D-4374-A672-472133A847BA", name: "Abdução de Quadril na Polia", muscleGroup: .glutes, equipment: .cable, focus: "Glúteo médio"),
        DefaultExercise(key: "hip-abduction-band", id: "7FAB266A-4F9F-473C-8348-B061032A4E7B", name: "Abdução com Elástico", muscleGroup: .glutes, equipment: .band, focus: "Glúteo médio"),
        DefaultExercise(key: "lateral-band-walk", id: "259F1AD8-9863-4C12-AF74-FD217AAABB9A", name: "Caminhada Lateral com Elástico", muscleGroup: .glutes, equipment: .band, focus: "Glúteo médio"),
        DefaultExercise(key: "sumo-squat-dumbbell", id: "4EE5DACD-EC24-41CA-A98C-AD2E064FB437", name: "Agachamento Sumô com Halter", muscleGroup: .glutes, equipment: .dumbbell, focus: "Glúteos e adutores"),
        DefaultExercise(key: "sumo-deadlift", id: "E8D7AA94-B91B-4232-9334-7DF6BCE89F6E", name: "Levantamento Terra Sumô", muscleGroup: .glutes, equipment: .barbell, focus: "Glúteos, adutores e posteriores"),
        DefaultExercise(key: "hip-adduction-machine", id: "D70D3781-594F-4DD0-A391-A6491B960B06", name: "Cadeira Adutora", muscleGroup: .glutes, equipment: .machine, focus: "Adutores (parte interna da coxa)"),

        // MARK: Panturrilhas
        DefaultExercise(key: "standing-calf-raise", id: "7186818E-02B6-4AA3-88CD-5E3A9D4B243F", name: "Panturrilha em Pé na Máquina", muscleGroup: .calves, equipment: .machine, focus: "Gastrocnêmio"),
        DefaultExercise(key: "seated-calf-raise", id: "E8275D6E-BD2F-4D84-9B61-818997F78B5F", name: "Panturrilha Sentado", muscleGroup: .calves, equipment: .machine, focus: "Sóleo"),
        DefaultExercise(key: "leg-press-calf-raise", id: "23FD5256-DCB6-418D-8429-91F2E47CCF05", name: "Panturrilha no Leg Press", muscleGroup: .calves, equipment: .machine, focus: "Gastrocnêmio"),
        DefaultExercise(key: "calf-raise-smith", id: "5328D6F5-7D10-410C-8D23-D9955E5C652F", name: "Panturrilha no Smith", muscleGroup: .calves, equipment: .smith, focus: "Gastrocnêmio"),
        DefaultExercise(key: "single-leg-calf-raise-dumbbell", id: "0ADB917E-FE38-4460-8905-78A08B37AF41", name: "Panturrilha Unilateral com Halter", muscleGroup: .calves, equipment: .dumbbell, focus: "Gastrocnêmio"),

        // MARK: Abdômen
        DefaultExercise(key: "crunch", id: "A281DFB5-CBE2-4467-B060-483E68E55F64", name: "Abdominal Supra", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte superior)"),
        DefaultExercise(key: "weighted-crunch-plate", id: "9B6A83BD-199F-46C5-9E0C-F9384D1FCB27", name: "Abdominal com Anilha", muscleGroup: .abs, equipment: .plate, focus: "Reto abdominal (parte superior)"),
        DefaultExercise(key: "cable-crunch", id: "557BF24B-D9F8-4DFE-B03C-23B713BE6F92", name: "Abdominal na Polia", muscleGroup: .abs, equipment: .cable, focus: "Reto abdominal"),
        DefaultExercise(key: "crunch-machine", id: "E5B1AE85-EFA8-4B27-879A-E9C22B867ADE", name: "Abdominal na Máquina", muscleGroup: .abs, equipment: .machine, focus: "Reto abdominal"),
        DefaultExercise(key: "reverse-crunch", id: "A4181692-FC6C-4276-BC3D-C538ED8C330D", name: "Abdominal Infra", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte inferior)"),
        DefaultExercise(key: "lying-leg-raise", id: "F1BF928F-6C2E-44F5-AEE0-F37C000E1211", name: "Elevação de Pernas Deitado", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte inferior)"),
        DefaultExercise(key: "hanging-leg-raise", id: "9E16015B-C0AB-4D4A-987D-017E7F6C4626", name: "Elevação de Pernas na Barra Fixa", muscleGroup: .abs, equipment: .bodyweight, focus: "Parte inferior e flexores do quadril"),
        DefaultExercise(key: "captains-chair-knee-raise", id: "0C39A349-EADF-408F-8AEE-44E6849179DB", name: "Elevação de Joelhos na Paralela", muscleGroup: .abs, equipment: .bodyweight, focus: "Reto abdominal (parte inferior)"),
        DefaultExercise(key: "oblique-crunch", id: "79B0FFFD-A439-40CC-BCBE-8C548415D6FB", name: "Abdominal Oblíquo", muscleGroup: .abs, equipment: .bodyweight, focus: "Oblíquos"),
        DefaultExercise(key: "bicycle-crunch", id: "AF0DF957-B16D-47C1-820B-F92E8BE7AFC7", name: "Abdominal Bicicleta", muscleGroup: .abs, equipment: .bodyweight, focus: "Oblíquos"),
        DefaultExercise(key: "russian-twist", id: "D82081B2-5DCC-4F63-AE83-F5BA93D70A9C", name: "Rotação Russa com Anilha", muscleGroup: .abs, equipment: .plate, focus: "Oblíquos"),
        DefaultExercise(key: "cable-woodchop", id: "D185F7C8-060E-4C6D-A08A-6B0E6873DB5C", name: "Lenhador na Polia", muscleGroup: .abs, equipment: .cable, focus: "Oblíquos (rotação)"),
        DefaultExercise(key: "ab-wheel-rollout", id: "2E2A3077-0EA9-4359-AC59-9EFD034500AD", name: "Abdominal com Roda", muscleGroup: .abs, equipment: .bodyweight, focus: "Core (estabilidade)"),
        DefaultExercise(key: "dead-bug", id: "FCC96AF0-F1D0-46A0-AA66-D28CAC9E6251", name: "Dead Bug", muscleGroup: .abs, equipment: .bodyweight, focus: "Core (estabilidade)"),

        // MARK: Corpo inteiro
        DefaultExercise(key: "kettlebell-swing", id: "5768F1BF-317F-4944-92EB-08C9E84BF197", name: "Kettlebell Swing", muscleGroup: .fullBody, equipment: .kettlebell, focus: "Glúteos e posteriores (potência)"),
        DefaultExercise(key: "kettlebell-snatch", id: "ABCAC9B5-A370-4F48-9746-37DAB193BA56", name: "Arranco com Kettlebell", muscleGroup: .fullBody, equipment: .kettlebell, focus: "Corpo inteiro (potência)"),
        DefaultExercise(key: "turkish-get-up", id: "C12663FE-8D07-4244-AE4B-7D76221D3C88", name: "Levantamento Turco", muscleGroup: .fullBody, equipment: .kettlebell, focus: "Estabilidade do corpo inteiro"),
        DefaultExercise(key: "thruster-barbell", id: "D3582270-5FAE-4B7D-99A3-F1DA1BE00431", name: "Thruster com Barra", muscleGroup: .fullBody, equipment: .barbell, focus: "Pernas e ombros"),
        DefaultExercise(key: "thruster-dumbbell", id: "94F098B9-9AF6-4DCA-A9D1-0A96B5B5C1F5", name: "Thruster com Halteres", muscleGroup: .fullBody, equipment: .dumbbell, focus: "Pernas e ombros"),
        DefaultExercise(key: "power-clean", id: "372E8075-4DF9-4DC2-9EE2-4E50CFF9EA1A", name: "Power Clean", muscleGroup: .fullBody, equipment: .barbell, focus: "Corpo inteiro (potência)"),
        DefaultExercise(key: "burpee", id: "E424EF0A-10C4-4C7C-97B4-944763A4884E", name: "Burpee", muscleGroup: .fullBody, equipment: .bodyweight, focus: "Condicionamento"),
    ]

    /// The entries by key, built once: what the library says of a built-in exercise that the store does
    /// not keep (its equipment and focus).
    static let byKey: [String: DefaultExercise] = Dictionary(all.map { ($0.key, $0) }) { first, _ in first }
}
