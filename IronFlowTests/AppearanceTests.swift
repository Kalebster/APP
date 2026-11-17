import Testing
import UIKit

/// The app is dark only, so each color of the asset catalog has a single value: the one of the approved
/// prototype "Iron Flow — visual novo" (black, white and gray, with blue only in details).
@MainActor
struct AppearanceTests {
    /// The red, green and blue of a catalog color as 0...255 integers, and its opacity as 0...100, as the
    /// given device style shows it.
    private func components(of name: String, style: UIUserInterfaceStyle) throws -> (rgb: [Int], opacity: Int) {
        let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil))
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let hasComponents = resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(hasComponents, "\(name) has no RGB components")
        return ([red, green, blue].map { Int(($0 * 255).rounded()) }, Int((alpha * 100).rounded()))
    }

    @Test("Each color is exactly its dark value, with the device in light or in dark mode")
    func colorsAreTheDarkValues() throws {
        // Opaque unless an opacity in percent is given.
        let expected: [(name: String, rgb: [Int], opacity: Int)] = [
            ("ScreenBackground", [0x00, 0x00, 0x00], 100),
            ("CardBackground", [0x12, 0x12, 0x14], 100),
            ("CardBorder", [0x23, 0x23, 0x26], 100),
            ("RowSeparator", [0x1E, 0x1E, 0x21], 100),
            ("BrightText", [0xF5, 0xF5, 0xF7], 100),
            ("MediumText", [0xC8, 0xC8, 0xCD], 100),
            ("SecondaryText", [0x9B, 0x9B, 0xA1], 100),
            ("DimText", [0x8C, 0x8C, 0x92], 100),
            ("FutureDayText", [0x7D, 0x7D, 0x83], 100),
            ("AccentColor", [0x3D, 0x7B, 0xF0], 100),
            ("LightAccent", [0xD1, 0xD1, 0xD6], 100),
            ("IconTileBackground", [0x1E, 0x1E, 0x21], 100),
            ("SetFieldBackground", [0x1E, 0x1E, 0x21], 100),
            ("UnplannedDayBackground", [0x1E, 0x1E, 0x21], 100),
            // The main buttons: white with black text.
            ("PrimaryButton", [0xF5, 0xF5, 0xF7], 100),
            ("PrimaryButtonText", [0x00, 0x00, 0x00], 100),
            // The highlight (today's workout).
            ("HighlightBackground", [0x0A, 0x0A, 0x0B], 100),
            ("HighlightBorder", [0xFF, 0xFF, 0xFF], 14),
            ("HighlightLine", [0xFF, 0xFF, 0xFF], 18),
            ("HighlightBadge", [0xFF, 0xFF, 0xFF], 10),
            ("HighlightGlow", [0xFF, 0xFF, 0xFF], 10),
            ("HighlightText", [0xF2, 0xF2, 0xF4], 100),
            ("HighlightSecondaryText", [0xA6, 0xA6, 0xAC], 100),
            ("HighlightLabel", [0xA6, 0xA6, 0xAC], 100),
            // The week.
            ("RingTrack", [0x23, 0x23, 0x26], 100),
            ("MarkedDayBackground", [0x1C, 0x1C, 0x1F], 100),
            ("MarkedDayNumber", [0xD1, 0xD1, 0xD6], 100),
            ("MarkedDayBorder", [0x8E, 0x8E, 0x94], 100),
            ("PlannedDayBackground", [0x2A, 0x2A, 0x2D], 100),
            ("PlannedDayLetter", [0xF2, 0xF2, 0xF4], 100),
            // The session in progress and the editor.
            ("SuggestionText", [0x84, 0x86, 0x8B], 100),
            ("ControlBorder", [0x34, 0x36, 0x3C], 100),
            ("CurrentSetBackground", [0x1C, 0x1C, 0x1F], 100),
            ("CurrentFieldBackground", [0x2C, 0x2C, 0x30], 100),
            ("CurrentSuggestionText", [0x9B, 0x9B, 0xA1], 100),
            ("CurrentSetBorder", [0xFF, 0xFF, 0xFF], 35),
            ("CurrentCheckBorder", [0xFF, 0xFF, 0xFF], 55),
            ("SelectedCardBackground", [0x1C, 0x1C, 0x1F], 100),
            ("DashedBorder", [0x3A, 0x3D, 0x44], 100),
            ("WarmupSet", [0xF5, 0xB8, 0x3D], 100),
            ("FeederSet", [0xA9, 0x8B, 0xF5], 100),
            ("FailureSet", [0xF3, 0x63, 0x67], 100),
            // The lock screen drawn in "Avisar quando o descanso acabar?".
            ("LockScreenTop", [0x2C, 0x2C, 0x30], 100),
            ("LockScreenMiddle", [0x14, 0x14, 0x16], 100),
            ("NoticeBackground", [0x30, 0x34, 0x3E], 82),
            ("NoticeText", [0xDD, 0xE1, 0xEA], 100),
            ("NoticeSecondaryText", [0xAE, 0xB4, 0xC2], 100),
        ]
        for (name, rgb, opacity) in expected {
            let dark = try components(of: name, style: .dark)
            let light = try components(of: name, style: .light)
            #expect(dark.rgb == rgb, "\(name) in dark mode is \(dark.rgb), expected \(rgb)")
            #expect(dark.opacity == opacity, "\(name) in dark mode has opacity \(dark.opacity)%, expected \(opacity)%")
            #expect(light.rgb == rgb && light.opacity == opacity, "\(name) in light mode is \(light), expected \(rgb) at \(opacity)%: the light value should be gone")
        }
    }

    @Test("The rest bar has no color of its own: it is the system's glass")
    func restBarHasNoColor() {
        #expect(UIColor(named: "RestBarBackground", in: .main, compatibleWith: nil) == nil)
    }
}
