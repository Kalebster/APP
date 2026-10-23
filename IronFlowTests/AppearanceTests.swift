import Testing
import UIKit

/// The app is dark only, so each color of the asset catalog has a single value: the dark one the app
/// has always shown, or the one of the approved Início, Treinos and session models.
@MainActor
struct AppearanceTests {
    /// The red, green and blue of a catalog color as 0...255 integers, as the given device style shows it.
    private func components(of name: String, style: UIUserInterfaceStyle) throws -> [Int] {
        let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil))
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let hasComponents = resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(hasComponents, "\(name) has no RGB components")
        let opacity = Int((alpha * 255).rounded())
        #expect(opacity == 255, "\(name) is not opaque")
        return [red, green, blue].map { Int(($0 * 255).rounded()) }
    }

    @Test("Each color is exactly its dark value, with the device in light or in dark mode")
    func colorsAreTheDarkValues() throws {
        let expected: [(name: String, rgb: [Int])] = [
            ("ScreenBackground", [0x0D, 0x0E, 0x11]),
            ("CardBackground", [0x17, 0x18, 0x1C]),
            ("CardBorder", [0x2A, 0x2C, 0x31]),
            ("AccentColor", [0x4A, 0x7B, 0xEA]),
            // The Início and Treinos models.
            ("HighlightBackground", [0x15, 0x21, 0x3D]),
            ("HighlightBorder", [0x2A, 0x3D, 0x6A]),
            ("HighlightLine", [0x34, 0x49, 0x7A]),
            ("HighlightText", [0xDC, 0xE5, 0xFB]),
            ("HighlightSecondaryText", [0xC3, 0xCE, 0xEA]),
            ("HighlightLabel", [0xA9, 0xBE, 0xEF]),
            ("HighlightBadge", [0x24, 0x36, 0x5F]),
            ("IconTileBackground", [0x1E, 0x26, 0x38]),
            ("LightAccent", [0x7F, 0xA3, 0xF2]),
            ("RingTrack", [0x24, 0x26, 0x2C]),
            ("MarkedDayBackground", [0x1A, 0x24, 0x40]),
            ("MarkedDayNumber", [0xA9, 0xC1, 0xF7]),
            ("PlannedDayBackground", [0x22, 0x35, 0x5F]),
            ("PlannedDayLetter", [0xCF, 0xDC, 0xFA]),
            ("UnplannedDayBackground", [0x22, 0x24, 0x2A]),
            ("DimText", [0x6E, 0x71, 0x78]),
            ("FutureDayText", [0x5C, 0x5F, 0x66]),
            ("MediumText", [0xC9, 0xCB, 0xD1]),
            ("RowSeparator", [0x24, 0x26, 0x2C]),
            ("BrightText", [0xF2, 0xF3, 0xF5]),
            // The session in progress model.
            ("SetFieldBackground", [0x1E, 0x1F, 0x24]),
            ("SuggestionText", [0x54, 0x57, 0x5E]),
            ("ControlBorder", [0x34, 0x36, 0x3C]),
            ("CurrentSetBackground", [0x16, 0x22, 0x41]),
            ("CurrentFieldBackground", [0x20, 0x30, 0x5A]),
            ("CurrentSuggestionText", [0x7F, 0x92, 0xC2]),
            ("RestBarBackground", [0x1C, 0x1D, 0x22]),
            // The Exercícios model.
            ("SecondaryText", [0x9A, 0x9C, 0xA3]),
            // The workout editor model.
            ("SelectedCardBackground", [0x14, 0x1B, 0x2C]),
        ]
        for (name, rgb) in expected {
            let dark = try components(of: name, style: .dark)
            let light = try components(of: name, style: .light)
            #expect(dark == rgb, "\(name) in dark mode is \(dark), expected \(rgb)")
            #expect(light == rgb, "\(name) in light mode is \(light), expected \(rgb): the light value should be gone")
        }
    }
}
