import Foundation

/// An exercise of the library of 420 that left the approved base list (26/11/2026), with what it had
/// then: kept only to migrate the stores that have it (`ExerciseLibrarySeeder`). Whoever used it (in the
/// history, a planned workout or the session in progress) keeps it as an exercise of their own, in "Meus",
/// with this name, group, equipment, muscles and kind of machine; an unused one is deleted.
struct RetiredExercise: Equatable, Sendable {
    let key: String
    let id: String
    let name: String
    let muscleGroup: MuscleGroup
    let equipment: Equipment
    let primary: [Muscle]
    let secondary: [Muscle]
    /// Only for an exercise done on a machine.
    var machine: MachineType?
}

/// The 105 exercises that left the library, and the 4 junctions: two exercises of the library of 420 that
/// became one combination, whose histories go together. Library data only, never stored.
///
/// Rule: a retired key never comes back to `DefaultExerciseLibrary` without leaving this list in the same
/// version (checked by the tests), so a store's exercise is never both migrated and kept.
enum RetiredExercises {
    static let all: [RetiredExercise] = [
        RetiredExercise(key: "sit-up", id: "EFCADE80-10A1-46A7-9F97-5FCADEF2372A", name: "Abdominal Completo", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.obliques]),
        RetiredExercise(key: "rowing-crunch", id: "5019E787-079A-4121-A035-C92F0FD306F9", name: "Abdominal Remador", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.obliques]),
        RetiredExercise(key: "scissor-kick", id: "0E1ED61D-280E-4AB5-A6A2-C5836607DB52", name: "Abdominal Tesoura", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.obliques]),
        RetiredExercise(key: "heel-touch", id: "CB89A2D8-B9D8-4841-A57E-4EF671491641", name: "Abdominal Toque no Calcanhar", muscleGroup: .abs, equipment: .bodyweight, primary: [.obliques], secondary: [.abs]),
        RetiredExercise(key: "stability-ball-crunch", id: "7235E620-0306-4AE9-ABD6-8C54C3BCF724", name: "Abdominal na Bola Suíça", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.obliques]),
        RetiredExercise(key: "side-lying-hip-abduction", id: "BFE45AFC-D496-4151-B647-6955361D2CBB", name: "Abdução Lateral Deitado", muscleGroup: .glutes, equipment: .bodyweight, primary: [.gluteusMedius], secondary: [.glutes]),
        RetiredExercise(key: "clamshell-band", id: "E015BF7B-89CC-4656-8716-B3921838418A", name: "Abdução Ostra (Elástico)", muscleGroup: .glutes, equipment: .band, primary: [.gluteusMedius], secondary: [.glutes]),
        RetiredExercise(key: "side-lying-hip-adduction", id: "F67FE5B5-F38F-4BED-9E52-5337B0F684E7", name: "Adução Lateral Deitado", muscleGroup: .adductors, equipment: .bodyweight, primary: [.adductors], secondary: []),
        RetiredExercise(key: "curtsy-lunge-dumbbell", id: "D87FC72F-FCFF-4274-9B5E-D31D70C10CAD", name: "Afundo Cruzado (Halter)", muscleGroup: .glutes, equipment: .dumbbell, primary: [.gluteusMedius, .glutes], secondary: [.quadriceps]),
        RetiredExercise(key: "lateral-lunge-dumbbell", id: "BF0AF26F-0614-4F6E-99D3-A92093550C3B", name: "Afundo Lateral (Halter)", muscleGroup: .quadriceps, equipment: .dumbbell, primary: [.quadriceps, .adductors], secondary: [.glutes]),
        RetiredExercise(key: "reverse-lunge-barbell", id: "D2018202-A7A1-4AF6-8056-8191AC650F1A", name: "Afundo Reverso (Barra)", muscleGroup: .quadriceps, equipment: .barbell, primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]),
        RetiredExercise(key: "reverse-lunge-dumbbell", id: "96277DF1-0C3E-455C-9E45-11B5BCC81C5A", name: "Afundo Reverso (Halter)", muscleGroup: .quadriceps, equipment: .dumbbell, primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]),
        RetiredExercise(key: "reverse-lunge-smith", id: "102C6327-0092-4B24-BB34-B3C742EB2758", name: "Afundo Reverso (Smith)", muscleGroup: .quadriceps, equipment: .smith, primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]),
        RetiredExercise(key: "cossack-squat", id: "FE459584-48DF-4BF1-96A0-5B27F44FDEED", name: "Agachamento Cossaco", muscleGroup: .quadriceps, equipment: .bodyweight, primary: [.quadriceps, .adductors], secondary: [.glutes]),
        RetiredExercise(key: "overhead-squat", id: "D8C49719-BD95-4EC3-827D-CCE279F4A327", name: "Agachamento Overhead (Barra)", muscleGroup: .quadriceps, equipment: .barbell, primary: [.quadriceps], secondary: [.glutes, .frontDelts, .abs]),
        RetiredExercise(key: "pistol-squat", id: "84CBD686-1D00-41D0-93DE-258F610B5513", name: "Agachamento Pistol", muscleGroup: .quadriceps, equipment: .bodyweight, primary: [.quadriceps], secondary: [.glutes, .adductors]),
        RetiredExercise(key: "v-squat-machine", id: "E1D2DB9C-33B2-476A-A7D6-B3E5DD0554F2", name: "Agachamento V-Squat (Máquina)", muscleGroup: .quadriceps, equipment: .machine, primary: [.quadriceps], secondary: [.glutes, .adductors], machine: .lever),
        RetiredExercise(key: "zercher-squat", id: "C85FE94A-01E6-4009-A4AB-F529294744B5", name: "Agachamento Zercher (Barra)", muscleGroup: .quadriceps, equipment: .barbell, primary: [.quadriceps], secondary: [.glutes, .abs]),
        RetiredExercise(key: "belt-squat-machine", id: "5301E290-9EFC-4464-8FC0-BC2733872D08", name: "Agachamento com Cinto (Máquina)", muscleGroup: .quadriceps, equipment: .machine, primary: [.quadriceps, .glutes], secondary: [.adductors, .hamstrings], machine: .lever),
        RetiredExercise(key: "jump-squat", id: "1CBA35C0-6C3E-467D-A4B5-D2CA694FB829", name: "Agachamento com Salto", muscleGroup: .quadriceps, equipment: .bodyweight, primary: [.quadriceps], secondary: [.glutes, .calves]),
        RetiredExercise(key: "box-squat", id: "3F9F16F0-A0E1-4E23-8FB2-0DE73F919D7E", name: "Agachamento no Banco (Barra)", muscleGroup: .quadriceps, equipment: .barbell, primary: [.quadriceps, .glutes], secondary: [.adductors, .hamstrings]),
        RetiredExercise(key: "clean-and-jerk", id: "2055A6E7-3AB8-49A4-B20B-0D19FD953A93", name: "Arremesso (Barra)", muscleGroup: .fullBody, equipment: .barbell, primary: [.glutes, .quadriceps, .frontDelts], secondary: [.hamstrings, .traps, .triceps]),
        RetiredExercise(key: "bird-dog", id: "356570FF-2054-437E-8CD8-9CA7519AEDF7", name: "Bird Dog", muscleGroup: .lowerBack, equipment: .bodyweight, primary: [.lowerBack], secondary: [.glutes, .abs]),
        RetiredExercise(key: "lateral-band-walk", id: "259F1AD8-9863-4C12-AF74-FD217AAABB9A", name: "Caminhada Lateral (Elástico)", muscleGroup: .glutes, equipment: .band, primary: [.gluteusMedius], secondary: [.glutes]),
        RetiredExercise(key: "kettlebell-clean", id: "E99672D6-F4F3-40B1-B0A1-00BAB937F3FB", name: "Clean (Kettlebell)", muscleGroup: .fullBody, equipment: .kettlebell, primary: [.glutes, .hamstrings, .quadriceps], secondary: [.traps, .lowerBack, .calves]),
        RetiredExercise(key: "single-arm-cable-crossover", id: "59C29ADB-6DFB-436C-8155-E516DF366841", name: "Crossover Unilateral (Polia)", muscleGroup: .chest, equipment: .cable, primary: [.chest], secondary: [.frontDelts]),
        RetiredExercise(key: "decline-fly-dumbbell", id: "8D79EF76-2A10-4A45-8273-5D251459D02E", name: "Crucifixo Declinado (Halter)", muscleGroup: .chest, equipment: .dumbbell, primary: [.chest], secondary: [.frontDelts]),
        RetiredExercise(key: "incline-reverse-fly-dumbbell", id: "8E5C22FD-761C-463D-A953-2109836049E6", name: "Crucifixo Invertido Inclinado (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, primary: [.rearDelts], secondary: [.upperBack, .traps]),
        RetiredExercise(key: "single-arm-reverse-fly-cable", id: "1766A0C1-60BF-46D0-AB1B-84CA4D4B8230", name: "Crucifixo Invertido Unilateral (Polia)", muscleGroup: .shoulders, equipment: .cable, primary: [.rearDelts], secondary: [.upperBack, .traps]),
        RetiredExercise(key: "dead-bug", id: "FCC96AF0-F1D0-46A0-AA66-D28CAC9E6251", name: "Dead Bug", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.obliques]),
        RetiredExercise(key: "behind-the-neck-press-barbell", id: "4903E1DC-3240-4681-B2C4-ABB810679924", name: "Desenvolvimento Atrás da Nuca (Barra)", muscleGroup: .shoulders, equipment: .barbell, primary: [.frontDelts, .sideDelts], secondary: [.triceps, .traps]),
        RetiredExercise(key: "behind-the-neck-press-smith", id: "D8E15EEB-E4EB-49AB-8542-364AF95A01E0", name: "Desenvolvimento Atrás da Nuca (Smith)", muscleGroup: .shoulders, equipment: .smith, primary: [.frontDelts, .sideDelts], secondary: [.triceps, .traps]),
        RetiredExercise(key: "landmine-shoulder-press", id: "03FA10BD-B78E-4D5C-9F9D-E998E9665189", name: "Desenvolvimento Landmine (Barra)", muscleGroup: .shoulders, equipment: .barbell, primary: [.frontDelts], secondary: [.chest, .triceps]),
        RetiredExercise(key: "neutral-grip-shoulder-press-dumbbell", id: "39529995-8B14-4797-9F12-2E4F6275AB63", name: "Desenvolvimento Pegada Neutra (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, primary: [.frontDelts], secondary: [.sideDelts, .triceps]),
        RetiredExercise(key: "single-arm-shoulder-press-dumbbell", id: "1D51D4BB-A75D-4F37-A730-0AE15D474277", name: "Desenvolvimento Unilateral (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, primary: [.frontDelts], secondary: [.sideDelts, .triceps, .obliques]),
        RetiredExercise(key: "single-arm-shoulder-press-machine", id: "75D815BB-566F-469D-9A94-CD111E7553EE", name: "Desenvolvimento Unilateral (Máquina)", muscleGroup: .shoulders, equipment: .machine, primary: [.frontDelts], secondary: [.sideDelts, .triceps], machine: .plates),
        RetiredExercise(key: "dragon-flag", id: "AFD2254B-F118-410F-81E9-CC52C30623F5", name: "Dragon Flag", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.obliques]),
        RetiredExercise(key: "alternating-front-raise-dumbbell", id: "733EEEE6-E24E-44A5-B7B3-C2857E6BB675", name: "Elevação Frontal Alternada (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, primary: [.frontDelts], secondary: [.sideDelts]),
        RetiredExercise(key: "single-arm-front-raise-cable", id: "4B16AD3B-F198-497C-B0F8-F7D7F51E3DC2", name: "Elevação Frontal Unilateral (Polia)", muscleGroup: .shoulders, equipment: .cable, primary: [.frontDelts], secondary: [.sideDelts]),
        RetiredExercise(key: "seated-lateral-raise-dumbbell", id: "C7883059-A317-41AE-8CF6-16C9E6B61181", name: "Elevação Lateral Sentado (Halter)", muscleGroup: .shoulders, equipment: .dumbbell, primary: [.sideDelts], secondary: [.traps]),
        RetiredExercise(key: "decline-leg-raise", id: "91EAB8B9-671A-4BF3-A931-636F638DC7C1", name: "Elevação de Pernas no Banco Declinado", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.obliques]),
        RetiredExercise(key: "behind-the-back-shrug", id: "4AA4E858-9101-48E6-ACEC-855958B7EA97", name: "Encolhimento Atrás do Corpo (Barra)", muscleGroup: .traps, equipment: .barbell, primary: [.traps], secondary: [.forearms]),
        RetiredExercise(key: "incline-shrug-dumbbell", id: "B34B36C5-4E70-443F-BFC1-15A416ECD6F1", name: "Encolhimento Inclinado (Halter)", muscleGroup: .traps, equipment: .dumbbell, primary: [.traps], secondary: [.upperBack]),
        RetiredExercise(key: "mountain-climber", id: "70ABB43F-4F7F-42CC-A629-EFDC179C664B", name: "Escalador", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.quadriceps, .frontDelts]),
        RetiredExercise(key: "kneeling-leg-curl", id: "B9B2FBA4-E1A0-4D1A-9F20-E4EF0725D5CC", name: "Flexora Ajoelhada (Máquina)", muscleGroup: .hamstrings, equipment: .machine, primary: [.hamstrings], secondary: [.calves], machine: .plates),
        RetiredExercise(key: "stability-ball-leg-curl", id: "FEF97402-8059-441B-AED7-455D8AD3ADD2", name: "Flexora na Bola Suíça", muscleGroup: .hamstrings, equipment: .bodyweight, primary: [.hamstrings], secondary: [.glutes]),
        RetiredExercise(key: "wide-push-up", id: "9A5F728D-0ED4-439F-9D92-4814B21AF25B", name: "Flexão Aberta", muscleGroup: .chest, equipment: .bodyweight, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "archer-push-up", id: "E134E58A-96DA-443C-A6B1-619B2C70FFD0", name: "Flexão Arqueiro", muscleGroup: .chest, equipment: .bodyweight, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "plyometric-push-up", id: "72C496DF-1E4F-483E-9230-CFB24BA20CB8", name: "Flexão Explosiva", muscleGroup: .chest, equipment: .bodyweight, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "close-grip-push-up", id: "593637DD-8037-4208-92D7-901C3F8E31B1", name: "Flexão Fechada", muscleGroup: .triceps, equipment: .bodyweight, primary: [.triceps], secondary: [.chest, .frontDelts]),
        RetiredExercise(key: "handstand-push-up", id: "ECD22BC8-899E-4F11-BF30-B1A82183FABD", name: "Flexão em Parada de Mão", muscleGroup: .shoulders, equipment: .bodyweight, primary: [.frontDelts, .triceps], secondary: [.sideDelts, .traps]),
        RetiredExercise(key: "glute-ham-raise", id: "08837A9C-2DF3-495D-AB44-155FFFD90B28", name: "Glute Ham Raise (Máquina)", muscleGroup: .hamstrings, equipment: .machine, primary: [.hamstrings, .glutes], secondary: [.lowerBack, .calves], machine: .ghd),
        RetiredExercise(key: "fire-hydrant", id: "D99D8F2C-FA96-41C1-9845-81A322661440", name: "Hidrante", muscleGroup: .glutes, equipment: .bodyweight, primary: [.gluteusMedius], secondary: [.glutes]),
        RetiredExercise(key: "reverse-hyperextension", id: "CD2244B9-52D7-4869-A222-CC224626F9DB", name: "Hiperextensão Reversa (Máquina)", muscleGroup: .glutes, equipment: .machine, primary: [.glutes], secondary: [.lowerBack, .hamstrings], machine: .lever),
        RetiredExercise(key: "single-arm-kettlebell-swing", id: "1C46EB31-03EC-48F0-A776-C36324F3E1AB", name: "Kettlebell Swing Unilateral", muscleGroup: .fullBody, equipment: .kettlebell, primary: [.glutes, .hamstrings], secondary: [.lowerBack, .abs]),
        RetiredExercise(key: "reverse-cable-woodchop", id: "3E7F8F85-2F5E-4AF7-AC95-4E1730617011", name: "Lenhador Invertido (Polia)", muscleGroup: .abs, equipment: .cable, primary: [.obliques], secondary: [.abs]),
        RetiredExercise(key: "deficit-deadlift", id: "50DB2074-1BC2-4EDE-9B79-A87BAB17A087", name: "Levantamento Terra Déficit (Barra)", muscleGroup: .lowerBack, equipment: .barbell, primary: [.lowerBack, .glutes, .hamstrings], secondary: [.quadriceps, .traps, .forearms]),
        RetiredExercise(key: "turkish-get-up", id: "C12663FE-8D07-4244-AE4B-7D76221D3C88", name: "Levantamento Turco (Kettlebell)", muscleGroup: .fullBody, equipment: .kettlebell, primary: [.abs, .frontDelts], secondary: [.obliques, .glutes, .triceps]),
        RetiredExercise(key: "windshield-wiper", id: "91F005A1-74A6-4D41-9F33-15263216983C", name: "Limpador de Para-brisa", muscleGroup: .abs, equipment: .bodyweight, primary: [.obliques], secondary: [.abs]),
        RetiredExercise(key: "pallof-press", id: "9AC40950-6C31-4C03-90CF-502B61E73258", name: "Pallof Press (Polia)", muscleGroup: .abs, equipment: .cable, primary: [.obliques], secondary: [.abs]),
        RetiredExercise(key: "donkey-calf-raise", id: "6F8FF0BA-9879-4BC0-BA39-E98D72C08459", name: "Panturrilha Burrico (Máquina)", muscleGroup: .calves, equipment: .machine, primary: [.calves], secondary: [], machine: .lever),
        RetiredExercise(key: "hack-squat-calf-raise", id: "E5C908E8-18AB-489E-B4FE-8EC6244A1AFF", name: "Panturrilha no Hack (Máquina)", muscleGroup: .calves, equipment: .machine, primary: [.calves], secondary: [], machine: .track),
        RetiredExercise(key: "cable-pull-through", id: "D9395DE5-8675-404A-81D5-40DBAE5967B7", name: "Pull Through (Polia)", muscleGroup: .glutes, equipment: .cable, primary: [.glutes], secondary: [.hamstrings]),
        RetiredExercise(key: "single-arm-pullover-cable", id: "C1281954-00A3-4031-BBAC-663510BB5C4D", name: "Pullover Unilateral (Polia)", muscleGroup: .back, equipment: .cable, primary: [.lats], secondary: [.triceps, .rearDelts]),
        RetiredExercise(key: "push-press", id: "072A69DE-7EFD-4FE3-9A55-C884F69AC9DD", name: "Push Press (Barra)", muscleGroup: .shoulders, equipment: .barbell, primary: [.frontDelts], secondary: [.triceps, .sideDelts, .quadriceps, .glutes]),
        RetiredExercise(key: "behind-the-neck-lat-pulldown", id: "28E9476D-39AE-4B15-B126-AACF71B9A846", name: "Puxada Atrás da Nuca (Polia)", muscleGroup: .back, equipment: .cable, primary: [.lats], secondary: [.upperBack, .biceps]),
        RetiredExercise(key: "toes-to-bar", id: "79439BA9-44D5-402A-8336-171E9C83EA2D", name: "Pés na Barra", muscleGroup: .abs, equipment: .bodyweight, primary: [.abs], secondary: [.obliques, .forearms]),
        RetiredExercise(key: "seal-row-barbell", id: "5F097598-C4A7-4A1C-A523-CCD7B3724059", name: "Remada Apoiada no Banco (Barra)", muscleGroup: .upperBack, equipment: .barbell, primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps]),
        RetiredExercise(key: "gorilla-row", id: "9882958F-199B-4A7B-802A-53A9511AED9E", name: "Remada Gorila (Kettlebell)", muscleGroup: .upperBack, equipment: .kettlebell, primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps, .lowerBack]),
        RetiredExercise(key: "kroc-row", id: "57CDE3AC-3F16-4054-A2FA-1A51232D29AE", name: "Remada Kroc (Halter)", muscleGroup: .back, equipment: .dumbbell, primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]),
        RetiredExercise(key: "meadows-row", id: "5570942F-4458-4F66-8135-7881442BB7DF", name: "Remada Meadows (Barra)", muscleGroup: .back, equipment: .barbell, primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]),
        RetiredExercise(key: "renegade-row", id: "5C029D5A-E7BE-4FD6-8530-ACB4F0846555", name: "Remada Renegada (Halter)", muscleGroup: .upperBack, equipment: .dumbbell, primary: [.upperBack], secondary: [.lats, .abs, .biceps]),
        RetiredExercise(key: "scapular-pull-up", id: "9408ED0C-A25C-4FA4-9C3B-1682467C57C4", name: "Retração Escapular na Barra Fixa", muscleGroup: .upperBack, equipment: .bodyweight, primary: [.upperBack, .traps], secondary: [.lats]),
        RetiredExercise(key: "high-cable-curl", id: "CB6661BE-6028-4DCD-A828-D4175CF49196", name: "Rosca Alta (Polia)", muscleGroup: .biceps, equipment: .cable, primary: [.biceps], secondary: [.forearms]),
        RetiredExercise(key: "drag-curl-barbell", id: "2284CB51-6D80-490B-80FB-2F67B804558D", name: "Rosca Arrastada (Barra)", muscleGroup: .biceps, equipment: .barbell, primary: [.biceps], secondary: [.forearms]),
        RetiredExercise(key: "close-grip-curl-ez-bar", id: "F516869D-6226-434A-91C6-C684AD3B8D15", name: "Rosca Direta Pegada Fechada (Barra W)", muscleGroup: .biceps, equipment: .barbell, primary: [.biceps], secondary: [.forearms]),
        RetiredExercise(key: "alternating-hammer-curl-dumbbell", id: "BC357B72-4721-483F-9EE7-E76E7A16BABE", name: "Rosca Martelo Alternada (Halter)", muscleGroup: .biceps, equipment: .dumbbell, primary: [.biceps, .forearms], secondary: []),
        RetiredExercise(key: "cross-body-hammer-curl", id: "220DFE5B-DF34-49B4-944A-9E11BFCE27AC", name: "Rosca Martelo Cruzada (Halter)", muscleGroup: .biceps, equipment: .dumbbell, primary: [.biceps], secondary: [.forearms]),
        RetiredExercise(key: "zottman-curl", id: "10694303-1E8E-41C8-BC7C-526D9FF00E33", name: "Rosca Zottman (Halter)", muscleGroup: .biceps, equipment: .dumbbell, primary: [.biceps, .forearms], secondary: []),
        RetiredExercise(key: "behind-the-back-wrist-curl", id: "E27AADEC-08B4-4DDA-8AC0-D55D25D6BD0B", name: "Rosca de Punho Atrás do Corpo (Barra)", muscleGroup: .forearms, equipment: .barbell, primary: [.forearms], secondary: []),
        RetiredExercise(key: "internal-rotation-cable", id: "97F8BB8E-D813-4467-A0F9-BEDDA981BDA0", name: "Rotação Interna (Polia)", muscleGroup: .shoulders, equipment: .cable, primary: [.rotatorCuff], secondary: [.frontDelts]),
        RetiredExercise(key: "wrist-rotation-dumbbell", id: "C589F864-C491-45BB-933A-ADF0DAC0CE78", name: "Rotação de Punho (Halter)", muscleGroup: .forearms, equipment: .dumbbell, primary: [.forearms], secondary: []),
        RetiredExercise(key: "torso-rotation-machine", id: "9B3811FC-12B3-4ECD-9487-401972309CE5", name: "Rotação de Tronco (Máquina)", muscleGroup: .abs, equipment: .machine, primary: [.obliques], secondary: [.abs], machine: .plates),
        RetiredExercise(key: "sissy-squat", id: "0B8ED39E-E9C9-412D-9617-799F06A6DA6B", name: "Sissy Squat", muscleGroup: .quadriceps, equipment: .bodyweight, primary: [.quadriceps], secondary: []),
        RetiredExercise(key: "guillotine-press-barbell", id: "C4AC98AD-0733-4E62-92D4-AB3E70634E05", name: "Supino Guilhotina (Barra)", muscleGroup: .chest, equipment: .barbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "neutral-grip-incline-bench-press-dumbbell", id: "5D9899F9-DC43-4513-9C8F-6D2D3AC2F3D2", name: "Supino Inclinado Pegada Neutra (Halter)", muscleGroup: .chest, equipment: .dumbbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "single-arm-incline-bench-press-dumbbell", id: "5132CC95-543E-42AD-9D4F-1487F01218C5", name: "Supino Inclinado Unilateral (Halter)", muscleGroup: .chest, equipment: .dumbbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "single-arm-incline-chest-press-machine", id: "1453A24D-8C25-46F5-A59B-047091E0D426", name: "Supino Inclinado Unilateral (Máquina)", muscleGroup: .chest, equipment: .machine, primary: [.chest], secondary: [.triceps, .frontDelts], machine: .plates),
        RetiredExercise(key: "single-arm-incline-bench-press-cable", id: "53FE34F8-AB73-4E29-B632-539035CA506C", name: "Supino Inclinado Unilateral (Polia)", muscleGroup: .chest, equipment: .cable, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "landmine-chest-press", id: "896B0866-605B-4B73-966C-758527F8FACF", name: "Supino Landmine (Barra)", muscleGroup: .chest, equipment: .barbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "wide-grip-bench-press-barbell", id: "93BF9A4C-D4B1-444C-88F4-CC2E367C43A2", name: "Supino Reto Pegada Aberta (Barra)", muscleGroup: .chest, equipment: .barbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "neutral-grip-bench-press-dumbbell", id: "51F31EB6-9804-4CD8-BB47-E419CEBA8988", name: "Supino Reto Pegada Neutra (Halter)", muscleGroup: .chest, equipment: .dumbbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "single-arm-bench-press-dumbbell", id: "37972895-1F79-4E2D-B408-17BD39B782D2", name: "Supino Reto Unilateral (Halter)", muscleGroup: .chest, equipment: .dumbbell, primary: [.chest], secondary: [.triceps, .frontDelts, .obliques]),
        RetiredExercise(key: "single-arm-chest-press-machine", id: "57CFDC55-F452-4164-838C-A239DD242468", name: "Supino Reto Unilateral (Máquina)", muscleGroup: .chest, equipment: .machine, primary: [.chest], secondary: [.triceps, .frontDelts], machine: .plates),
        RetiredExercise(key: "single-arm-bench-press-cable", id: "3720757B-F8EF-4191-9AB1-A893128861FC", name: "Supino Reto Unilateral (Polia)", muscleGroup: .chest, equipment: .cable, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "squeeze-press-dumbbell", id: "149BACA9-4D85-48A5-9F3E-D9A092AE91C1", name: "Supino Squeeze (Halter)", muscleGroup: .chest, equipment: .dumbbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "floor-press-barbell", id: "D5CC21C9-E89D-4EE5-88B0-FFBF39DE7046", name: "Supino no Chão (Barra)", muscleGroup: .chest, equipment: .barbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "floor-press-dumbbell", id: "F67A1090-8E67-4F1C-B0E5-B4E1EAC18008", name: "Supino no Chão (Halter)", muscleGroup: .chest, equipment: .dumbbell, primary: [.chest], secondary: [.triceps, .frontDelts]),
        RetiredExercise(key: "svend-press", id: "8E5B0429-5056-40F6-8D89-452DDEB220F9", name: "Svend Press (Anilha)", muscleGroup: .chest, equipment: .plate, primary: [.chest], secondary: [.frontDelts]),
        RetiredExercise(key: "tate-press", id: "8345ADAD-FC96-46AA-B687-2BA765ACC8AF", name: "Tate Press (Halter)", muscleGroup: .triceps, equipment: .dumbbell, primary: [.triceps], secondary: []),
        RetiredExercise(key: "triceps-pushdown-band", id: "F588831B-3944-4CA9-8F60-806DAABC44E3", name: "Tríceps (Elástico)", muscleGroup: .triceps, equipment: .band, primary: [.triceps], secondary: []),
        RetiredExercise(key: "cross-body-triceps-extension-cable", id: "EF2EC54C-BA82-4CBE-9B8A-DDDC12EC57E9", name: "Tríceps Cruzado (Polia)", muscleGroup: .triceps, equipment: .cable, primary: [.triceps], secondary: []),
        RetiredExercise(key: "incline-skull-crusher-ez-bar", id: "238ABAA2-6174-4BDD-8AFC-CF04BDE9BF0F", name: "Tríceps Testa Inclinado (Barra W)", muscleGroup: .triceps, equipment: .barbell, primary: [.triceps], secondary: []),
        RetiredExercise(key: "single-arm-skull-crusher-dumbbell", id: "DE773437-FBDD-4FBB-85E4-A100235A991B", name: "Tríceps Testa Unilateral (Halter)", muscleGroup: .triceps, equipment: .dumbbell, primary: [.triceps], secondary: []),
        RetiredExercise(key: "single-arm-reverse-grip-pushdown", id: "0EFDC351-6501-41D3-BCC3-8438D6B2CC61", name: "Tríceps Unilateral Invertido (Polia)", muscleGroup: .triceps, equipment: .cable, primary: [.triceps], secondary: []),
    ]

    /// The junctions: the exercise that stays (its key and id are the combination's) and the one merged into
    /// it, whose history, planned workouts and session in progress go to the one that stays.
    static let junctions: [(kept: String, merged: String)] = [
        (kept: "fly-cable", merged: "cable-crossover-mid"), // Crucifixo (Polia) ← Crossover (Polia Média)
        (kept: "v-grip-row-machine", merged: "chest-supported-row-machine"), // Remada Sentada Pegada V (Máquina) ← Remada Apoiada (Máquina)
        (kept: "overhead-press-barbell", merged: "seated-overhead-press-barbell"), // Desenvolvimento (Barra) ← Desenvolvimento Sentado (Barra)
        (kept: "standing-calf-raise-bodyweight", merged: "tibialis-raise"), // Panturrilha em Pé ← Elevação de Ponta dos Pés
    ]

    /// The names the library of 420 had for the combinations that changed name (the 32 renamed, and the
    /// junctions, whose second exercise had another name), by the combination's key: the search also finds an
    /// exercise by an old name.
    static let oldNames: [String: [String]] = [
        "fly-cable": ["Crossover (Polia Média)"], // Crucifixo (Polia)
        "cable-crossover": ["Crossover (Polia Alta)"], // Crucifixo Alto (Polia)
        "cable-crossover-low": ["Crossover (Polia Baixa)"], // Crucifixo Baixo (Polia)
        "v-grip-row-machine": ["Remada Sentada Pegada V (Máquina)", "Remada Apoiada (Máquina)"], // Remada Fechada (Máquina)
        "row-machine": ["Remada Sentada Aberta (Máquina)"], // Remada Aberta (Máquina)
        "t-bar-row-machine": ["Remada T-Bar (Máquina)"], // Remada na T-Bar (Máquina)
        "wide-grip-seated-cable-row": ["Remada Sentada Aberta (Polia)"], // Remada Baixa Aberta (Polia)
        "seated-row-band": ["Remada Sentada (Elástico)"], // Remada Baixa (Elástico)
        "lat-pulldown-machine": ["Puxada Alta (Máquina)"], // Puxada Alta Aberta (Máquina)
        "single-arm-lat-pulldown-machine": ["Puxada Unilateral (Máquina)"], // Puxada Alta Unilateral (Máquina)
        "high-row-machine": ["Remada Alta Articulada (Máquina)"], // Remada Alta Iso-Lateral (Máquina)
        "single-arm-high-row-machine": ["Remada Alta Articulada Unilateral (Máquina)"], // Remada Alta Unilateral Iso-Lateral (Máquina)
        "back-extension": ["Extensão Lombar"], // Extensão de Lombar
        "back-extension-machine": ["Extensão Lombar (Máquina)"], // Extensão de Lombar (Máquina)
        "back-extension-plate": ["Extensão Lombar (Anilha)"], // Extensão de Lombar (Anilha)
        "overhead-press-barbell": ["Desenvolvimento Sentado (Barra)"], // Desenvolvimento (Barra)
        "upright-row-barbell": ["Remada Alta (Barra)"], // Remada Ombro (Barra)
        "upright-row-dumbbell": ["Remada Alta (Halter)"], // Remada Ombro (Halter)
        "upright-row-smith": ["Remada Alta (Smith)"], // Remada Ombro (Smith)
        "upright-row-cable": ["Remada Alta (Polia)"], // Remada Ombro (Polia)
        "triceps-pushdown-bar": ["Tríceps Pulley (Polia)"], // Tríceps Barra (Polia)
        "triceps-pushdown-v-bar": ["Tríceps Pulley Barra V (Polia)"], // Tríceps Barra V (Polia)
        "reverse-grip-pushdown": ["Tríceps Pulley Invertido (Polia)"], // Tríceps Pegada Inversa (Polia)
        "overhead-extension-dumbbell": ["Extensão de Tríceps Acima da Cabeça (Halter)"], // Tríceps Francês (Halter)
        "overhead-extension-ez-bar": ["Extensão de Tríceps Acima da Cabeça (Barra W)"], // Tríceps Francês (Barra W)
        "single-arm-overhead-extension-dumbbell": ["Extensão de Tríceps Unilateral (Halter)"], // Tríceps Francês Unilateral (Halter)
        "overhead-extension-machine": ["Extensão de Tríceps Acima da Cabeça (Máquina)"], // Tríceps Francês (Máquina)
        "overhead-extension-rope": ["Extensão de Tríceps Acima da Cabeça (Polia)"], // Tríceps Francês (Polia)
        "single-arm-overhead-extension-cable": ["Extensão de Tríceps Acima da Cabeça Unilateral (Polia)"], // Tríceps Francês Unilateral (Polia)
        "overhead-extension-band": ["Extensão de Tríceps Acima da Cabeça (Elástico)"], // Tríceps Francês (Elástico)
        "standing-calf-raise-bodyweight": ["Elevação de Ponta dos Pés"], // Panturrilha em Pé
    ]
}
