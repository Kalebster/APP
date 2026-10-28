import SwiftUI

/// The parts every sheet of the Início and Treinos models shares, in the model's points at the default
/// text size: the title (17 heavy) and its explanation (13), the section titles (10 heavy, spaced 1,8),
/// the buttons (46 high, corners of 13, text 15 bold), and a height that is that of the content.
enum SheetStyle {
    /// The space above the title, below the drag indicator.
    static let topPadding: CGFloat = 20
    /// The space below the last block of the content.
    static let bottomPadding: CGFloat = 12
}

/// A sheet's title and the line that explains it.
struct SheetHeader: View {
    let title: Text
    let explanation: Text?
    /// The accessibility identifier of the explanation, for the tests that read it.
    let explanationIdentifier: String?

    init(_ title: Text, explanation: Text? = nil, explanationIdentifier: String? = nil) {
        self.title = title
        self.explanation = explanation
        self.explanationIdentifier = explanationIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
                .scaledFont(17, weight: .heavy)
                .foregroundStyle(Theme.Colors.brightText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let explanation {
                explanation
                    .scaledFont(13)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(explanationIdentifier ?? "")
            }
        }
    }
}

/// A section title inside a sheet: "TREINO", "SEXO", "ÚLTIMOS REGISTROS".
struct SheetSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        SectionTitle(title, size: 10, tracking: 1.8)
            .foregroundStyle(Theme.Colors.secondaryText)
    }
}

/// A sheet's full-width button: blue for the action ("Salvar", "Pronto"), gray for leaving
/// ("Cancelar", "Fechar").
struct SheetButton: View {
    enum Kind {
        case primary
        case secondary
    }

    let title: Text
    let kind: Kind
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 46

    init(_ title: Text, kind: Kind, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            title
                .scaledFont(15, weight: .bold)
                .foregroundStyle(kind == .primary ? Color.white : Theme.Colors.brightText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(
                    kind == .primary ? Color.accentColor : Theme.Colors.setFieldBackground,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A sheet as tall as what it shows: its scrolling content and the buttons kept at its bottom (when it
/// has them) are measured, and the sheet takes their height, never leaving empty space below. Content
/// taller than the screen (the largest text sizes, a long calculator) gets the tallest sheet and
/// scrolls, so nothing is cut.
struct FittedSheet<Content: View, Bottom: View>: View {
    private let content: Content
    private let bottom: Bottom

    @State private var contentHeight: CGFloat?
    @State private var bottomHeight: CGFloat?

    init(@ViewBuilder content: () -> Content, @ViewBuilder bottom: () -> Bottom) {
        self.content = content()
        self.bottom = bottom()
    }

    /// A sheet whose buttons scroll with its content.
    init(@ViewBuilder content: () -> Content) where Bottom == EmptyView {
        self.content = content()
        bottom = EmptyView()
        _bottomHeight = State(initialValue: 0)
    }

    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottom
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    bottomHeight = height
                }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.cardBackground)
    }

    /// The content's height once it is measured; the system keeps it within the screen. Until then, the
    /// middle height.
    private var detents: Set<PresentationDetent> {
        guard let contentHeight, let bottomHeight else { return [.medium] }
        return [.height((contentHeight + bottomHeight).rounded(.up))]
    }
}

extension View {
    /// The bar of buttons at the bottom of a sheet: the sheet's background, a margin around them.
    func sheetButtonBar() -> some View {
        padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Theme.Colors.cardBackground)
    }

    /// The margins of a sheet's scrolling content.
    func sheetContentPadding() -> some View {
        padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, SheetStyle.topPadding)
            .padding(.bottom, SheetStyle.bottomPadding)
    }
}
