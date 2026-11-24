import SwiftUI

/// The kind of machine of a library exercise: its icon, its name, "Tipo de máquina" (for Graviton, what
/// its kg means) and the ⓘ. The whole row opens the "Tipos de máquina" sheet.
struct MachineTypeRow: View {
    let machine: MachineType
    let action: @MainActor () -> Void

    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 60

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(machine == .graviton ? .eqPesoDoCorpo : .eqMaquina, iconSize: 17, side: 36, cornerRadius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text(machine.displayName)
                        .scaledFont(14, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                    Text(subtitle)
                        .scaledFont(12)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The prototype's rows keep 20 more between the text and what is on its right.
                .padding(.trailing, 20)
                AppIcon(.info, size: 20)
                    .foregroundStyle(Theme.Colors.mediumText)
            }
            .frame(minHeight: minHeight - 24)
            .cardStyle(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14), cornerRadius: 17)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(machine.displayName)), \(Text(subtitle))"))
        .accessibilityHint(Text("Explica os tipos de máquina"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("exercise.machine")
    }

    private var subtitle: LocalizedStringResource {
        machine == .graviton ? "Mais kg = mais ajuda. Menos kg é progresso." : "Tipo de máquina"
    }
}
