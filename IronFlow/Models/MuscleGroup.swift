import Foundation

/// Muscle group of an exercise.
///
/// The raw value is the stable storage key and never depends on the interface
/// language; `displayName` provides the name shown to the user. The order of the cases is the order
/// of the group filters; it can change, the raw values never do.
enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest
    /// "Dorsais". Stored as "back" since the first version, when it was every back exercise ("Costas").
    case back
    case upperBack
    case traps
    case lowerBack
    case shoulders
    case biceps
    case triceps
    case forearms
    case abs
    case quadriceps
    case hamstrings
    case glutes
    case adductors
    case calves
    case fullBody
    case other

    /// Creates a group from its storage key.
    ///
    /// Unknown keys can only come from data written by a newer app version;
    /// they are read as `.other` so that older versions keep working.
    init(storageKey: String) {
        self = MuscleGroup(rawValue: storageKey) ?? .other
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .chest: "Peito"
        case .back: "Dorsais"
        case .upperBack: "Costas superiores"
        case .traps: "Trapézio"
        case .lowerBack: "Lombar"
        case .shoulders: "Ombros"
        case .biceps: "Bíceps"
        case .triceps: "Tríceps"
        case .forearms: "Antebraços"
        case .abs: "Abdômen"
        case .quadriceps: "Quadríceps"
        case .hamstrings: "Posteriores de coxa"
        case .glutes: "Glúteos"
        case .adductors: "Adutores"
        case .calves: "Panturrilhas"
        case .fullBody: "Corpo inteiro"
        case .other: "Outro"
        }
    }
}
