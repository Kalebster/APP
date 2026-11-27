import Foundation

/// What an exercise is done with.
///
/// The raw value is a stable key: the library names the equipment of each built-in exercise with it, and
/// an exercise of the user's own stores it (`Exercise.equipmentRaw`, none being "Outro"). `displayName`
/// is the name shown to the user. The order of the cases is the order of the equipment filters.
enum Equipment: String, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case machine
    case cable
    case smith
    case bodyweight
    case kettlebell
    case band
    case plate

    var displayName: LocalizedStringResource {
        switch self {
        case .barbell: "Barra"
        case .dumbbell: "Halteres"
        case .machine: "Máquina"
        case .cable: "Polia"
        case .smith: "Smith"
        case .bodyweight: "Peso do corpo"
        case .kettlebell: "Kettlebell"
        case .band: "Elástico"
        case .plate: "Anilha"
        }
    }
}
