import SwiftUI

/// Chooses which indicators the Home quick summary shows (up to `HomeSummary.maxVisibleMetrics`),
/// in the order they are chosen. Every change is kept right away in the app preferences.
struct SummaryCustomizeSheet: View {
    @Binding var storedMetrics: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let selection = HomeSummary.metrics(fromStored: storedMetrics)

        NavigationStack {
            List {
                Section {
                    ForEach(SummaryMetric.allCases) { metric in
                        let position = selection.firstIndex(of: metric)
                        Button {
                            storedMetrics = HomeSummary.storedValue(for: HomeSummary.toggled(metric, in: selection))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: metric.systemImage)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                                Text(metric.title)
                                Spacer(minLength: 0)
                                if let position {
                                    Text((position + 1).formatted())
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.accentColor, in: Circle())
                                } else {
                                    Image(systemName: "circle")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }
                            }
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle())
                        }
                        .disabled(position == nil && selection.count >= HomeSummary.maxVisibleMetrics)
                        .accessibilityAddTraits(position != nil ? .isSelected : [])
                        .accessibilityIdentifier("customize.\(metric.rawValue)")
                    }
                } footer: {
                    Text("Escolha até \(HomeSummary.maxVisibleMetrics) indicadores. A ordem na tela segue a ordem de escolha.")
                }
            }
            .navigationTitle("Personalizar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        dismiss()
                    }
                    .accessibilityIdentifier("customize.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
