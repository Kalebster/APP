import Foundation

/// The muscles of a library exercise, and its kind of machine when it is done on one: library data
/// only, never stored, found by the exercise's stable key (`Exercise.libraryKey`), like the equipment
/// and the focus of `DefaultExerciseLibrary`. Every key of the library has exactly one entry, in the
/// library's order; the values are those of the approved prototype ("MUS" and "MACH").
///
/// Rules (checked by the tests): at least one main muscle; no muscle both main and secondary; a kind of
/// machine only on an exercise whose equipment is `Equipment.machine`.
struct DefaultExerciseMuscles: Equatable, Sendable {
    let key: String
    /// The muscles the exercise works the most, in the order shown.
    let primary: [Muscle]
    /// The muscles that help, in the order shown; often none.
    let secondary: [Muscle]
    /// The kind of machine, for an exercise done on one.
    var machine: MachineType?

    /// The entry of the library exercise with `key`.
    static let byKey: [String: DefaultExerciseMuscles] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })

    /// Whether the exercise is done on a Graviton (counterweight) machine, whose kg is the help of the
    /// machine: its sets never count in the kg lifted, and its evolution reads less kg as better. True for
    /// the 4 Graviton exercises of the library and for an exercise of the user's own whose kind of machine
    /// is Graviton.
    static func isAssisted(_ exercise: Exercise?) -> Bool {
        guard let exercise else { return false }
        return machine(of: exercise) == .graviton
    }

    /// The muscles shown for an exercise: those of its library entry, those an exercise of the user's own
    /// chose, or, for one of the user's own without muscles of its own (created before version 8), the
    /// muscles of its group (none for "Corpo inteiro" and "Outro").
    static func muscles(of exercise: Exercise) -> (primary: [Muscle], secondary: [Muscle]) {
        if exercise.isCustom {
            let primary = exercise.primaryMuscles
            let secondary = exercise.secondaryMuscles
            if primary.isEmpty && secondary.isEmpty {
                return (muscles(of: exercise.muscleGroup), [])
            }
            return (primary, secondary)
        }
        if let key = exercise.libraryKey, let entry = byKey[key] {
            return (entry.primary, entry.secondary)
        }
        return (muscles(of: exercise.muscleGroup), [])
    }

    /// Whether the body figure shows the muscles of the exercise's group: an exercise of the user's own
    /// without muscles of its own.
    static func showsGroupMuscles(of exercise: Exercise) -> Bool {
        exercise.isCustom && exercise.primaryMuscleKeys.isEmpty && exercise.secondaryMuscleKeys.isEmpty
    }

    /// The kind of machine: the library's for a built-in exercise, the one chosen for an exercise of the
    /// user's own (only when its equipment is the machine).
    static func machine(of exercise: Exercise) -> MachineType? {
        if exercise.isCustom {
            return exercise.equipment == .machine ? exercise.machineType : nil
        }
        guard let key = exercise.libraryKey else { return nil }
        return byKey[key]?.machine
    }

    /// The equipment: the library's for a built-in exercise, the one chosen for an exercise of the user's
    /// own; `nil` is "Outro".
    static func equipment(of exercise: Exercise) -> Equipment? {
        if exercise.isCustom {
            return exercise.equipment
        }
        return exercise.libraryKey.flatMap { DefaultExerciseLibrary.byKey[$0] }?.equipment
    }

    /// The muscles of a muscle group, for an exercise of the user's own, as in the prototype.
    static func muscles(of group: MuscleGroup) -> [Muscle] {
        switch group {
        case .chest: [.chest]
        case .back: [.lats]
        case .upperBack: [.upperBack]
        case .traps: [.traps]
        case .lowerBack: [.lowerBack]
        case .shoulders: [.frontDelts, .sideDelts, .rearDelts]
        case .biceps: [.biceps]
        case .triceps: [.triceps]
        case .forearms: [.forearms]
        case .abs: [.abs]
        case .quadriceps: [.quadriceps]
        case .hamstrings: [.hamstrings]
        case .glutes: [.glutes]
        case .adductors: [.adductors]
        case .calves: [.calves]
        case .fullBody, .other: []
        }
    }

    static let all: [DefaultExerciseMuscles] = [
        DefaultExerciseMuscles(key: "bench-press-barbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Reto (Barra)
        DefaultExerciseMuscles(key: "bench-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Reto (Halter)
        DefaultExerciseMuscles(key: "chest-press-machine", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .plates), // Supino Reto (Máquina)
        DefaultExerciseMuscles(key: "bench-press-smith", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Reto (Smith)
        DefaultExerciseMuscles(key: "bench-press-cable", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Reto (Polia)
        DefaultExerciseMuscles(key: "chest-press-lever", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .lever), // Supino Reto Iso-Lateral (Máquina)
        DefaultExerciseMuscles(key: "incline-bench-press-barbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Inclinado (Barra)
        DefaultExerciseMuscles(key: "incline-bench-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Inclinado (Halter)
        DefaultExerciseMuscles(key: "incline-chest-press-machine", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .plates), // Supino Inclinado (Máquina)
        DefaultExerciseMuscles(key: "incline-bench-press-smith", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Inclinado (Smith)
        DefaultExerciseMuscles(key: "incline-bench-press-cable", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Inclinado (Polia)
        DefaultExerciseMuscles(key: "decline-bench-press-barbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Declinado (Barra)
        DefaultExerciseMuscles(key: "decline-bench-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Declinado (Halter)
        DefaultExerciseMuscles(key: "decline-chest-press-machine", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .plates), // Supino Declinado (Máquina)
        DefaultExerciseMuscles(key: "decline-bench-press-smith", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Declinado (Smith)
        DefaultExerciseMuscles(key: "decline-bench-press-cable", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Declinado (Polia)
        DefaultExerciseMuscles(key: "seated-chest-press-machine", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .plates), // Supino Sentado (Máquina)
        DefaultExerciseMuscles(key: "seated-chest-press-cable", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Sentado (Polia)
        DefaultExerciseMuscles(key: "fly-dumbbell", primary: [.chest], secondary: [.frontDelts]), // Crucifixo (Halter)
        DefaultExerciseMuscles(key: "fly-machine", primary: [.chest], secondary: [.frontDelts], machine: .plates), // Crucifixo (Máquina)
        DefaultExerciseMuscles(key: "fly-cable", primary: [.chest], secondary: [.frontDelts]), // Crucifixo (Polia)
        DefaultExerciseMuscles(key: "incline-fly-dumbbell", primary: [.chest], secondary: [.frontDelts]), // Crucifixo Inclinado (Halter)
        DefaultExerciseMuscles(key: "incline-fly-machine", primary: [.chest], secondary: [.frontDelts], machine: .plates), // Crucifixo Inclinado (Máquina)
        DefaultExerciseMuscles(key: "incline-fly-cable", primary: [.chest], secondary: [.frontDelts]), // Crucifixo Inclinado (Polia)
        DefaultExerciseMuscles(key: "cable-crossover", primary: [.chest], secondary: [.frontDelts]), // Crossover (Polia Alta)
        DefaultExerciseMuscles(key: "cable-crossover-mid", primary: [.chest], secondary: [.frontDelts]), // Crossover (Polia Média)
        DefaultExerciseMuscles(key: "cable-crossover-low", primary: [.chest], secondary: [.frontDelts]), // Crossover (Polia Baixa)
        DefaultExerciseMuscles(key: "single-arm-cable-crossover", primary: [.chest], secondary: [.frontDelts]), // Crossover Unilateral (Polia)
        DefaultExerciseMuscles(key: "push-up", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão
        DefaultExerciseMuscles(key: "decline-push-up", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão Declinada
        DefaultExerciseMuscles(key: "incline-push-up", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão Inclinada
        DefaultExerciseMuscles(key: "knee-push-up", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão com Joelhos Apoiados
        DefaultExerciseMuscles(key: "chest-dips", primary: [.chest], secondary: [.triceps, .frontDelts]), // Peito na Paralela
        DefaultExerciseMuscles(key: "single-arm-bench-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts, .obliques]), // Supino Reto Unilateral (Halter)
        DefaultExerciseMuscles(key: "neutral-grip-bench-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Reto Pegada Neutra (Halter)
        DefaultExerciseMuscles(key: "wide-grip-bench-press-barbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Reto Pegada Aberta (Barra)
        DefaultExerciseMuscles(key: "single-arm-chest-press-machine", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .plates), // Supino Reto Unilateral (Máquina)
        DefaultExerciseMuscles(key: "single-arm-bench-press-cable", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Reto Unilateral (Polia)
        DefaultExerciseMuscles(key: "single-arm-incline-bench-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Inclinado Unilateral (Halter)
        DefaultExerciseMuscles(key: "neutral-grip-incline-bench-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Inclinado Pegada Neutra (Halter)
        DefaultExerciseMuscles(key: "incline-chest-press-lever", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .lever), // Supino Inclinado Iso-Lateral (Máquina)
        DefaultExerciseMuscles(key: "single-arm-incline-chest-press-machine", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .plates), // Supino Inclinado Unilateral (Máquina)
        DefaultExerciseMuscles(key: "single-arm-incline-bench-press-cable", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Inclinado Unilateral (Polia)
        DefaultExerciseMuscles(key: "decline-chest-press-lever", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .lever), // Supino Declinado Iso-Lateral (Máquina)
        DefaultExerciseMuscles(key: "squeeze-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Squeeze (Halter)
        DefaultExerciseMuscles(key: "guillotine-press-barbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Guilhotina (Barra)
        DefaultExerciseMuscles(key: "floor-press-barbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino no Chão (Barra)
        DefaultExerciseMuscles(key: "floor-press-dumbbell", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino no Chão (Halter)
        DefaultExerciseMuscles(key: "landmine-chest-press", primary: [.chest], secondary: [.triceps, .frontDelts]), // Supino Landmine (Barra)
        DefaultExerciseMuscles(key: "decline-fly-dumbbell", primary: [.chest], secondary: [.frontDelts]), // Crucifixo Declinado (Halter)
        DefaultExerciseMuscles(key: "fly-band", primary: [.chest], secondary: [.frontDelts]), // Crucifixo (Elástico)
        DefaultExerciseMuscles(key: "svend-press", primary: [.chest], secondary: [.frontDelts]), // Svend Press (Anilha)
        DefaultExerciseMuscles(key: "assisted-chest-dips", primary: [.chest], secondary: [.triceps, .frontDelts], machine: .graviton), // Peito na Paralela (Graviton)
        DefaultExerciseMuscles(key: "wide-push-up", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão Aberta
        DefaultExerciseMuscles(key: "weighted-push-up-plate", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão (Anilha)
        DefaultExerciseMuscles(key: "band-push-up", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão (Elástico)
        DefaultExerciseMuscles(key: "archer-push-up", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão Arqueiro
        DefaultExerciseMuscles(key: "plyometric-push-up", primary: [.chest], secondary: [.triceps, .frontDelts]), // Flexão Explosiva
        DefaultExerciseMuscles(key: "pull-up", primary: [.lats], secondary: [.upperBack, .biceps]), // Barra Fixa (Pegada Aberta)
        DefaultExerciseMuscles(key: "close-grip-pull-up", primary: [.lats], secondary: [.upperBack, .biceps]), // Barra Fixa (Pegada Fechada)
        DefaultExerciseMuscles(key: "chin-up", primary: [.lats], secondary: [.biceps, .upperBack]), // Barra Fixa (Pegada Supinada)
        DefaultExerciseMuscles(key: "assisted-pull-up", primary: [.lats], secondary: [.upperBack, .biceps], machine: .graviton), // Barra Fixa (Graviton)
        DefaultExerciseMuscles(key: "lat-pulldown", primary: [.lats], secondary: [.upperBack, .biceps]), // Puxada Alta Aberta (Polia)
        DefaultExerciseMuscles(key: "close-grip-lat-pulldown", primary: [.lats], secondary: [.upperBack, .biceps]), // Puxada Alta Fechada (Polia)
        DefaultExerciseMuscles(key: "reverse-grip-lat-pulldown", primary: [.lats], secondary: [.biceps, .upperBack]), // Puxada Alta Supinada (Polia)
        DefaultExerciseMuscles(key: "lat-pulldown-machine", primary: [.lats], secondary: [.upperBack, .biceps], machine: .plates), // Puxada Alta (Máquina)
        DefaultExerciseMuscles(key: "single-arm-lat-pulldown", primary: [.lats], secondary: [.upperBack, .biceps]), // Puxada Unilateral (Polia)
        DefaultExerciseMuscles(key: "single-arm-lat-pulldown-machine", primary: [.lats], secondary: [.upperBack, .biceps], machine: .plates), // Puxada Unilateral (Máquina)
        DefaultExerciseMuscles(key: "reverse-grip-bent-over-row", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Curvada Supinada (Barra)
        DefaultExerciseMuscles(key: "one-arm-row-dumbbell", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Serrote (Halter)
        DefaultExerciseMuscles(key: "single-arm-row-cable", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Unilateral (Polia)
        DefaultExerciseMuscles(key: "single-arm-row-machine", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts], machine: .plates), // Remada Unilateral (Máquina)
        DefaultExerciseMuscles(key: "seated-cable-row", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Baixa (Polia)
        DefaultExerciseMuscles(key: "high-row-machine", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts], machine: .lever), // Remada Alta Articulada (Máquina)
        DefaultExerciseMuscles(key: "pullover-dumbbell", primary: [.lats], secondary: [.chest, .triceps]), // Pullover (Halter)
        DefaultExerciseMuscles(key: "pullover-barbell", primary: [.lats], secondary: [.chest, .triceps]), // Pullover (Barra)
        DefaultExerciseMuscles(key: "straight-arm-pulldown", primary: [.lats], secondary: [.triceps, .rearDelts]), // Pullover (Polia)
        DefaultExerciseMuscles(key: "pullover-machine", primary: [.lats], secondary: [.triceps, .rearDelts], machine: .plates), // Pullover (Máquina)
        DefaultExerciseMuscles(key: "neutral-grip-pull-up", primary: [.lats], secondary: [.biceps, .upperBack]), // Barra Fixa (Pegada Neutra)
        DefaultExerciseMuscles(key: "weighted-pull-up", primary: [.lats], secondary: [.upperBack, .biceps]), // Barra Fixa com Peso (Anilha)
        DefaultExerciseMuscles(key: "weighted-chin-up", primary: [.lats], secondary: [.biceps, .upperBack]), // Barra Fixa Supinada com Peso (Anilha)
        DefaultExerciseMuscles(key: "band-assisted-pull-up", primary: [.lats], secondary: [.upperBack, .biceps]), // Barra Fixa (Elástico)
        DefaultExerciseMuscles(key: "assisted-chin-up", primary: [.lats], secondary: [.biceps, .upperBack], machine: .graviton), // Barra Fixa Supinada (Graviton)
        DefaultExerciseMuscles(key: "neutral-grip-lat-pulldown", primary: [.lats], secondary: [.upperBack, .biceps]), // Puxada Alta Pegada Neutra (Polia)
        DefaultExerciseMuscles(key: "behind-the-neck-lat-pulldown", primary: [.lats], secondary: [.upperBack, .biceps]), // Puxada Atrás da Nuca (Polia)
        DefaultExerciseMuscles(key: "reverse-grip-lat-pulldown-machine", primary: [.lats], secondary: [.biceps, .upperBack], machine: .plates), // Puxada Alta Supinada (Máquina)
        DefaultExerciseMuscles(key: "close-grip-lat-pulldown-machine", primary: [.lats], secondary: [.upperBack, .biceps], machine: .plates), // Puxada Alta Fechada (Máquina)
        DefaultExerciseMuscles(key: "lat-pulldown-band", primary: [.lats], secondary: [.upperBack, .biceps]), // Puxada Alta (Elástico)
        DefaultExerciseMuscles(key: "rope-pullover-cable", primary: [.lats], secondary: [.triceps, .rearDelts]), // Pullover Corda (Polia)
        DefaultExerciseMuscles(key: "single-arm-pullover-cable", primary: [.lats], secondary: [.triceps, .rearDelts]), // Pullover Unilateral (Polia)
        DefaultExerciseMuscles(key: "kroc-row", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Kroc (Halter)
        DefaultExerciseMuscles(key: "meadows-row", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Meadows (Barra)
        DefaultExerciseMuscles(key: "single-arm-high-row-machine", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts], machine: .lever), // Remada Alta Articulada Unilateral (Máquina)
        DefaultExerciseMuscles(key: "reverse-grip-seated-cable-row", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Baixa Supinada (Polia)
        DefaultExerciseMuscles(key: "reverse-grip-bent-over-row-dumbbell", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Curvada Supinada (Halter)
        DefaultExerciseMuscles(key: "reverse-grip-bent-over-row-smith", primary: [.lats], secondary: [.upperBack, .biceps, .rearDelts]), // Remada Curvada Supinada (Smith)
        DefaultExerciseMuscles(key: "bent-over-row-barbell", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps, .lowerBack]), // Remada Curvada (Barra)
        DefaultExerciseMuscles(key: "bent-over-row-dumbbell", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps, .lowerBack]), // Remada Curvada (Halter)
        DefaultExerciseMuscles(key: "bent-over-row-smith", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps, .lowerBack]), // Remada Curvada (Smith)
        DefaultExerciseMuscles(key: "t-bar-row", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps, .lowerBack]), // Remada Cavalinho (Barra)
        DefaultExerciseMuscles(key: "t-bar-row-machine", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps], machine: .lever), // Remada T-Bar (Máquina)
        DefaultExerciseMuscles(key: "row-lever-machine", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps], machine: .lever), // Remada Baixa Iso-Lateral (Máquina)
        DefaultExerciseMuscles(key: "wide-grip-seated-cable-row", primary: [.upperBack], secondary: [.rearDelts, .traps, .biceps]), // Remada Sentada Aberta (Polia)
        DefaultExerciseMuscles(key: "row-machine", primary: [.upperBack], secondary: [.rearDelts, .traps, .biceps], machine: .plates), // Remada Sentada Aberta (Máquina)
        DefaultExerciseMuscles(key: "v-grip-row-machine", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps], machine: .plates), // Remada Sentada Pegada V (Máquina)
        DefaultExerciseMuscles(key: "seal-row", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps]), // Remada Apoiada no Banco (Halter)
        DefaultExerciseMuscles(key: "pendlay-row", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps, .lowerBack]), // Remada Pendlay (Barra)
        DefaultExerciseMuscles(key: "inverted-row", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps]), // Remada Invertida
        DefaultExerciseMuscles(key: "seal-row-barbell", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps]), // Remada Apoiada no Banco (Barra)
        DefaultExerciseMuscles(key: "chest-supported-row-machine", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps], machine: .lever), // Remada Apoiada (Máquina)
        DefaultExerciseMuscles(key: "single-arm-row-smith", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps]), // Remada Unilateral (Smith)
        DefaultExerciseMuscles(key: "bent-over-row-band", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps, .lowerBack]), // Remada Curvada (Elástico)
        DefaultExerciseMuscles(key: "seated-row-band", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps]), // Remada Sentada (Elástico)
        DefaultExerciseMuscles(key: "gorilla-row", primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps, .lowerBack]), // Remada Gorila (Kettlebell)
        DefaultExerciseMuscles(key: "renegade-row", primary: [.upperBack], secondary: [.lats, .abs, .biceps]), // Remada Renegada (Halter)
        DefaultExerciseMuscles(key: "scapular-pull-up", primary: [.upperBack, .traps], secondary: [.lats]), // Retração Escapular na Barra Fixa
        DefaultExerciseMuscles(key: "shrug-barbell", primary: [.traps], secondary: [.forearms]), // Encolhimento (Barra)
        DefaultExerciseMuscles(key: "shrug-dumbbell", primary: [.traps], secondary: [.forearms]), // Encolhimento (Halter)
        DefaultExerciseMuscles(key: "shrug-smith", primary: [.traps], secondary: [.forearms]), // Encolhimento (Smith)
        DefaultExerciseMuscles(key: "shrug-machine", primary: [.traps], secondary: [.forearms], machine: .lever), // Encolhimento (Máquina)
        DefaultExerciseMuscles(key: "shrug-cable", primary: [.traps], secondary: [.forearms]), // Encolhimento (Polia)
        DefaultExerciseMuscles(key: "behind-the-back-shrug", primary: [.traps], secondary: [.forearms]), // Encolhimento Atrás do Corpo (Barra)
        DefaultExerciseMuscles(key: "incline-shrug-dumbbell", primary: [.traps], secondary: [.upperBack]), // Encolhimento Inclinado (Halter)
        DefaultExerciseMuscles(key: "y-raise-dumbbell", primary: [.traps], secondary: [.sideDelts, .rearDelts]), // Elevação Y (Halter)
        DefaultExerciseMuscles(key: "y-raise-cable", primary: [.traps], secondary: [.sideDelts, .rearDelts]), // Elevação Y (Polia)
        DefaultExerciseMuscles(key: "back-extension", primary: [.lowerBack], secondary: [.glutes, .hamstrings]), // Extensão Lombar
        DefaultExerciseMuscles(key: "back-extension-plate", primary: [.lowerBack], secondary: [.glutes, .hamstrings]), // Extensão Lombar (Anilha)
        DefaultExerciseMuscles(key: "back-extension-machine", primary: [.lowerBack], secondary: [.glutes, .hamstrings], machine: .plates), // Extensão Lombar (Máquina)
        DefaultExerciseMuscles(key: "superman", primary: [.lowerBack], secondary: [.glutes, .hamstrings]), // Super-Homem
        DefaultExerciseMuscles(key: "deadlift", primary: [.lowerBack, .glutes, .hamstrings], secondary: [.quadriceps, .traps, .forearms]), // Levantamento Terra (Barra)
        DefaultExerciseMuscles(key: "deadlift-dumbbell", primary: [.lowerBack, .glutes, .hamstrings], secondary: [.quadriceps, .traps, .forearms]), // Levantamento Terra (Halter)
        DefaultExerciseMuscles(key: "trap-bar-deadlift", primary: [.lowerBack, .glutes, .hamstrings], secondary: [.quadriceps, .traps, .forearms]), // Levantamento Terra (Barra Hexagonal)
        DefaultExerciseMuscles(key: "deficit-deadlift", primary: [.lowerBack, .glutes, .hamstrings], secondary: [.quadriceps, .traps, .forearms]), // Levantamento Terra Déficit (Barra)
        DefaultExerciseMuscles(key: "rack-pull", primary: [.lowerBack, .traps], secondary: [.glutes, .hamstrings, .forearms]), // Rack Pull (Barra)
        DefaultExerciseMuscles(key: "deadlift-kettlebell", primary: [.lowerBack, .glutes, .hamstrings], secondary: [.quadriceps, .traps, .forearms]), // Levantamento Terra (Kettlebell)
        DefaultExerciseMuscles(key: "bird-dog", primary: [.lowerBack], secondary: [.glutes, .abs]), // Bird Dog
        DefaultExerciseMuscles(key: "overhead-press-barbell", primary: [.frontDelts], secondary: [.sideDelts, .triceps]), // Desenvolvimento (Barra)
        DefaultExerciseMuscles(key: "shoulder-press-dumbbell", primary: [.frontDelts], secondary: [.sideDelts, .triceps]), // Desenvolvimento (Halter)
        DefaultExerciseMuscles(key: "shoulder-press-machine", primary: [.frontDelts], secondary: [.sideDelts, .triceps], machine: .plates), // Desenvolvimento (Máquina)
        DefaultExerciseMuscles(key: "shoulder-press-smith", primary: [.frontDelts], secondary: [.sideDelts, .triceps]), // Desenvolvimento (Smith)
        DefaultExerciseMuscles(key: "arnold-press", primary: [.frontDelts, .sideDelts], secondary: [.triceps]), // Desenvolvimento Arnold (Halter)
        DefaultExerciseMuscles(key: "lateral-raise-dumbbell", primary: [.sideDelts], secondary: [.traps]), // Elevação Lateral (Halter)
        DefaultExerciseMuscles(key: "lateral-raise-cable", primary: [.sideDelts], secondary: [.traps]), // Elevação Lateral (Polia)
        DefaultExerciseMuscles(key: "lateral-raise-machine", primary: [.sideDelts], secondary: [.traps], machine: .plates), // Elevação Lateral (Máquina)
        DefaultExerciseMuscles(key: "single-arm-lateral-raise-dumbbell", primary: [.sideDelts], secondary: [.traps]), // Elevação Lateral Unilateral (Halter)
        DefaultExerciseMuscles(key: "single-arm-lateral-raise-cable", primary: [.sideDelts], secondary: [.traps]), // Elevação Lateral Unilateral (Polia)
        DefaultExerciseMuscles(key: "front-raise-dumbbell", primary: [.frontDelts], secondary: [.sideDelts]), // Elevação Frontal (Halter)
        DefaultExerciseMuscles(key: "front-raise-barbell", primary: [.frontDelts], secondary: [.sideDelts]), // Elevação Frontal (Barra)
        DefaultExerciseMuscles(key: "front-raise-plate", primary: [.frontDelts], secondary: [.sideDelts]), // Elevação Frontal (Anilha)
        DefaultExerciseMuscles(key: "front-raise-cable", primary: [.frontDelts], secondary: [.sideDelts]), // Elevação Frontal (Polia)
        DefaultExerciseMuscles(key: "reverse-fly-dumbbell", primary: [.rearDelts], secondary: [.upperBack, .traps]), // Crucifixo Invertido (Halter)
        DefaultExerciseMuscles(key: "reverse-fly-machine", primary: [.rearDelts], secondary: [.upperBack, .traps], machine: .plates), // Crucifixo Invertido (Máquina)
        DefaultExerciseMuscles(key: "reverse-fly-cable", primary: [.rearDelts], secondary: [.upperBack, .traps]), // Crucifixo Invertido (Polia)
        DefaultExerciseMuscles(key: "single-arm-reverse-fly-cable", primary: [.rearDelts], secondary: [.upperBack, .traps]), // Crucifixo Invertido Unilateral (Polia)
        DefaultExerciseMuscles(key: "face-pull", primary: [.rearDelts, .rotatorCuff], secondary: [.upperBack, .traps]), // Face Pull (Polia)
        DefaultExerciseMuscles(key: "upright-row-barbell", primary: [.sideDelts, .traps], secondary: [.frontDelts, .biceps]), // Remada Alta (Barra)
        DefaultExerciseMuscles(key: "upright-row-dumbbell", primary: [.sideDelts, .traps], secondary: [.frontDelts, .biceps]), // Remada Alta (Halter)
        DefaultExerciseMuscles(key: "upright-row-cable", primary: [.sideDelts, .traps], secondary: [.frontDelts, .biceps]), // Remada Alta (Polia)
        DefaultExerciseMuscles(key: "external-rotation-cable", primary: [.rotatorCuff], secondary: [.rearDelts]), // Rotação Externa (Polia)
        DefaultExerciseMuscles(key: "seated-overhead-press-barbell", primary: [.frontDelts], secondary: [.sideDelts, .triceps]), // Desenvolvimento Sentado (Barra)
        DefaultExerciseMuscles(key: "behind-the-neck-press-barbell", primary: [.frontDelts, .sideDelts], secondary: [.triceps, .traps]), // Desenvolvimento Atrás da Nuca (Barra)
        DefaultExerciseMuscles(key: "behind-the-neck-press-smith", primary: [.frontDelts, .sideDelts], secondary: [.triceps, .traps]), // Desenvolvimento Atrás da Nuca (Smith)
        DefaultExerciseMuscles(key: "single-arm-shoulder-press-dumbbell", primary: [.frontDelts], secondary: [.sideDelts, .triceps, .obliques]), // Desenvolvimento Unilateral (Halter)
        DefaultExerciseMuscles(key: "neutral-grip-shoulder-press-dumbbell", primary: [.frontDelts], secondary: [.sideDelts, .triceps]), // Desenvolvimento Pegada Neutra (Halter)
        DefaultExerciseMuscles(key: "shoulder-press-lever", primary: [.frontDelts], secondary: [.sideDelts, .triceps], machine: .lever), // Desenvolvimento Iso-Lateral (Máquina)
        DefaultExerciseMuscles(key: "single-arm-shoulder-press-machine", primary: [.frontDelts], secondary: [.sideDelts, .triceps], machine: .plates), // Desenvolvimento Unilateral (Máquina)
        DefaultExerciseMuscles(key: "shoulder-press-kettlebell", primary: [.frontDelts], secondary: [.sideDelts, .triceps]), // Desenvolvimento (Kettlebell)
        DefaultExerciseMuscles(key: "shoulder-press-band", primary: [.frontDelts], secondary: [.sideDelts, .triceps]), // Desenvolvimento (Elástico)
        DefaultExerciseMuscles(key: "landmine-shoulder-press", primary: [.frontDelts], secondary: [.chest, .triceps]), // Desenvolvimento Landmine (Barra)
        DefaultExerciseMuscles(key: "push-press", primary: [.frontDelts], secondary: [.triceps, .sideDelts, .quadriceps, .glutes]), // Push Press (Barra)
        DefaultExerciseMuscles(key: "seated-lateral-raise-dumbbell", primary: [.sideDelts], secondary: [.traps]), // Elevação Lateral Sentado (Halter)
        DefaultExerciseMuscles(key: "lateral-raise-band", primary: [.sideDelts], secondary: [.traps]), // Elevação Lateral (Elástico)
        DefaultExerciseMuscles(key: "alternating-front-raise-dumbbell", primary: [.frontDelts], secondary: [.sideDelts]), // Elevação Frontal Alternada (Halter)
        DefaultExerciseMuscles(key: "single-arm-front-raise-cable", primary: [.frontDelts], secondary: [.sideDelts]), // Elevação Frontal Unilateral (Polia)
        DefaultExerciseMuscles(key: "front-raise-band", primary: [.frontDelts], secondary: [.sideDelts]), // Elevação Frontal (Elástico)
        DefaultExerciseMuscles(key: "incline-reverse-fly-dumbbell", primary: [.rearDelts], secondary: [.upperBack, .traps]), // Crucifixo Invertido Inclinado (Halter)
        DefaultExerciseMuscles(key: "reverse-fly-band", primary: [.rearDelts], secondary: [.upperBack, .traps]), // Crucifixo Invertido (Elástico)
        DefaultExerciseMuscles(key: "face-pull-band", primary: [.rearDelts, .rotatorCuff], secondary: [.upperBack, .traps]), // Face Pull (Elástico)
        DefaultExerciseMuscles(key: "upright-row-smith", primary: [.sideDelts, .traps], secondary: [.frontDelts, .biceps]), // Remada Alta (Smith)
        DefaultExerciseMuscles(key: "external-rotation-dumbbell", primary: [.rotatorCuff], secondary: [.rearDelts]), // Rotação Externa (Halter)
        DefaultExerciseMuscles(key: "external-rotation-band", primary: [.rotatorCuff], secondary: [.rearDelts]), // Rotação Externa (Elástico)
        DefaultExerciseMuscles(key: "internal-rotation-cable", primary: [.rotatorCuff], secondary: [.frontDelts]), // Rotação Interna (Polia)
        DefaultExerciseMuscles(key: "pike-push-up", primary: [.frontDelts], secondary: [.triceps, .sideDelts]), // Flexão Pike
        DefaultExerciseMuscles(key: "handstand-push-up", primary: [.frontDelts, .triceps], secondary: [.sideDelts, .traps]), // Flexão em Parada de Mão
        DefaultExerciseMuscles(key: "curl-barbell", primary: [.biceps], secondary: [.forearms]), // Rosca Direta (Barra)
        DefaultExerciseMuscles(key: "curl-ez-bar", primary: [.biceps], secondary: [.forearms]), // Rosca Direta (Barra W)
        DefaultExerciseMuscles(key: "curl-dumbbell", primary: [.biceps], secondary: [.forearms]), // Rosca Direta (Halter)
        DefaultExerciseMuscles(key: "alternating-curl-dumbbell", primary: [.biceps], secondary: [.forearms]), // Rosca Alternada (Halter)
        DefaultExerciseMuscles(key: "curl-cable", primary: [.biceps], secondary: [.forearms]), // Rosca Direta (Polia)
        DefaultExerciseMuscles(key: "single-arm-curl-cable", primary: [.biceps], secondary: [.forearms]), // Rosca Unilateral (Polia)
        DefaultExerciseMuscles(key: "bayesian-curl-cable", primary: [.biceps], secondary: [.forearms]), // Rosca Bayesiana (Polia)
        DefaultExerciseMuscles(key: "preacher-curl", primary: [.biceps], secondary: [.forearms]), // Rosca Scott (Barra W)
        DefaultExerciseMuscles(key: "preacher-curl-machine", primary: [.biceps], secondary: [.forearms], machine: .plates), // Rosca Scott (Máquina)
        DefaultExerciseMuscles(key: "preacher-curl-cable", primary: [.biceps], secondary: [.forearms]), // Rosca Scott (Polia)
        DefaultExerciseMuscles(key: "preacher-curl-dumbbell", primary: [.biceps], secondary: [.forearms]), // Rosca Scott Unilateral (Halter)
        DefaultExerciseMuscles(key: "concentration-curl", primary: [.biceps], secondary: [.forearms]), // Rosca Concentrada (Halter)
        DefaultExerciseMuscles(key: "hammer-curl-dumbbell", primary: [.biceps, .forearms], secondary: []), // Rosca Martelo (Halter)
        DefaultExerciseMuscles(key: "hammer-curl-rope", primary: [.biceps, .forearms], secondary: []), // Rosca Martelo (Polia)
        DefaultExerciseMuscles(key: "incline-curl-dumbbell", primary: [.biceps], secondary: [.forearms]), // Rosca Inclinada (Halter)
        DefaultExerciseMuscles(key: "spider-curl-ez-bar", primary: [.biceps], secondary: [.forearms]), // Rosca Spider (Barra W)
        DefaultExerciseMuscles(key: "spider-curl-dumbbell", primary: [.biceps], secondary: [.forearms]), // Rosca Spider (Halter)
        DefaultExerciseMuscles(key: "curl-machine", primary: [.biceps], secondary: [.forearms], machine: .plates), // Rosca Direta (Máquina)
        DefaultExerciseMuscles(key: "curl-band", primary: [.biceps], secondary: [.forearms]), // Rosca Direta (Elástico)
        DefaultExerciseMuscles(key: "close-grip-curl-ez-bar", primary: [.biceps], secondary: [.forearms]), // Rosca Direta Pegada Fechada (Barra W)
        DefaultExerciseMuscles(key: "curl-21s-barbell", primary: [.biceps], secondary: [.forearms]), // Rosca 21 (Barra)
        DefaultExerciseMuscles(key: "drag-curl-barbell", primary: [.biceps], secondary: [.forearms]), // Rosca Arrastada (Barra)
        DefaultExerciseMuscles(key: "alternating-hammer-curl-dumbbell", primary: [.biceps, .forearms], secondary: []), // Rosca Martelo Alternada (Halter)
        DefaultExerciseMuscles(key: "cross-body-hammer-curl", primary: [.biceps], secondary: [.forearms]), // Rosca Martelo Cruzada (Halter)
        DefaultExerciseMuscles(key: "preacher-curl-barbell", primary: [.biceps], secondary: [.forearms]), // Rosca Scott (Barra)
        DefaultExerciseMuscles(key: "single-arm-preacher-curl-cable", primary: [.biceps], secondary: [.forearms]), // Rosca Scott Unilateral (Polia)
        DefaultExerciseMuscles(key: "single-arm-preacher-curl-machine", primary: [.biceps], secondary: [.forearms], machine: .plates), // Rosca Scott Unilateral (Máquina)
        DefaultExerciseMuscles(key: "concentration-curl-cable", primary: [.biceps], secondary: [.forearms]), // Rosca Concentrada (Polia)
        DefaultExerciseMuscles(key: "zottman-curl", primary: [.biceps, .forearms], secondary: []), // Rosca Zottman (Halter)
        DefaultExerciseMuscles(key: "high-cable-curl", primary: [.biceps], secondary: [.forearms]), // Rosca Alta (Polia)
        DefaultExerciseMuscles(key: "triceps-pushdown-bar", primary: [.triceps], secondary: []), // Tríceps Pulley (Polia)
        DefaultExerciseMuscles(key: "triceps-pushdown-rope", primary: [.triceps], secondary: []), // Tríceps Corda (Polia)
        DefaultExerciseMuscles(key: "single-arm-triceps-pushdown", primary: [.triceps], secondary: []), // Tríceps Unilateral (Polia)
        DefaultExerciseMuscles(key: "single-arm-reverse-grip-pushdown", primary: [.triceps], secondary: []), // Tríceps Unilateral Invertido (Polia)
        DefaultExerciseMuscles(key: "overhead-extension-dumbbell", primary: [.triceps], secondary: []), // Extensão de Tríceps Acima da Cabeça (Halter)
        DefaultExerciseMuscles(key: "overhead-extension-ez-bar", primary: [.triceps], secondary: []), // Extensão de Tríceps Acima da Cabeça (Barra W)
        DefaultExerciseMuscles(key: "overhead-extension-rope", primary: [.triceps], secondary: []), // Extensão de Tríceps Acima da Cabeça (Polia)
        DefaultExerciseMuscles(key: "single-arm-overhead-extension-dumbbell", primary: [.triceps], secondary: []), // Extensão de Tríceps Unilateral (Halter)
        DefaultExerciseMuscles(key: "triceps-extension-machine", primary: [.triceps], secondary: [], machine: .plates), // Extensão de Tríceps (Máquina)
        DefaultExerciseMuscles(key: "skull-crusher-barbell", primary: [.triceps], secondary: []), // Tríceps Testa (Barra W)
        DefaultExerciseMuscles(key: "skull-crusher-dumbbell", primary: [.triceps], secondary: []), // Tríceps Testa (Halter)
        DefaultExerciseMuscles(key: "skull-crusher-cable", primary: [.triceps], secondary: []), // Tríceps Testa (Polia)
        DefaultExerciseMuscles(key: "skull-crusher-smith", primary: [.triceps], secondary: []), // Tríceps Testa (Smith)
        DefaultExerciseMuscles(key: "kickback-dumbbell", primary: [.triceps], secondary: []), // Tríceps Coice (Halter)
        DefaultExerciseMuscles(key: "kickback-cable", primary: [.triceps], secondary: []), // Tríceps Coice (Polia)
        DefaultExerciseMuscles(key: "jm-press-barbell", primary: [.triceps], secondary: [.chest]), // JM Press (Barra)
        DefaultExerciseMuscles(key: "jm-press-smith", primary: [.triceps], secondary: [.chest]), // JM Press (Smith)
        DefaultExerciseMuscles(key: "close-grip-bench-press", primary: [.triceps], secondary: [.chest, .frontDelts]), // Supino Fechado (Barra)
        DefaultExerciseMuscles(key: "close-grip-bench-press-smith", primary: [.triceps], secondary: [.chest, .frontDelts]), // Supino Fechado (Smith)
        DefaultExerciseMuscles(key: "seated-dip-machine", primary: [.triceps], secondary: [.chest, .frontDelts], machine: .plates), // Mergulho Sentado (Máquina)
        DefaultExerciseMuscles(key: "dips", primary: [.triceps], secondary: [.chest, .frontDelts]), // Tríceps na Paralela
        DefaultExerciseMuscles(key: "bench-dips", primary: [.triceps], secondary: [.chest, .frontDelts]), // Tríceps no Banco
        DefaultExerciseMuscles(key: "diamond-push-up", primary: [.triceps], secondary: [.chest, .frontDelts]), // Flexão Diamante
        DefaultExerciseMuscles(key: "reverse-grip-pushdown", primary: [.triceps], secondary: []), // Tríceps Pulley Invertido (Polia)
        DefaultExerciseMuscles(key: "triceps-pushdown-v-bar", primary: [.triceps], secondary: []), // Tríceps Pulley Barra V (Polia)
        DefaultExerciseMuscles(key: "cross-body-triceps-extension-cable", primary: [.triceps], secondary: []), // Tríceps Cruzado (Polia)
        DefaultExerciseMuscles(key: "triceps-pushdown-band", primary: [.triceps], secondary: []), // Tríceps (Elástico)
        DefaultExerciseMuscles(key: "single-arm-overhead-extension-cable", primary: [.triceps], secondary: []), // Extensão de Tríceps Acima da Cabeça Unilateral (Polia)
        DefaultExerciseMuscles(key: "overhead-extension-machine", primary: [.triceps], secondary: [], machine: .plates), // Extensão de Tríceps Acima da Cabeça (Máquina)
        DefaultExerciseMuscles(key: "overhead-extension-band", primary: [.triceps], secondary: []), // Extensão de Tríceps Acima da Cabeça (Elástico)
        DefaultExerciseMuscles(key: "skull-crusher-straight-bar", primary: [.triceps], secondary: []), // Tríceps Testa (Barra)
        DefaultExerciseMuscles(key: "incline-skull-crusher-ez-bar", primary: [.triceps], secondary: []), // Tríceps Testa Inclinado (Barra W)
        DefaultExerciseMuscles(key: "single-arm-skull-crusher-dumbbell", primary: [.triceps], secondary: []), // Tríceps Testa Unilateral (Halter)
        DefaultExerciseMuscles(key: "tate-press", primary: [.triceps], secondary: []), // Tate Press (Halter)
        DefaultExerciseMuscles(key: "close-grip-bench-press-dumbbell", primary: [.triceps], secondary: [.chest, .frontDelts]), // Supino Fechado (Halter)
        DefaultExerciseMuscles(key: "weighted-dips", primary: [.triceps], secondary: [.chest, .frontDelts]), // Tríceps na Paralela com Peso (Anilha)
        DefaultExerciseMuscles(key: "assisted-dips", primary: [.triceps], secondary: [.chest, .frontDelts], machine: .graviton), // Tríceps na Paralela (Graviton)
        DefaultExerciseMuscles(key: "weighted-bench-dips", primary: [.triceps], secondary: [.chest, .frontDelts]), // Tríceps no Banco com Peso (Anilha)
        DefaultExerciseMuscles(key: "close-grip-push-up", primary: [.triceps], secondary: [.chest, .frontDelts]), // Flexão Fechada
        DefaultExerciseMuscles(key: "wrist-curl-barbell", primary: [.forearms], secondary: []), // Rosca de Punho (Barra)
        DefaultExerciseMuscles(key: "wrist-curl-dumbbell", primary: [.forearms], secondary: []), // Rosca de Punho (Halter)
        DefaultExerciseMuscles(key: "reverse-wrist-curl-barbell", primary: [.forearms], secondary: []), // Rosca de Punho Invertida (Barra)
        DefaultExerciseMuscles(key: "reverse-wrist-curl-dumbbell", primary: [.forearms], secondary: []), // Rosca de Punho Invertida (Halter)
        DefaultExerciseMuscles(key: "reverse-curl-barbell", primary: [.forearms], secondary: [.biceps]), // Rosca Invertida (Barra W)
        DefaultExerciseMuscles(key: "reverse-curl-dumbbell", primary: [.forearms], secondary: [.biceps]), // Rosca Invertida (Halter)
        DefaultExerciseMuscles(key: "reverse-curl-cable", primary: [.forearms], secondary: [.biceps]), // Rosca Invertida (Polia)
        DefaultExerciseMuscles(key: "wrist-curl-cable", primary: [.forearms], secondary: []), // Rosca de Punho (Polia)
        DefaultExerciseMuscles(key: "behind-the-back-wrist-curl", primary: [.forearms], secondary: []), // Rosca de Punho Atrás do Corpo (Barra)
        DefaultExerciseMuscles(key: "reverse-curl-straight-bar", primary: [.forearms], secondary: [.biceps]), // Rosca Invertida (Barra)
        DefaultExerciseMuscles(key: "wrist-roller", primary: [.forearms], secondary: []), // Rolo de Antebraço (Anilha)
        DefaultExerciseMuscles(key: "wrist-rotation-dumbbell", primary: [.forearms], secondary: []), // Rotação de Punho (Halter)
        DefaultExerciseMuscles(key: "crunch", primary: [.abs], secondary: [.obliques]), // Abdominal
        DefaultExerciseMuscles(key: "weighted-crunch-plate", primary: [.abs], secondary: [.obliques]), // Abdominal (Anilha)
        DefaultExerciseMuscles(key: "cable-crunch", primary: [.abs], secondary: [.obliques]), // Abdominal (Polia)
        DefaultExerciseMuscles(key: "crunch-machine", primary: [.abs], secondary: [.obliques], machine: .plates), // Abdominal (Máquina)
        DefaultExerciseMuscles(key: "decline-crunch", primary: [.abs], secondary: [.obliques]), // Abdominal Declinado
        DefaultExerciseMuscles(key: "reverse-crunch", primary: [.abs], secondary: [.obliques]), // Abdominal Infra
        DefaultExerciseMuscles(key: "oblique-crunch", primary: [.obliques], secondary: [.abs]), // Abdominal Oblíquo
        DefaultExerciseMuscles(key: "bicycle-crunch", primary: [.obliques], secondary: [.abs]), // Abdominal Bicicleta
        DefaultExerciseMuscles(key: "scissor-kick", primary: [.abs], secondary: [.obliques]), // Abdominal Tesoura
        DefaultExerciseMuscles(key: "ab-wheel-rollout", primary: [.abs], secondary: [.obliques, .lats]), // Roda Abdominal
        DefaultExerciseMuscles(key: "dragon-flag", primary: [.abs], secondary: [.obliques]), // Dragon Flag
        DefaultExerciseMuscles(key: "lying-leg-raise", primary: [.abs], secondary: [.obliques]), // Elevação de Pernas Deitado
        DefaultExerciseMuscles(key: "hanging-leg-raise", primary: [.abs], secondary: [.obliques, .forearms]), // Elevação de Pernas na Barra Fixa
        DefaultExerciseMuscles(key: "captains-chair-knee-raise", primary: [.abs], secondary: [.obliques]), // Elevação de Joelhos na Paralela
        DefaultExerciseMuscles(key: "russian-twist", primary: [.obliques], secondary: [.abs]), // Rotação Russa (Anilha)
        DefaultExerciseMuscles(key: "cable-woodchop", primary: [.obliques], secondary: [.abs]), // Lenhador (Polia)
        DefaultExerciseMuscles(key: "dead-bug", primary: [.abs], secondary: [.obliques]), // Dead Bug
        DefaultExerciseMuscles(key: "sit-up", primary: [.abs], secondary: [.obliques]), // Abdominal Completo
        DefaultExerciseMuscles(key: "weighted-decline-crunch", primary: [.abs], secondary: [.obliques]), // Abdominal Declinado (Anilha)
        DefaultExerciseMuscles(key: "v-up", primary: [.abs], secondary: [.obliques]), // Abdominal Canivete
        DefaultExerciseMuscles(key: "rowing-crunch", primary: [.abs], secondary: [.obliques]), // Abdominal Remador
        DefaultExerciseMuscles(key: "heel-touch", primary: [.obliques], secondary: [.abs]), // Abdominal Toque no Calcanhar
        DefaultExerciseMuscles(key: "stability-ball-crunch", primary: [.abs], secondary: [.obliques]), // Abdominal na Bola Suíça
        DefaultExerciseMuscles(key: "hanging-knee-raise", primary: [.abs], secondary: [.obliques, .forearms]), // Elevação de Joelhos na Barra Fixa
        DefaultExerciseMuscles(key: "captains-chair-leg-raise", primary: [.abs], secondary: [.obliques]), // Elevação de Pernas na Paralela
        DefaultExerciseMuscles(key: "decline-leg-raise", primary: [.abs], secondary: [.obliques]), // Elevação de Pernas no Banco Declinado
        DefaultExerciseMuscles(key: "toes-to-bar", primary: [.abs], secondary: [.obliques, .forearms]), // Pés na Barra
        DefaultExerciseMuscles(key: "windshield-wiper", primary: [.obliques], secondary: [.abs]), // Limpador de Para-brisa
        DefaultExerciseMuscles(key: "mountain-climber", primary: [.abs], secondary: [.quadriceps, .frontDelts]), // Escalador
        DefaultExerciseMuscles(key: "side-bend-dumbbell", primary: [.obliques], secondary: [.abs]), // Flexão Lateral (Halter)
        DefaultExerciseMuscles(key: "side-bend-cable", primary: [.obliques], secondary: [.abs]), // Flexão Lateral (Polia)
        DefaultExerciseMuscles(key: "russian-twist-dumbbell", primary: [.obliques], secondary: [.abs]), // Rotação Russa (Halter)
        DefaultExerciseMuscles(key: "torso-rotation-machine", primary: [.obliques], secondary: [.abs], machine: .plates), // Rotação de Tronco (Máquina)
        DefaultExerciseMuscles(key: "reverse-cable-woodchop", primary: [.obliques], secondary: [.abs]), // Lenhador Invertido (Polia)
        DefaultExerciseMuscles(key: "pallof-press", primary: [.obliques], secondary: [.abs]), // Pallof Press (Polia)
        DefaultExerciseMuscles(key: "back-squat", primary: [.quadriceps, .glutes], secondary: [.adductors, .hamstrings]), // Agachamento Livre (Barra)
        DefaultExerciseMuscles(key: "front-squat", primary: [.quadriceps], secondary: [.glutes, .abs]), // Agachamento Frontal (Barra)
        DefaultExerciseMuscles(key: "squat-smith", primary: [.quadriceps], secondary: [.glutes, .adductors]), // Agachamento (Smith)
        DefaultExerciseMuscles(key: "hack-squat", primary: [.quadriceps], secondary: [.glutes, .adductors], machine: .track), // Agachamento Hack (Máquina)
        DefaultExerciseMuscles(key: "pendulum-squat", primary: [.quadriceps], secondary: [.glutes, .adductors], machine: .lever), // Agachamento Pendular (Máquina)
        DefaultExerciseMuscles(key: "goblet-squat", primary: [.quadriceps], secondary: [.glutes, .adductors]), // Agachamento Goblet (Kettlebell)
        DefaultExerciseMuscles(key: "goblet-squat-dumbbell", primary: [.quadriceps], secondary: [.glutes, .adductors]), // Agachamento Goblet (Halter)
        DefaultExerciseMuscles(key: "bulgarian-split-squat", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Agachamento Búlgaro (Halter)
        DefaultExerciseMuscles(key: "bulgarian-split-squat-smith", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Agachamento Búlgaro (Smith)
        DefaultExerciseMuscles(key: "bodyweight-squat", primary: [.quadriceps], secondary: [.glutes, .adductors]), // Agachamento sem Peso
        DefaultExerciseMuscles(key: "sissy-squat", primary: [.quadriceps], secondary: []), // Sissy Squat
        DefaultExerciseMuscles(key: "leg-press", primary: [.quadriceps, .glutes], secondary: [.adductors, .hamstrings], machine: .track), // Leg Press 45° (Máquina)
        DefaultExerciseMuscles(key: "leg-press-horizontal", primary: [.quadriceps], secondary: [.glutes, .adductors], machine: .plates), // Leg Press Horizontal (Máquina)
        DefaultExerciseMuscles(key: "single-leg-press", primary: [.quadriceps, .glutes], secondary: [.adductors, .hamstrings], machine: .track), // Leg Press Unilateral (Máquina)
        DefaultExerciseMuscles(key: "leg-extension", primary: [.quadriceps], secondary: [], machine: .plates), // Cadeira Extensora (Máquina)
        DefaultExerciseMuscles(key: "single-leg-extension", primary: [.quadriceps], secondary: [], machine: .plates), // Cadeira Extensora Unilateral (Máquina)
        DefaultExerciseMuscles(key: "lunge-dumbbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Afundo (Halter)
        DefaultExerciseMuscles(key: "lunge-barbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Afundo (Barra)
        DefaultExerciseMuscles(key: "lunge-smith", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Afundo (Smith)
        DefaultExerciseMuscles(key: "walking-lunge-dumbbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Passada (Halter)
        DefaultExerciseMuscles(key: "walking-lunge-barbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Passada (Barra)
        DefaultExerciseMuscles(key: "step-up-dumbbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Subida no Banco (Halter)
        DefaultExerciseMuscles(key: "squat-dumbbell", primary: [.quadriceps, .glutes], secondary: [.adductors, .hamstrings]), // Agachamento (Halter)
        DefaultExerciseMuscles(key: "box-squat", primary: [.quadriceps, .glutes], secondary: [.adductors, .hamstrings]), // Agachamento no Banco (Barra)
        DefaultExerciseMuscles(key: "zercher-squat", primary: [.quadriceps], secondary: [.glutes, .abs]), // Agachamento Zercher (Barra)
        DefaultExerciseMuscles(key: "overhead-squat", primary: [.quadriceps], secondary: [.glutes, .frontDelts, .abs]), // Agachamento Overhead (Barra)
        DefaultExerciseMuscles(key: "front-squat-smith", primary: [.quadriceps], secondary: [.glutes, .abs]), // Agachamento Frontal (Smith)
        DefaultExerciseMuscles(key: "v-squat-machine", primary: [.quadriceps], secondary: [.glutes, .adductors], machine: .lever), // Agachamento V-Squat (Máquina)
        DefaultExerciseMuscles(key: "belt-squat-machine", primary: [.quadriceps, .glutes], secondary: [.adductors, .hamstrings], machine: .lever), // Agachamento com Cinto (Máquina)
        DefaultExerciseMuscles(key: "bulgarian-split-squat-barbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Agachamento Búlgaro (Barra)
        DefaultExerciseMuscles(key: "bulgarian-split-squat-bodyweight", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Agachamento Búlgaro
        DefaultExerciseMuscles(key: "pistol-squat", primary: [.quadriceps], secondary: [.glutes, .adductors]), // Agachamento Pistol
        DefaultExerciseMuscles(key: "cossack-squat", primary: [.quadriceps, .adductors], secondary: [.glutes]), // Agachamento Cossaco
        DefaultExerciseMuscles(key: "jump-squat", primary: [.quadriceps], secondary: [.glutes, .calves]), // Agachamento com Salto
        DefaultExerciseMuscles(key: "vertical-leg-press", primary: [.quadriceps], secondary: [.glutes, .adductors], machine: .track), // Leg Press Vertical (Máquina)
        DefaultExerciseMuscles(key: "lunge-bodyweight", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Afundo
        DefaultExerciseMuscles(key: "reverse-lunge-dumbbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Afundo Reverso (Halter)
        DefaultExerciseMuscles(key: "reverse-lunge-barbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Afundo Reverso (Barra)
        DefaultExerciseMuscles(key: "reverse-lunge-smith", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Afundo Reverso (Smith)
        DefaultExerciseMuscles(key: "lateral-lunge-dumbbell", primary: [.quadriceps, .adductors], secondary: [.glutes]), // Afundo Lateral (Halter)
        DefaultExerciseMuscles(key: "walking-lunge-bodyweight", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Passada
        DefaultExerciseMuscles(key: "step-up-bodyweight", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Subida no Banco
        DefaultExerciseMuscles(key: "step-up-barbell", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .adductors]), // Subida no Banco (Barra)
        DefaultExerciseMuscles(key: "lying-leg-curl", primary: [.hamstrings], secondary: [.calves], machine: .plates), // Mesa Flexora (Máquina)
        DefaultExerciseMuscles(key: "seated-leg-curl", primary: [.hamstrings], secondary: [.calves], machine: .plates), // Cadeira Flexora (Máquina)
        DefaultExerciseMuscles(key: "standing-leg-curl", primary: [.hamstrings], secondary: [.calves], machine: .plates), // Flexora Unilateral em Pé (Máquina)
        DefaultExerciseMuscles(key: "romanian-deadlift-barbell", primary: [.hamstrings, .glutes], secondary: [.lowerBack]), // Stiff (Barra)
        DefaultExerciseMuscles(key: "romanian-deadlift-dumbbell", primary: [.hamstrings, .glutes], secondary: [.lowerBack]), // Stiff (Halter)
        DefaultExerciseMuscles(key: "romanian-deadlift-smith", primary: [.hamstrings, .glutes], secondary: [.lowerBack]), // Stiff (Smith)
        DefaultExerciseMuscles(key: "single-leg-romanian-deadlift-dumbbell", primary: [.hamstrings, .glutes], secondary: [.lowerBack]), // Stiff Unilateral (Halter)
        DefaultExerciseMuscles(key: "rdl-barbell", primary: [.hamstrings, .glutes], secondary: [.lowerBack]), // Levantamento Terra Romeno (Barra)
        DefaultExerciseMuscles(key: "good-morning", primary: [.hamstrings, .lowerBack], secondary: [.glutes]), // Good Morning (Barra)
        DefaultExerciseMuscles(key: "good-morning-smith", primary: [.hamstrings, .lowerBack], secondary: [.glutes]), // Good Morning (Smith)
        DefaultExerciseMuscles(key: "nordic-curl", primary: [.hamstrings], secondary: [.calves]), // Flexão Nórdica
        DefaultExerciseMuscles(key: "single-leg-lying-leg-curl", primary: [.hamstrings], secondary: [.calves], machine: .plates), // Mesa Flexora Unilateral (Máquina)
        DefaultExerciseMuscles(key: "single-leg-seated-leg-curl", primary: [.hamstrings], secondary: [.calves], machine: .plates), // Cadeira Flexora Unilateral (Máquina)
        DefaultExerciseMuscles(key: "kneeling-leg-curl", primary: [.hamstrings], secondary: [.calves], machine: .plates), // Flexora Ajoelhada (Máquina)
        DefaultExerciseMuscles(key: "lying-leg-curl-dumbbell", primary: [.hamstrings], secondary: [.calves]), // Mesa Flexora (Halter)
        DefaultExerciseMuscles(key: "standing-leg-curl-cable", primary: [.hamstrings], secondary: [.calves]), // Flexora em Pé (Polia)
        DefaultExerciseMuscles(key: "stability-ball-leg-curl", primary: [.hamstrings], secondary: [.glutes]), // Flexora na Bola Suíça
        DefaultExerciseMuscles(key: "romanian-deadlift-kettlebell", primary: [.hamstrings, .glutes], secondary: [.lowerBack]), // Stiff (Kettlebell)
        DefaultExerciseMuscles(key: "glute-ham-raise", primary: [.hamstrings, .glutes], secondary: [.lowerBack, .calves], machine: .ghd), // Glute Ham Raise (Máquina)
        DefaultExerciseMuscles(key: "hip-thrust-barbell", primary: [.glutes], secondary: [.hamstrings]), // Elevação Pélvica (Barra)
        DefaultExerciseMuscles(key: "hip-thrust-machine", primary: [.glutes], secondary: [.hamstrings], machine: .lever), // Elevação Pélvica (Máquina)
        DefaultExerciseMuscles(key: "hip-thrust-smith", primary: [.glutes], secondary: [.hamstrings]), // Elevação Pélvica (Smith)
        DefaultExerciseMuscles(key: "glute-bridge", primary: [.glutes], secondary: [.hamstrings]), // Ponte de Glúteo
        DefaultExerciseMuscles(key: "cable-kickback", primary: [.glutes], secondary: [.hamstrings]), // Glúteo Coice (Polia)
        DefaultExerciseMuscles(key: "glute-kickback-machine", primary: [.glutes], secondary: [.hamstrings], machine: .plates), // Glúteo Coice (Máquina)
        DefaultExerciseMuscles(key: "hip-abduction-machine", primary: [.gluteusMedius], secondary: [.glutes], machine: .plates), // Cadeira Abdutora (Máquina)
        DefaultExerciseMuscles(key: "hip-abduction-cable", primary: [.gluteusMedius], secondary: [.glutes]), // Abdução de Quadril (Polia)
        DefaultExerciseMuscles(key: "hip-abduction-band", primary: [.gluteusMedius], secondary: [.glutes]), // Abdução de Quadril (Elástico)
        DefaultExerciseMuscles(key: "lateral-band-walk", primary: [.gluteusMedius], secondary: [.glutes]), // Caminhada Lateral (Elástico)
        DefaultExerciseMuscles(key: "sumo-squat-dumbbell", primary: [.glutes, .adductors], secondary: [.quadriceps]), // Agachamento Sumô (Halter)
        DefaultExerciseMuscles(key: "sumo-deadlift", primary: [.glutes, .adductors, .hamstrings], secondary: [.quadriceps, .lowerBack]), // Levantamento Terra Sumô (Barra)
        DefaultExerciseMuscles(key: "hip-thrust-dumbbell", primary: [.glutes], secondary: [.hamstrings]), // Elevação Pélvica (Halter)
        DefaultExerciseMuscles(key: "single-leg-hip-thrust", primary: [.glutes], secondary: [.hamstrings]), // Elevação Pélvica Unilateral
        DefaultExerciseMuscles(key: "single-leg-hip-thrust-machine", primary: [.glutes], secondary: [.hamstrings], machine: .lever), // Elevação Pélvica Unilateral (Máquina)
        DefaultExerciseMuscles(key: "glute-bridge-barbell", primary: [.glutes], secondary: [.hamstrings]), // Ponte de Glúteo (Barra)
        DefaultExerciseMuscles(key: "single-leg-glute-bridge", primary: [.glutes], secondary: [.hamstrings]), // Ponte de Glúteo Unilateral
        DefaultExerciseMuscles(key: "quadruped-kickback", primary: [.glutes], secondary: [.hamstrings]), // Glúteo Quatro Apoios
        DefaultExerciseMuscles(key: "glute-kickback-smith", primary: [.glutes], secondary: [.hamstrings]), // Glúteo Coice (Smith)
        DefaultExerciseMuscles(key: "reverse-hyperextension", primary: [.glutes], secondary: [.lowerBack, .hamstrings], machine: .lever), // Hiperextensão Reversa (Máquina)
        DefaultExerciseMuscles(key: "cable-pull-through", primary: [.glutes], secondary: [.hamstrings]), // Pull Through (Polia)
        DefaultExerciseMuscles(key: "reverse-hack-squat", primary: [.glutes], secondary: [.hamstrings, .quadriceps], machine: .track), // Agachamento Hack Invertido (Máquina)
        DefaultExerciseMuscles(key: "sumo-squat-kettlebell", primary: [.glutes, .adductors], secondary: [.quadriceps]), // Agachamento Sumô (Kettlebell)
        DefaultExerciseMuscles(key: "sumo-squat-smith", primary: [.glutes, .adductors], secondary: [.quadriceps]), // Agachamento Sumô (Smith)
        DefaultExerciseMuscles(key: "curtsy-lunge-dumbbell", primary: [.gluteusMedius, .glutes], secondary: [.quadriceps]), // Afundo Cruzado (Halter)
        DefaultExerciseMuscles(key: "standing-hip-abduction-machine", primary: [.gluteusMedius], secondary: [.glutes], machine: .plates), // Abdução de Quadril em Pé (Máquina)
        DefaultExerciseMuscles(key: "side-lying-hip-abduction", primary: [.gluteusMedius], secondary: [.glutes]), // Abdução Lateral Deitado
        DefaultExerciseMuscles(key: "clamshell-band", primary: [.gluteusMedius], secondary: [.glutes]), // Abdução Ostra (Elástico)
        DefaultExerciseMuscles(key: "fire-hydrant", primary: [.gluteusMedius], secondary: [.glutes]), // Hidrante
        DefaultExerciseMuscles(key: "hip-adduction-machine", primary: [.adductors], secondary: [], machine: .plates), // Cadeira Adutora (Máquina)
        DefaultExerciseMuscles(key: "hip-adduction-cable", primary: [.adductors], secondary: []), // Adução de Quadril (Polia)
        DefaultExerciseMuscles(key: "hip-adduction-band", primary: [.adductors], secondary: []), // Adução de Quadril (Elástico)
        DefaultExerciseMuscles(key: "side-lying-hip-adduction", primary: [.adductors], secondary: []), // Adução Lateral Deitado
        DefaultExerciseMuscles(key: "standing-calf-raise", primary: [.calves], secondary: [], machine: .plates), // Panturrilha em Pé (Máquina)
        DefaultExerciseMuscles(key: "calf-raise-smith", primary: [.calves], secondary: []), // Panturrilha em Pé (Smith)
        DefaultExerciseMuscles(key: "seated-calf-raise", primary: [.calves], secondary: [], machine: .lever), // Panturrilha Sentado (Máquina)
        DefaultExerciseMuscles(key: "leg-press-calf-raise", primary: [.calves], secondary: [], machine: .track), // Panturrilha no Leg Press (Máquina)
        DefaultExerciseMuscles(key: "single-leg-calf-raise-dumbbell", primary: [.calves], secondary: []), // Panturrilha Unilateral (Halter)
        DefaultExerciseMuscles(key: "standing-calf-raise-bodyweight", primary: [.calves], secondary: []), // Panturrilha em Pé
        DefaultExerciseMuscles(key: "standing-calf-raise-dumbbell", primary: [.calves], secondary: []), // Panturrilha em Pé (Halter)
        DefaultExerciseMuscles(key: "standing-calf-raise-barbell", primary: [.calves], secondary: []), // Panturrilha em Pé (Barra)
        DefaultExerciseMuscles(key: "seated-calf-raise-dumbbell", primary: [.calves], secondary: []), // Panturrilha Sentado (Halter)
        DefaultExerciseMuscles(key: "hack-squat-calf-raise", primary: [.calves], secondary: [], machine: .track), // Panturrilha no Hack (Máquina)
        DefaultExerciseMuscles(key: "donkey-calf-raise", primary: [.calves], secondary: [], machine: .lever), // Panturrilha Burrico (Máquina)
        DefaultExerciseMuscles(key: "tibialis-raise", primary: [.tibialis], secondary: []), // Elevação de Ponta dos Pés
        DefaultExerciseMuscles(key: "kettlebell-swing", primary: [.glutes, .hamstrings], secondary: [.lowerBack, .abs]), // Kettlebell Swing
        DefaultExerciseMuscles(key: "kettlebell-snatch", primary: [.glutes, .hamstrings, .quadriceps], secondary: [.frontDelts, .traps, .lowerBack]), // Arranco (Kettlebell)
        DefaultExerciseMuscles(key: "turkish-get-up", primary: [.abs, .frontDelts], secondary: [.obliques, .glutes, .triceps]), // Levantamento Turco (Kettlebell)
        DefaultExerciseMuscles(key: "thruster-barbell", primary: [.quadriceps, .frontDelts], secondary: [.glutes, .triceps]), // Thruster (Barra)
        DefaultExerciseMuscles(key: "thruster-dumbbell", primary: [.quadriceps, .frontDelts], secondary: [.glutes, .triceps]), // Thruster (Halter)
        DefaultExerciseMuscles(key: "power-clean", primary: [.glutes, .hamstrings, .quadriceps], secondary: [.traps, .lowerBack, .calves]), // Power Clean (Barra)
        DefaultExerciseMuscles(key: "burpee", primary: [.quadriceps, .chest], secondary: [.glutes, .frontDelts, .triceps]), // Burpee
        DefaultExerciseMuscles(key: "clean-and-jerk", primary: [.glutes, .quadriceps, .frontDelts], secondary: [.hamstrings, .traps, .triceps]), // Arremesso (Barra)
        DefaultExerciseMuscles(key: "snatch-barbell", primary: [.glutes, .hamstrings, .quadriceps], secondary: [.frontDelts, .traps, .lowerBack]), // Arranco (Barra)
        DefaultExerciseMuscles(key: "snatch-dumbbell", primary: [.glutes, .hamstrings, .quadriceps], secondary: [.frontDelts, .traps, .lowerBack]), // Arranco (Halter)
        DefaultExerciseMuscles(key: "kettlebell-clean", primary: [.glutes, .hamstrings, .quadriceps], secondary: [.traps, .lowerBack, .calves]), // Clean (Kettlebell)
        DefaultExerciseMuscles(key: "thruster-kettlebell", primary: [.quadriceps, .frontDelts], secondary: [.glutes, .triceps]), // Thruster (Kettlebell)
        DefaultExerciseMuscles(key: "single-arm-kettlebell-swing", primary: [.glutes, .hamstrings], secondary: [.lowerBack, .abs]), // Kettlebell Swing Unilateral
    ]
}
