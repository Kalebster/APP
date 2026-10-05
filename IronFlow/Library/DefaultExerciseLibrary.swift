import Foundation

/// One exercise of the built-in library.
struct DefaultExercise: Equatable, Sendable {
    /// Stable business identity. Never changed, removed or reused.
    let key: String
    /// Fixed UUID, the same on every install. Never changed or reused.
    let id: String
    let name: String
    let muscleGroup: MuscleGroup
}

/// The built-in exercise library, controlled by the app.
///
/// Rules: keys and ids are never changed, removed or reused. Name and muscle group may be
/// corrected in a later version. Entries that leave this list stay in existing stores.
enum DefaultExerciseLibrary {
    static let all: [DefaultExercise] = [
        // MARK: Peito
        DefaultExercise(key: "bench-press-barbell", id: "2A8DF1B0-3059-46E9-8A28-0249DFFF35A3", name: "Supino Reto com Barra", muscleGroup: .chest),
        DefaultExercise(key: "bench-press-dumbbell", id: "8BE65287-7F57-42CE-9FC1-25932355AE5A", name: "Supino Reto com Halteres", muscleGroup: .chest),
        DefaultExercise(key: "incline-bench-press-barbell", id: "EFE20D78-2A00-4EFB-BED3-024357710F23", name: "Supino Inclinado com Barra", muscleGroup: .chest),
        DefaultExercise(key: "incline-bench-press-dumbbell", id: "F207C734-07C0-41E5-8310-AA1611CFB38C", name: "Supino Inclinado com Halteres", muscleGroup: .chest),
        DefaultExercise(key: "decline-bench-press-barbell", id: "5F72F996-41A5-4D32-AEB2-2154411A4566", name: "Supino Declinado com Barra", muscleGroup: .chest),
        DefaultExercise(key: "chest-press-machine", id: "916E8492-AC56-49B2-8459-A029513409C3", name: "Supino na Máquina", muscleGroup: .chest),
        DefaultExercise(key: "fly-dumbbell", id: "EF31C314-C1EB-48CD-9FF8-D3E0A2A16B69", name: "Crucifixo com Halteres", muscleGroup: .chest),
        DefaultExercise(key: "fly-machine", id: "432E6DC6-193A-4B02-8CBA-0AD196069BB7", name: "Crucifixo na Máquina", muscleGroup: .chest),
        DefaultExercise(key: "cable-crossover", id: "EE3EBFB6-1880-439A-83FD-CE25C4026E91", name: "Crossover na Polia", muscleGroup: .chest),

        // MARK: Costas
        DefaultExercise(key: "pull-up", id: "B4C39763-E2C4-4115-86D8-46FDEB6897CD", name: "Barra Fixa", muscleGroup: .back),
        DefaultExercise(key: "lat-pulldown", id: "EF0C3EAD-71E2-427F-8DE1-CB1CAF6B6043", name: "Puxada Frontal", muscleGroup: .back),
        DefaultExercise(key: "bent-over-row-barbell", id: "C4052FD4-1A83-4B58-A863-1C27F9E68B03", name: "Remada Curvada com Barra", muscleGroup: .back),
        DefaultExercise(key: "one-arm-row-dumbbell", id: "6DA533D8-9699-49C1-8BC9-CA31E0DC926E", name: "Remada Unilateral com Halter", muscleGroup: .back),
        DefaultExercise(key: "seated-cable-row", id: "96192D2A-5DD7-4CF0-9A09-7C7476B4BC0E", name: "Remada Baixa na Polia", muscleGroup: .back),
        DefaultExercise(key: "row-machine", id: "F7C34293-0230-4D7E-93F8-A66EDAA878EB", name: "Remada na Máquina", muscleGroup: .back),
        DefaultExercise(key: "straight-arm-pulldown", id: "4EC1E018-0130-4B5E-A989-DF527139405B", name: "Pulldown com Braços Estendidos", muscleGroup: .back),

        // MARK: Ombros
        DefaultExercise(key: "overhead-press-barbell", id: "EBDDA760-71D6-4F7B-A96C-608A69A865D0", name: "Desenvolvimento com Barra", muscleGroup: .shoulders),
        DefaultExercise(key: "shoulder-press-dumbbell", id: "B245B003-04B8-45CC-AE95-1C32B437A8DC", name: "Desenvolvimento com Halteres", muscleGroup: .shoulders),
        DefaultExercise(key: "shoulder-press-machine", id: "76C03A25-36D5-4066-99BA-0854E91AED82", name: "Desenvolvimento na Máquina", muscleGroup: .shoulders),
        DefaultExercise(key: "lateral-raise-dumbbell", id: "EE3F5702-F5F8-473C-BA24-DD46766A8B87", name: "Elevação Lateral com Halteres", muscleGroup: .shoulders),
        DefaultExercise(key: "lateral-raise-cable", id: "F8A98D05-8F42-41B1-85C5-08F15D814940", name: "Elevação Lateral na Polia", muscleGroup: .shoulders),
        DefaultExercise(key: "front-raise-dumbbell", id: "3A1666E9-FAB2-4DE7-BD12-0C0DF6D92697", name: "Elevação Frontal com Halteres", muscleGroup: .shoulders),
        DefaultExercise(key: "reverse-fly-dumbbell", id: "0D0F986B-182E-414E-B879-7E2DF51C1071", name: "Crucifixo Inverso com Halteres", muscleGroup: .shoulders),
        DefaultExercise(key: "face-pull", id: "10B33D70-0CC9-45B9-B2FA-B448603D6F77", name: "Face Pull na Polia", muscleGroup: .shoulders),
        DefaultExercise(key: "shrug-dumbbell", id: "1B22DE68-44A1-4DD4-B93D-4E0AE489E439", name: "Encolhimento com Halteres", muscleGroup: .shoulders),

        // MARK: Bíceps
        DefaultExercise(key: "curl-barbell", id: "5DE24313-22D9-4860-A20E-BC4593835349", name: "Rosca Direta com Barra", muscleGroup: .biceps),
        DefaultExercise(key: "alternating-curl-dumbbell", id: "165B5981-72A7-4405-B4C5-62E9BEEE0A54", name: "Rosca Alternada com Halteres", muscleGroup: .biceps),
        DefaultExercise(key: "hammer-curl-dumbbell", id: "CB64654F-E743-425D-9CF0-564BBCD3F300", name: "Rosca Martelo com Halteres", muscleGroup: .biceps),
        DefaultExercise(key: "preacher-curl", id: "8C7A9E79-6136-4E37-9DB8-E3E51BF794BA", name: "Rosca Scott", muscleGroup: .biceps),
        DefaultExercise(key: "curl-cable", id: "61D5ACA4-FD2B-4F00-BC53-AA2170579306", name: "Rosca na Polia", muscleGroup: .biceps),
        DefaultExercise(key: "concentration-curl", id: "D1A7BD27-C7FC-46A3-95C9-310050E31A6B", name: "Rosca Concentrada", muscleGroup: .biceps),

        // MARK: Tríceps
        DefaultExercise(key: "triceps-pushdown-bar", id: "129B6EDC-93B4-4969-AF26-8D014C4F23B5", name: "Tríceps na Polia com Barra", muscleGroup: .triceps),
        DefaultExercise(key: "triceps-pushdown-rope", id: "EA9F719C-A66E-4F78-9609-C4E5FE07E47C", name: "Tríceps na Polia com Corda", muscleGroup: .triceps),
        DefaultExercise(key: "skull-crusher-barbell", id: "B3BF4DA4-9FA0-4675-8FC8-ABC089E49DBC", name: "Tríceps Testa com Barra", muscleGroup: .triceps),
        DefaultExercise(key: "overhead-extension-dumbbell", id: "CD72E327-6CDA-4091-B035-8B52C888B229", name: "Tríceps Francês com Halter", muscleGroup: .triceps),
        DefaultExercise(key: "close-grip-bench-press", id: "B49164A1-A952-4A3D-9F75-FBAB2E78375B", name: "Supino Fechado", muscleGroup: .triceps),
        DefaultExercise(key: "dips", id: "1CFDD592-1E38-4415-86D8-12553A8465FE", name: "Mergulho em Paralelas", muscleGroup: .triceps),
        DefaultExercise(key: "kickback-dumbbell", id: "8244BCB7-6383-4770-8AE4-E1279D81E50F", name: "Tríceps Coice com Halter", muscleGroup: .triceps),

        // MARK: Antebraços
        DefaultExercise(key: "wrist-curl-barbell", id: "0481D3C9-EAEB-4264-88CA-685EC556BE60", name: "Rosca de Punho com Barra", muscleGroup: .forearms),
        DefaultExercise(key: "reverse-wrist-curl-barbell", id: "8470E422-59F5-4AC9-B0F3-8B09BA00C334", name: "Rosca de Punho Invertida", muscleGroup: .forearms),
        DefaultExercise(key: "reverse-curl-barbell", id: "B60B986C-37C2-49F0-9047-8F6C93AD6348", name: "Rosca Inversa com Barra", muscleGroup: .forearms),

        // MARK: Quadríceps
        DefaultExercise(key: "back-squat", id: "C517F588-CCE9-43C9-A1E9-2DBCFCAF2EB4", name: "Agachamento Livre com Barra", muscleGroup: .quadriceps),
        DefaultExercise(key: "front-squat", id: "7C1C3F6C-94B2-48ED-A61D-98186E652811", name: "Agachamento Frontal com Barra", muscleGroup: .quadriceps),
        DefaultExercise(key: "goblet-squat", id: "4BE239F6-9A5D-4ED0-97B3-1D3C32325917", name: "Agachamento Goblet", muscleGroup: .quadriceps),
        DefaultExercise(key: "hack-squat", id: "BB7E8880-925B-4C74-973E-70184E481B73", name: "Agachamento Hack", muscleGroup: .quadriceps),
        DefaultExercise(key: "leg-press", id: "CE7E1B81-9AB5-4526-8CCD-3BAE65186FA5", name: "Leg Press 45°", muscleGroup: .quadriceps),
        DefaultExercise(key: "leg-extension", id: "C63B1D0E-9341-4FD1-B6F5-6B7BD8A6666E", name: "Cadeira Extensora", muscleGroup: .quadriceps),
        DefaultExercise(key: "lunge-dumbbell", id: "40D00DD6-61B9-4799-9499-F70F299E2BBB", name: "Afundo com Halteres", muscleGroup: .quadriceps),
        DefaultExercise(key: "bulgarian-split-squat", id: "2045FEDA-CA84-4BDD-ACAD-D6C73AC04A51", name: "Agachamento Búlgaro", muscleGroup: .quadriceps),

        // MARK: Posteriores de coxa
        DefaultExercise(key: "deadlift", id: "CC2B68C8-727F-49C9-AFDC-8B338BE8C692", name: "Levantamento Terra", muscleGroup: .hamstrings),
        DefaultExercise(key: "romanian-deadlift-barbell", id: "070BF992-4700-4C2A-B6B6-DB2E3AA3740E", name: "Stiff com Barra", muscleGroup: .hamstrings),
        DefaultExercise(key: "romanian-deadlift-dumbbell", id: "FDFB0C36-22A4-476A-A92D-2178DDAD7716", name: "Stiff com Halteres", muscleGroup: .hamstrings),
        DefaultExercise(key: "lying-leg-curl", id: "BA642AA8-6477-47CB-BAD2-EE698617D7CC", name: "Mesa Flexora", muscleGroup: .hamstrings),
        DefaultExercise(key: "seated-leg-curl", id: "6A33CF0A-0FA8-4000-B2E5-760F30BC5813", name: "Cadeira Flexora", muscleGroup: .hamstrings),
        DefaultExercise(key: "good-morning", id: "A0FEF74E-FA04-419F-A24C-8373963B385B", name: "Bom Dia com Barra", muscleGroup: .hamstrings),

        // MARK: Glúteos
        DefaultExercise(key: "hip-thrust-barbell", id: "BAA2E068-F397-42D3-B12B-21A9B3527ABC", name: "Elevação Pélvica com Barra", muscleGroup: .glutes),
        DefaultExercise(key: "glute-bridge", id: "3F432DB8-1C9B-4CB2-BCD9-2CDC72A6567A", name: "Ponte de Glúteo", muscleGroup: .glutes),
        DefaultExercise(key: "hip-abduction-machine", id: "BE53D4D5-A142-4959-9770-CF7195BD098E", name: "Abdução de Quadril na Máquina", muscleGroup: .glutes),
        DefaultExercise(key: "cable-kickback", id: "01888996-9C1A-4661-B8FF-611A30F3A6D2", name: "Coice na Polia", muscleGroup: .glutes),

        // MARK: Panturrilhas
        DefaultExercise(key: "standing-calf-raise", id: "7186818E-02B6-4AA3-88CD-5E3A9D4B243F", name: "Panturrilha em Pé na Máquina", muscleGroup: .calves),
        DefaultExercise(key: "seated-calf-raise", id: "E8275D6E-BD2F-4D84-9B61-818997F78B5F", name: "Panturrilha Sentado", muscleGroup: .calves),
        DefaultExercise(key: "leg-press-calf-raise", id: "23FD5256-DCB6-418D-8429-91F2E47CCF05", name: "Panturrilha no Leg Press", muscleGroup: .calves),

        // MARK: Abdômen
        DefaultExercise(key: "crunch", id: "A281DFB5-CBE2-4467-B060-483E68E55F64", name: "Abdominal Supra", muscleGroup: .abs),
        DefaultExercise(key: "cable-crunch", id: "557BF24B-D9F8-4DFE-B03C-23B713BE6F92", name: "Abdominal na Polia", muscleGroup: .abs),
        DefaultExercise(key: "hanging-leg-raise", id: "9E16015B-C0AB-4D4A-987D-017E7F6C4626", name: "Elevação de Pernas na Barra", muscleGroup: .abs),
        DefaultExercise(key: "lying-leg-raise", id: "F1BF928F-6C2E-44F5-AEE0-F37C000E1211", name: "Elevação de Pernas Deitado", muscleGroup: .abs),
        DefaultExercise(key: "russian-twist", id: "D82081B2-5DCC-4F63-AE83-F5BA93D70A9C", name: "Abdominal Oblíquo com Rotação", muscleGroup: .abs),
        DefaultExercise(key: "ab-wheel-rollout", id: "2E2A3077-0EA9-4359-AC59-9EFD034500AD", name: "Abdominal com Roda", muscleGroup: .abs),

        // MARK: Corpo inteiro
        DefaultExercise(key: "kettlebell-swing", id: "5768F1BF-317F-4944-92EB-08C9E84BF197", name: "Kettlebell Swing", muscleGroup: .fullBody),
        DefaultExercise(key: "burpee", id: "E424EF0A-10C4-4C7C-97B4-944763A4884E", name: "Burpee", muscleGroup: .fullBody),

        // MARK: Outro
        DefaultExercise(key: "hip-adduction-machine", id: "D70D3781-594F-4DD0-A391-A6491B960B06", name: "Cadeira Adutora", muscleGroup: .other),
    ]
}
