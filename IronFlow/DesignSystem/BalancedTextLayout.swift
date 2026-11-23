import SwiftUI

/// Lays a text out with its lines about the same length, as the prototype's `text-wrap: balance`: when
/// the text needs more than one line at the width offered, it gets the narrowest width that keeps the
/// same number of lines, found by halving. The layout itself takes the whole width offered. For a title
/// of one line it changes nothing.
struct BalancedTextLayout: Layout {
    struct Cache {
        var offered: CGFloat?
        var balanced: CGFloat?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let width = balancedWidth(of: text, offered: proposal.width, cache: &cache)
        let size = text.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard let text = subviews.first else { return }
        let width = balancedWidth(of: text, offered: bounds.width, cache: &cache)
        text.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: width, height: nil))
    }

    private func balancedWidth(of text: LayoutSubview, offered: CGFloat?, cache: inout Cache) -> CGFloat? {
        guard let offered, offered.isFinite, offered > 0 else { return offered }
        if cache.offered == offered, let balanced = cache.balanced {
            return balanced
        }
        let height = text.sizeThatFits(ProposedViewSize(width: offered, height: nil)).height
        let oneLine = text.sizeThatFits(ProposedViewSize(width: nil, height: nil))
        var balanced = offered
        if oneLine.width > offered {
            // The narrowest width with the same height (the same number of lines), within half a point.
            var low: CGFloat = 0
            var high = offered
            while high - low > 0.5 {
                let middle = (low + high) / 2
                if text.sizeThatFits(ProposedViewSize(width: middle, height: nil)).height <= height {
                    high = middle
                } else {
                    low = middle
                }
            }
            balanced = min(offered, high.rounded(.up))
        }
        cache.offered = offered
        cache.balanced = balanced
        return balanced
    }
}
