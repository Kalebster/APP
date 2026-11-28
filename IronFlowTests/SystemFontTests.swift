import CoreText
import SwiftUI
import Testing
import UIKit
@testable import IronFlow

/// SF Pro, the system font, is the font of every text of the app (DESIGN.md): no font file ships with
/// the app, the line heights of the model are taken from the font's real height at each size and weight,
/// and the Bold Text setting makes the text heavier with no work of the app's.
@MainActor
struct SystemFontTests {
    /// The size SwiftUI gives `view` on a 3x screen with the default text size, as wide as it needs up to
    /// `width`.
    private func size(of view: some View, width: CGFloat = 300) -> CGSize {
        let controller = UIHostingController(rootView: view.environment(\.displayScale, 3))
        return controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    @Test("No font file ships with the app, and the app registers no font when it opens")
    func noFontFiles() {
        for fileExtension in ["ttf", "otf", "ttc"] {
            #expect(Bundle.main.urls(forResourcesWithExtension: fileExtension, subdirectory: nil)?.isEmpty ?? true, "A .\(fileExtension) file is in the app")
        }
        #expect(Bundle.main.url(forResource: "OFL", withExtension: "txt") == nil, "The Inter license is still in the app")
        let registered = CTFontManagerCopyRegisteredFontDescriptors(.process, true) as NSArray
        #expect(registered.count == 0, "Fonts registered by the app: \(registered.count)")
    }

    @Test("A line takes the system font's own height at its size, the same in the five weights of the app")
    func lineHeightIsTheFonts() {
        for size in [10, 13, 17, 22, 26, 29, 46] as [CGFloat] {
            let regular = SystemFont.lineHeight(size: size, weight: .regular)
            #expect(regular == UIFont.systemFont(ofSize: size).lineHeight)
            #expect(regular > size, "\(size): \(regular)")
            for weight in [Font.Weight.medium, .semibold, .bold, .heavy] {
                let height = SystemFont.lineHeight(size: size, weight: weight)
                #expect(abs(height - regular) < 0.5, "\(size) \(weight): \(height) against \(regular)")
            }
        }
    }

    @Test("A title of 29 at the model's 1,05 loses half of the difference above and below, no line spacing")
    func tightLineHeight() {
        let own = SystemFont.lineHeight(size: 29, weight: .heavy)
        let metrics = LineHeightMetrics(size: 29, weight: .heavy, lineHeight: 1.05, displayScale: 3)
        #expect(abs(metrics.edgePadding - (30.45 - (own * 3).rounded(.up) / 3) / 2) < 0.001)
        #expect(metrics.edgePadding < 0)
        #expect(metrics.lineSpacing == 0)
    }

    @Test("A sheet text of 13 at the model's 1,4 gains half above and below, and all of it between lines")
    func looseLineHeight() {
        let own = SystemFont.lineHeight(size: 13, weight: .regular)
        let metrics = LineHeightMetrics(size: 13, weight: .regular, lineHeight: 1.4, displayScale: 3)
        #expect(abs(metrics.edgePadding - (18.2 - (own * 3).rounded(.up) / 3) / 2) < 0.001)
        // A line of the wrapped text is the model's: the font's own line and the spacing.
        #expect(abs(own + metrics.lineSpacing - 18.2) < 0.001)
        // On a 2x screen the line is rounded to its half points instead.
        let twoX = LineHeightMetrics(size: 13, weight: .regular, lineHeight: 1.4, displayScale: 2)
        #expect(abs(twoX.edgePadding - (18.2 - (own * 2).rounded(.up) / 2) / 2) < 0.001)
    }

    @Test("The WebKit line of the prototype is in whole points, rounded down: 16 for 12 at 1,4, 18 for 13 at 1,4, 13 for the normal line of 11")
    func webKitLine() {
        for (size, lineHeight, line) in [(12, 1.4, 16), (13, 1.4, 18), (11, 1.35, 14), (11, 13.0 / 11, 13)] as [(CGFloat, CGFloat, CGFloat)] {
            let own = SystemFont.lineHeight(size: size, weight: .regular)
            let metrics = LineHeightMetrics(size: size, weight: .regular, lineHeight: lineHeight, displayScale: 3, roundsDown: true)
            #expect(abs(own + metrics.lineSpacing - line) < 0.001 || metrics.lineSpacing == 0, "\(size) at \(lineHeight)")
            #expect(abs(metrics.edgePadding - (line - (own * 3).rounded(.up) / 3) / 2) < 0.001, "\(size) at \(lineHeight)")
        }
    }

    @Test("Laid out by SwiftUI, a text with the WebKit line is as tall as in the prototype")
    func measuredWebKitLines() {
        // A note of 12 at 1,4 in two lines: 16 each, as the prototype's WebKit lays it out.
        let note = size(of: Text(verbatim: "Primeira linha\nSegunda linha").scaledFont(12, lineHeight: 1.4, webKitLine: true))
        #expect(abs(note.height - 32) < 0.67, "Note: \(note.height)")
        // A title of 11 with the normal line: 13.
        let title = size(of: Text(verbatim: "MÚSCULOS").scaledFont(11, weight: .heavy, webKitLine: true))
        #expect(abs(title.height - 13) < 0.34, "Title: \(title.height)")
        print("MEDIÇÃO linha do WebKit: 12 a 1,4 em duas linhas \(note.height) pt, 11 normal \(title.height) pt")
    }

    @Test("Laid out by SwiftUI, a text with a line height of the model is as tall as in the model")
    func measuredLineHeights() {
        // A title of 29 at 1,05: one line of 30,45.
        let title = size(of: Text(verbatim: "Programação").scaledFont(29, weight: .heavy, lineHeight: 1.05))
        #expect(abs(title.height - 30.45) < 0.34, "Title: \(title.height)")
        // A sheet text of 13 at 1,4 in two lines: 18,2 each.
        let sheet = size(of: Text(verbatim: "Primeira linha\nSegunda linha").scaledFont(13, lineHeight: 1.4))
        #expect(abs(sheet.height - 36.4) < 0.67, "Sheet text: \(sheet.height)")
        // Without a line height, the font's own: a line of 17 takes SF Pro's height at 17.
        let body = size(of: Text(verbatim: "Treino").scaledFont(17))
        #expect(abs(body.height - SystemFont.lineHeight(size: 17, weight: .regular)) < 0.34, "Body: \(body.height)")
    }

    @Test("With the Bold Text setting, the system font draws the same text heavier, so wider")
    func boldText() {
        let text = Text(verbatim: "Supino Inclinado (Halter)").scaledFont(15).fixedSize()
        let normal = size(of: text, width: .greatestFiniteMagnitude)
        let bold = size(of: text.environment(\.legibilityWeight, .bold), width: .greatestFiniteMagnitude)
        #expect(bold.width > normal.width + 1, "Regular \(normal.width), with Bold Text \(bold.width)")
    }
}
