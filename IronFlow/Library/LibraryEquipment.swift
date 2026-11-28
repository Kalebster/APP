import Foundation

/// A button of the EQUIPAMENTO row of a base exercise (the base list approved by the owner on 26/11/2026):
/// the ten general ones every base shows, in the standard order, and two specific ones that only the bases
/// where they are common show (Barra W right after Barra, Graviton right after Peso do corpo).
///
/// Library data only, never stored: an exercise's combination is found by its stable key
/// (`Exercise.libraryKey`). The order of the cases is the standard order.
enum LibraryEquipment: String, CaseIterable, Decodable, Sendable {
    case barbell
    /// Barra W (EZ bar): only in Rosca Direta, Rosca Scott, Rosca Spider, Rosca Invertida, Tríceps Francês
    /// and Tríceps Testa.
    case ezBar
    case dumbbell
    case machine
    /// An iso-lateral machine is always a machine: it uses the machine's filter and icon.
    case isoLateralMachine
    case smith
    case cable
    case band
    case kettlebell
    case plate
    case bodyweight
    /// Graviton (counterweight): only in Barra Fixa, Peito na Paralela and Tríceps na Paralela.
    case graviton

    /// The name on the button.
    var displayName: LocalizedStringResource {
        switch self {
        case .barbell: "Barra"
        case .ezBar: "Barra W"
        case .dumbbell: "Halteres"
        case .machine: "Máquina"
        case .isoLateralMachine: "Máquina iso-lateral"
        case .smith: "Smith"
        case .cable: "Polia"
        case .band: "Elástico"
        case .kettlebell: "Kettlebell"
        case .plate: "Anilha"
        case .bodyweight: "Peso do corpo"
        case .graviton: "Graviton"
        }
    }

    /// The equipment of the equipment filter and of the icon: Barra W is a Barra; Máquina iso-lateral and
    /// Graviton are a Máquina.
    var equipment: Equipment {
        switch self {
        case .barbell, .ezBar: .barbell
        case .dumbbell: .dumbbell
        case .machine, .isoLateralMachine, .graviton: .machine
        case .smith: .smith
        case .cable: .cable
        case .band: .band
        case .kettlebell: .kettlebell
        case .plate: .plate
        case .bodyweight: .bodyweight
        }
    }
}
