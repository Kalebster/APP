import Foundation

/// Muscle group of an exercise.
///
/// The raw value is the stable storage key and never depends on the interface
/// language; `displayName` provides the name shown to the user.
enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case forearms
    case quadriceps
    case hamstrings
    case glutes
    case calves
    case abs
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
        case .back: "Costas"
        case .shoulders: "Ombros"
        case .biceps: "Bíceps"
        case .triceps: "Tríceps"
        case .forearms: "Antebraços"
        case .quadriceps: "Quadríceps"
        case .hamstrings: "Posteriores de coxa"
        case .glutes: "Glúteos"
        case .calves: "Panturrilhas"
        case .abs: "Abdômen"
        case .fullBody: "Corpo inteiro"
        case .other: "Outro"
        }
    }
}
