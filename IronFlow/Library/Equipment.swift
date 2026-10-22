import Foundation

/// What a built-in exercise is done with.
///
/// Library data only, never stored: the raw value is a stable key of the library and `displayName`
/// the name shown to the user. The order of the cases is the order of the equipment filters.
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
