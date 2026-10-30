import Testing
import UIKit
@testable import IronFlow

/// Inter, the app's font: its five files are in the app, they are registered when it starts, and each
/// weight the app uses has its file.
@MainActor
struct InterFontTests {
    @Test("The five files are in the app, registered, and load under their PostScript names")
    func filesAreRegistered() throws {
        // Already registered when the app started: a second time changes nothing and fails nothing.
        #expect(InterFont.register().isEmpty)
        for name in InterFont.allNames {
            #expect(Bundle.main.url(forResource: name, withExtension: "ttf") != nil, "\(name).ttf not in the app")
            let font = try #require(UIFont(name: name, size: 17), "\(name) does not load")
            #expect(font.fontName == name)
            #expect(font.familyName == "Inter")
        }
        // The license goes with the files.
        #expect(Bundle.main.url(forResource: "OFL", withExtension: "txt") != nil, "OFL.txt not in the app")
    }

    @Test("Each weight of the app has its file: regular, medium, semibold, bold and heavy (ExtraBold)")
    func weights() {
        #expect(InterFont.name(for: .regular) == "Inter-Regular")
        #expect(InterFont.name(for: .medium) == "Inter-Medium")
        #expect(InterFont.name(for: .semibold) == "Inter-SemiBold")
        #expect(InterFont.name(for: .bold) == "Inter-Bold")
        #expect(InterFont.name(for: .heavy) == "Inter-ExtraBold")
        // Weights the app does not use read as the nearest file.
        #expect(InterFont.name(for: .light) == "Inter-Regular")
        #expect(InterFont.name(for: .black) == "Inter-ExtraBold")
    }

    @Test("With the Bold Text setting, each weight reads heavier, as the system font does")
    func boldText() {
        #expect(InterFont.name(for: .regular, boldText: true) == "Inter-SemiBold")
        #expect(InterFont.name(for: .medium, boldText: true) == "Inter-Bold")
        #expect(InterFont.name(for: .semibold, boldText: true) == "Inter-Bold")
        #expect(InterFont.name(for: .bold, boldText: true) == "Inter-ExtraBold")
        #expect(InterFont.name(for: .heavy, boldText: true) == "Inter-ExtraBold")
        // Without it, the weight's own file.
        #expect(InterFont.name(for: .semibold, boldText: false) == "Inter-SemiBold")
    }
}
