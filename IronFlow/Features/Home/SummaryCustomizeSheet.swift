import SwiftData
import SwiftUI

/// "Personalizar resumo": the ten indicators in two groups, Treino and Corpo, each with its icon, its
/// name, its value and the order it was chosen in. Up to `HomeSummary.maxVisibleMetrics` are chosen,
/// shown on the Início in that order; with that many, the others are dimmed and unavailable. Every tap
/// is kept right away in the app preferences, so the Início follows it at once.
struct SummaryCustomizeSheet: View {
    @Binding var storedMetrics: String?
    /// What the Início already holds, for the values of the rows.
    let known: SummaryIndicatorLoader.Known
    let now: Date
    let calendar: Calendar

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// The value of every indicator, read once when the sheet opens.
    @State private var values: [SummaryMetric: IndicatorValue] = [:]
    @State private var errorMessage: String?
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 50
    @ScaledMetric(relativeTo: .body) private var badgeSide: CGFloat = 28

    var body: some View {
        let selection = HomeSummary.metrics(fromStored: storedMetrics)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personalizar resumo")
                        .scaledFont(20, weight: .heavy)
                        .accessibilityAddTraits(.isHeader)
                    Text("Escolha até \(HomeSummary.maxVisibleMetrics). Eles aparecem no Início na ordem em que você marcar.")
                        .scaledFont(15)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let errorMessage {
                    Text(verbatim: errorMessage)
                        .scaledFont(13)
                        .foregroundStyle(Theme.Colors.failureSet)
                        .accessibilityIdentifier("customize.error")
                }
                ForEach(SummaryMetric.Category.allCases, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(LocalizedStringKey(String(localized: category.title)))
                            .foregroundStyle(Theme.Colors.secondaryText)
                        rows(SummaryMetric.allCases.filter { $0.category == category }, selection: selection)
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, Theme.Metrics.screenPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                dismiss()
            } label: {
                Text("Pronto")
                    .scaledFont(16, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: buttonHeight)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("customize.done")
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.vertical, 8)
            .background(Theme.Colors.cardBackground)
        }
        .onAppear(perform: load)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.cardBackground)
    }

    /// The indicators of a group in one block, a line between them.
    private func rows(_ metrics: [SummaryMetric], selection: [SummaryMetric]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element) { index, metric in
                if index > 0 {
                    Theme.Colors.rowSeparator
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                row(metric, selection: selection)
            }
        }
        .background(Theme.Colors.screenBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func row(_ metric: SummaryMetric, selection: [SummaryMetric]) -> some View {
        let position = selection.firstIndex(of: metric)
        let isAvailable = position != nil || selection.count < HomeSummary.maxVisibleMetrics
        let line = values[metric]?.line ?? ""
        return Button {
            storedMetrics = HomeSummary.storedValue(for: HomeSummary.toggled(metric, in: selection))
        } label: {
            HStack(spacing: 14) {
                IconTile(systemImage: metric.systemImage, side: 36, cornerRadius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.title)
                        .scaledFont(16, weight: .bold)
                        .foregroundStyle(Theme.Colors.brightText)
                    Text(verbatim: line)
                        .scaledFont(12)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                orderMark(position)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .opacity(isAvailable ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: metric.title)), \(line)"))
        .accessibilityValue(Text(verbatim: position.map { "\($0 + 1)º" } ?? ""))
        .accessibilityAddTraits(position != nil ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("customize.\(metric.rawValue)")
    }

    /// The order the indicator was chosen in, in a blue circle; an empty circle when it is not chosen.
    @ViewBuilder
    private func orderMark(_ position: Int?) -> some View {
        if let position {
            Text(verbatim: "\(position + 1)")
                .scaledFont(14, weight: .bold)
                .foregroundStyle(.white)
                .frame(width: badgeSide, height: badgeSide)
                .background(Color.accentColor, in: Circle())
        } else {
            Circle()
                .strokeBorder(Theme.Colors.controlBorder, lineWidth: 2)
                .frame(width: badgeSide, height: badgeSide)
        }
    }

    /// Reads the value of every indicator, each from its own period.
    private func load() {
        do {
            values = try SummaryIndicatorLoader(context: context, now: now, calendar: calendar)
                .values(for: SummaryMetric.allCases, known: known)
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
