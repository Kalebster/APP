import Foundation

/// A muscle of the muscle map: the 21 muscles the library names as the main or secondary muscles of
/// an exercise, drawn on the body figure of the exercise screen. The order is the order of the approved
/// prototype's legend; `bodyOrder` is the order of the choices, from the top of the body down.
///
/// The raw value is the stable storage key of the muscles an exercise of the user's own chooses
/// (`Exercise.primaryMuscleKeys`): it never changes, whatever the name shown.
enum Muscle: String, CaseIterable, Decodable, Sendable {
    case chest
    case frontDelts
    case sideDelts
    case rearDelts
    case biceps
    case triceps
    case forearms
    case abs
    case obliques
    case quadriceps
    case adductors
    case tibialis
    case traps
    case upperBack
    case rotatorCuff
    case lats
    case lowerBack
    case glutes
    case gluteusMedius
    case hamstrings
    case calves

    var displayName: LocalizedStringResource {
        switch self {
        case .chest: "Peitoral"
        case .frontDelts: "Deltoide anterior"
        case .sideDelts: "Deltoide lateral"
        case .rearDelts: "Deltoide posterior"
        case .biceps: "Bíceps"
        case .triceps: "Tríceps"
        case .forearms: "Antebraços"
        case .abs: "Abdômen"
        case .obliques: "Oblíquos"
        case .quadriceps: "Quadríceps"
        case .adductors: "Adutores"
        case .tibialis: "Tibial anterior"
        case .traps: "Trapézio"
        case .upperBack: "Costas superiores"
        case .rotatorCuff: "Manguito rotador"
        case .lats: "Dorsais"
        case .lowerBack: "Lombar"
        case .glutes: "Glúteos"
        case .gluteusMedius: "Glúteo médio"
        case .hamstrings: "Posteriores de coxa"
        case .calves: "Panturrilhas"
        }
    }

    /// The muscles from the top of the body down, as the choices of an exercise of the user's own show
    /// them (the prototype's `MUS_ORDER`).
    static let bodyOrder: [Muscle] = [
        .traps, .frontDelts, .sideDelts, .rearDelts, .rotatorCuff, .chest, .upperBack, .lats, .biceps, .triceps,
        .forearms, .abs, .obliques, .lowerBack, .glutes, .gluteusMedius, .adductors, .quadriceps, .hamstrings,
        .tibialis, .calves,
    ]
}

/// The kind of machine of an exercise done on one, shown on the exercise screen and explained in the
/// "Tipos de máquina" sheet, in this order.
///
/// The raw value is the stable storage key of the kind an exercise of the user's own chooses
/// (`Exercise.machineTypeRaw`): it never changes, whatever the name shown.
enum MachineType: String, CaseIterable, Decodable, Sendable {
    /// A stack of plates, chosen with the pin.
    case plates
    /// Plates loaded on an arm that turns on an axis.
    case lever
    /// Plates loaded on a platform that runs on a track, as in the leg press.
    case track
    /// A counterweight that helps: more kg makes the exercise easier.
    case graviton
    /// A bench with a foot support; the kg is the extra weight held.
    case ghd

    var displayName: LocalizedStringResource {
        switch self {
        case .plates: "Máquina de placas"
        case .lever: "Articulada (anilhas)"
        case .track: "Trilho (anilhas)"
        case .graviton: "Graviton (contrapeso)"
        case .ghd: "Banco GHD"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .plates: "O peso é uma pilha de placas, escolhido com o pino."
        case .lever: "Você coloca anilhas e o braço da máquina gira num eixo."
        case .track: "Você coloca anilhas e a plataforma corre num trilho, como no leg press."
        case .graviton: "O peso ajuda você a subir: mais kg deixa o exercício mais fácil."
        case .ghd: "Banco com apoio para os pés. O kg é o peso extra que você segura."
        }
    }
}
