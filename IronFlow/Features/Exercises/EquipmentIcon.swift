import SwiftUI

/// The icon of an equipment, as in the model: its eq-* icon of the asset catalog. It fills its frame,
/// so the line grows with the icon. Decorative: the text next to it says what it is.
struct EquipmentIcon: View {
    let equipment: Equipment

    var body: some View {
        Image(equipment.icon)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

extension Equipment {
    /// The equipment's icon in the model.
    var icon: ImageResource {
        switch self {
        case .barbell: .eqBarra
        case .dumbbell: .eqHalteres
        case .machine: .eqMaquina
        case .cable: .eqPolia
        case .smith: .eqSmith
        case .bodyweight: .eqPesoDoCorpo
        case .kettlebell: .eqKettlebell
        case .band: .eqElastico
        case .plate: .eqAnilha
        }
    }
}
