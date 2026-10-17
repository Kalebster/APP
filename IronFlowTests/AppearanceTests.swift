import Testing
import UIKit

/// The app is dark only, so each color of the asset catalog has a single value: the dark one the app
/// has always shown. Nothing visible changed when the light values were removed.
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

    @Test("Each color is exactly the dark value of today, with the device in light or in dark mode")
    func colorsAreTheDarkValues() throws {
        let expected: [(name: String, rgb: [Int])] = [
            ("ScreenBackground", [0x0D, 0x0E, 0x11]),
            ("CardBackground", [0x17, 0x18, 0x1C]),
            ("CardBorder", [0x2A, 0x2C, 0x31]),
            ("AccentColor", [0x4A, 0x7B, 0xEA]),
        ]
        for (name, rgb) in expected {
            let dark = try components(of: name, style: .dark)
            let light = try components(of: name, style: .light)
            #expect(dark == rgb, "\(name) in dark mode is \(dark), expected \(rgb)")
            #expect(light == rgb, "\(name) in light mode is \(light), expected \(rgb): the light value should be gone")
        }
    }
}
