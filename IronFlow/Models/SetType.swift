import Foundation

/// The kind of a set: warm-up, feeder, working or failure.
///
/// The raw value is the stable storage key and never depends on the interface language;
/// `displayName` provides the name shown to the user. The order of the cases is the order shown.
enum SetType: String, CaseIterable, Sendable {
    case warmup
    case feeder
    case working
    case failure

    /// Creates a type from its storage key.
    ///
    /// Unknown keys can only come from data written by a newer app version; they are read as
    /// `.working`, the type of every set recorded before set types existed.
    init(storageKey: String) {
        self = SetType(rawValue: storageKey) ?? .working
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .warmup: "Aquecimento"
        case .feeder: "Preparatória"
        case .working: "Válida"
        case .failure: "Falha"
        }
    }

    /// What the type means, as the set type sheet explains it.
    var explanation: LocalizedStringResource {
        switch self {
        case .warmup: "Leve, para aquecer. Não conta nos kg levantados."
        case .feeder: "Mais pesada, para chegar pronto na carga. Não conta nos kg levantados."
        case .working: "A série de trabalho. Conta nos kg levantados."
        case .failure: "Até não conseguir mais repetições. Conta nos kg levantados."
        }
    }

    /// Whether the set's load × repetitions count in the load lifted ("kg levantados"). Warm-up and
    /// feeder sets prepare the work and do not.
    var countsTowardLiftedLoad: Bool {
        switch self {
        case .working, .failure: true
        case .warmup, .feeder: false
        }
    }

    /// Whether the set's repetition target makes up the exercise's target in the session ("meta 8–12
    /// reps"). Warm-up and feeder sets have targets of their own, outside the work, and do not.
    var countsTowardTarget: Bool {
        switch self {
        case .working, .failure: true
        case .warmup, .feeder: false
        }
    }

    /// The type of a new set copied from a set of this type: a copy of a warm-up or feeder set is a
    /// working set, the others keep their type.
    var typeOfCopy: SetType {
        switch self {
        case .warmup, .feeder: .working
        case .working, .failure: self
        }
    }
}
