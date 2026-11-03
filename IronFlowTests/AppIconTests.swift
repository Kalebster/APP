import Testing
import UIKit

/// The icons of the approved model in the asset catalog: each one is in the app, kept as a 24 × 24
/// template, and draws its shape. A shape the catalog could not read would leave the icon blank.
@MainActor
struct AppIconTests {
    /// The icons the app uses: the model's 50, without menu-edit, menu-rename and menu-reorder (the ⋯
    /// menus are the iOS ones) and without the 4 identical to another one kept (timer is clock,
    /// metric-month is calendar, metric-wkg is eq-halteres, plus-small is plus).
    static let names = [
        "bolt", "calculator", "calendar", "check", "chevron-down", "chevron-left", "chevron-right",
        "chevron-right-list", "chevron-up", "clock", "eq-anilha", "eq-barra", "eq-elastico", "eq-halteres",
        "eq-kettlebell", "eq-maquina", "eq-peso-do-corpo", "eq-polia", "eq-smith", "logo", "menu-arrow-down",
        "menu-arrow-up", "menu-close", "metric-bmr", "metric-height", "metric-kcal", "metric-last",
        "metric-streak", "metric-wdelta", "metric-weight", "metric-wtime", "more", "more-vertical", "play",
        "play-hero", "plus", "search", "tab-exercises", "tab-history", "tab-home", "tab-settings",
        "tab-workouts", "target",
    ]

    @Test("The 43 icons are in the app as 24 × 24 templates")
    func iconsAreTemplates() throws {
        #expect(Self.names.count == 43)
        for name in Self.names {
            let image = try #require(UIImage(named: name, in: .main, compatibleWith: nil), "\(name) is not in the app")
            #expect(image.renderingMode == .alwaysTemplate, "\(name) is not a template")
            #expect(image.size == CGSize(width: 24, height: 24), "\(name) is \(image.size), expected 24 × 24")
        }
        for name in ["menu-edit", "menu-rename", "menu-reorder", "timer", "metric-month", "metric-wkg", "plus-small"] {
            #expect(UIImage(named: name, in: .main, compatibleWith: nil) == nil, "\(name) should not be in the app")
        }
    }

    @Test("Each icon draws its shape: lines and fills both reach the image")
    func iconsDrawTheirShape() throws {
        for name in Self.names {
            let image = try #require(UIImage(named: name, in: .main, compatibleWith: nil))
            let covered = try coveredFraction(of: image, side: 48)
            // The thinnest icons (a chevron, a plus) cover about 5% of their square; a blank one covers 0.
            #expect(covered > 0.02, "\(name) covers \(covered) of its square: its shape was not drawn")
            #expect(covered < 0.9, "\(name) covers \(covered) of its square: it is drawn as a block")
        }
    }

    /// The share of the pixels that `image`, drawn at `side` × `side` pixels, makes mostly opaque.
    private func coveredFraction(of image: UIImage, side: Int) throws -> Double {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: side, height: side)
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        let cgImage = try #require(drawn.cgImage)
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let opaque = try pixels.withUnsafeMutableBytes { buffer -> Int in
            let context = try #require(CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            return stride(from: 3, to: buffer.count, by: 4).count(where: { buffer[$0] > 128 })
        }
        return Double(opaque) / Double(side * side)
    }
}
