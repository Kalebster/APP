import SwiftUI

/// An SF Symbol in light blue on a dark blue rounded square: the icons of the Início summary cards and
/// of the Treinos rows. Decorative: the text next to it says what it is.
struct IconTile: View {
    let systemImage: String
    let cornerRadius: CGFloat
    /// The side of the square; set in points of the default text size, it grows with the text.
    @ScaledMetric private var side: CGFloat

    init(systemImage: String, side: CGFloat, cornerRadius: CGFloat) {
        self.systemImage = systemImage
        self.cornerRadius = cornerRadius
        _side = ScaledMetric(wrappedValue: side, relativeTo: .body)
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: side * 0.48, weight: .semibold))
            .foregroundStyle(Theme.Colors.lightAccent)
            .frame(width: side, height: side)
            .background(Theme.Colors.iconTileBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// An icon and its title close together, 4 points apart: the session clock, "+ Adicionar série".
struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

/// "‹ Treinos": the blue back of the screens that hide the navigation bar for the model's own top row,
/// the workout editor and the weekly plan. Text 15, as in the model.
struct TextBackButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .scaledFont(15, weight: .semibold)
                Text(title)
                    .scaledFont(15)
            }
            .foregroundStyle(Theme.Colors.lightAccent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A small capsule on the highlight: "Programado" on today's workout in the Início, "HOJE" on the card
/// of today's workout in Treinos.
struct CapsuleBadge: View {
    let text: String
    let weight: Font.Weight
    let tracking: CGFloat
    let padding: EdgeInsets
    /// In points of the default text size: 10, or 9 on the rows of the sheets.
    var size: CGFloat = 10

    var body: some View {
        Text(verbatim: text)
            .scaledFont(size, weight: weight)
            .tracking(tracking)
            .foregroundStyle(Theme.Colors.highlightText)
            .lineLimit(1)
            .padding(padding)
            .background(Theme.Colors.highlightBadge, in: Capsule())
    }
}

/// Lays its subviews out in rows, left to right, and starts a new row when the next one does not fit:
/// the muscle group chips of today's workout. A subview wider than a row wraps its own text.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(of: subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map { row in row.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(row.count - 1, 0)) }.max() ?? 0
        let height = rows.reduce(0) { $0 + ($1.map(\.height).max() ?? 0) } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var index = 0
        var y = bounds.minY
        for row in rows(of: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for size in row {
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += (row.map(\.height).max() ?? 0) + spacing
        }
    }

    /// The size of each subview, grouped in rows that fit `maxWidth`.
    private func rows(of subviews: Subviews, maxWidth: CGFloat) -> [[CGSize]] {
        var rows: [[CGSize]] = []
        var row: [CGSize] = []
        var rowWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let needed = row.isEmpty ? size.width : rowWidth + spacing + size.width
            if !row.isEmpty && needed > maxWidth {
                rows.append(row)
                row = [size]
                rowWidth = size.width
            } else {
                row.append(size)
                rowWidth = needed
            }
        }
        if !row.isEmpty {
            rows.append(row)
        }
        return rows
    }
}

/// A section title with an action on the right in light blue, such as "Personalizar" or "Ver tudo".
/// The action keeps a touch area of at least 44 points.
struct SectionHeader: View {
    let title: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let actionIdentifier: String
    let action: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            SectionTitle(title)
            Spacer(minLength: 8)
            Button(action: action) {
                Text(actionTitle)
                    .scaledFont(13, weight: .semibold)
                    .foregroundStyle(Theme.Colors.lightAccent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(actionIdentifier)
        }
    }
}
