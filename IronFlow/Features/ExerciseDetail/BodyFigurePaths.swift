import SwiftUI

/// The body figure of the exercise screen, an original drawing of the approved prototype: each region is
/// drawn on the left side of the body and mirrored across x = 120, in the prototype's coordinates
/// (viewBox 18 2 84 228). The paths are read once.
enum BodyFigurePaths {
    /// A region of the drawing and the muscles it shows.
    struct Region: Sendable {
        let id: String
        let muscles: [Muscle]
        let path: String
    }

    /// A region read as a path, with its mirror image.
    struct DrawnRegion: Sendable {
        let muscles: [Muscle]
        let path: Path
    }

    /// The drawing's own area: the prototype's viewBox.
    static let viewBox = CGRect(x: 18, y: 2, width: 84, height: 228)

    /// The regions of each view, as paths with both sides, in drawing order.
    static let frontRegions: [DrawnRegion] = drawn(front)
    static let backRegions: [DrawnRegion] = drawn(back)
    /// The parts without muscle and the neck, both sides.
    static let skin: Path = {
        var path = SVGPath.parse(base)
        path.addPath(SVGPath.parse(neck))
        return path
    }()

    private static func drawn(_ regions: [Region]) -> [DrawnRegion] {
        regions.map { region in
            let left = SVGPath.parse(region.path)
            var both = left
            both.addPath(left, transform: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 120, ty: 0))
            return DrawnRegion(muscles: region.muscles, path: both)
        }
    }

    static let front: [Region] = [
        Region(id: "f_trap", muscles: [.traps], path: "M55.2 27.6C53.4 31.6 49.6 34.2 42.6 36.6C46.6 37.4 50.4 37.2 53.6 35.8C55 33.6 56 31.2 56.4 28.6Z"),
        Region(id: "f_dlat", muscles: [.sideDelts], path: "M40.6 37.2C34.2 37.6 29.6 41.8 28.6 48.8C28 53.6 28.6 57.6 30.4 60.8C31.4 55.4 32.6 49.2 35 44C36.4 41.2 38.4 38.8 40.6 37.2Z"),
        Region(id: "f_dant", muscles: [.frontDelts], path: "M41.6 37.6C38.8 39.4 36.6 42.4 35.4 45.6C33.8 50 32.6 55 31.8 60.2C33.4 59.6 35 58.2 36.4 56.4C37.4 50.6 39.8 44.6 45.2 39.6C44.2 38.6 43 38 41.6 37.6Z"),
        Region(id: "f_pec", muscles: [.chest], path: "M46.6 40C51.4 38.6 56 38.6 59.2 39.6V58.4C55 61.8 48.6 62.2 43.4 60.2C40.6 59.2 38.6 57.8 37.6 56.4C38.6 49.8 41.4 44 46.6 40Z"),
        Region(id: "f_lat", muscles: [.lats], path: "M38.4 59.4C39.2 63.8 40.6 67.8 42.6 71.4C43 67.6 43.2 64.4 43.4 61.8C41.6 61.4 40 60.6 38.4 59.4Z"),
        Region(id: "f_bic", muscles: [.biceps], path: "M30.6 62.6C28.4 67.8 27.4 74.4 27.8 81C28 84.2 29.2 86.2 31.2 86.4C33.4 86.6 34.8 84.6 35.4 81.6C36.6 75.4 36.6 68.6 35.8 60.6C34.2 61.8 32.4 62.4 30.6 62.6Z"),
        Region(id: "f_fore", muscles: [.forearms], path: "M28.4 88.6C25.6 95.4 23 104.6 21.4 117.6L25.6 118.4C28.4 108.8 31.6 99.6 34.6 90.8C34.8 89.4 34.4 88.4 33.4 88C31.8 87.6 30 87.8 28.4 88.6Z"),
        Region(id: "f_obl", muscles: [.obliques], path: "M43.8 63.8C43.2 69.6 43 75.4 43.6 81.4C44.2 87.2 45.6 92.6 47.8 97.4L49.8 99V66.4C47.8 65.8 45.8 65 43.8 63.8Z"),
        Region(id: "f_abs", muscles: [.abs], path: "M51 63.4H59.2V72.6H51.2ZM51.2 74H59.2V83.2H51.4ZM51.4 84.6H59.2V93.6H51.6ZM51.6 95H59.2V108.6C56.2 107.4 53.6 104.6 51.8 100.6Z"),
        Region(id: "f_quad", muscles: [.quadriceps], path: "M41.4 104.8C38.6 113.6 37.8 124.6 39 136C40 145.4 42.4 153.4 45.6 159.2L49.2 157.8C48 149 48 139.4 49.4 129.6C50.6 121.6 52.8 114.4 55.4 109C51 108.4 46 107 41.4 104.8Z"),
        Region(id: "f_vmo", muscles: [.quadriceps], path: "M55.4 110.2C53.4 116.4 52 123.6 51.4 131.4C50.8 140 51.2 148.6 52.6 156.6C54.6 155.4 56.2 153.2 57 150.4C56.2 146.6 55.6 142.6 55.8 138.6C56.4 129.8 57.2 120.6 57.4 111.6Z"),
        Region(id: "f_add", muscles: [.adductors], path: "M57.6 111.4C57.8 118 57.6 124.4 57.2 130.8C58 125.6 58.8 120 59.4 114.6Z"),
        Region(id: "f_tib", muscles: [.tibialis], path: "M45.8 169.2C44.4 178.8 44.6 190.4 46.6 203.6C47.4 208.4 48.2 212.4 49.2 215.6L50.6 215.4C50 205.6 49.8 195.4 50.2 185.4C50.4 179.4 50.4 174 50 169.4C48.6 168.8 47.2 168.8 45.8 169.2Z"),
        Region(id: "f_calf", muscles: [.calves], path: "M51.6 169.6C54.6 174.4 56.4 181.2 56.2 189.4C56 196.4 54.4 202.8 52 207.8C51.4 199.6 51.2 191 51.4 182.6C51.4 178 51.4 173.6 51.6 169.6Z"),
    ]

    static let back: [Region] = [
        Region(id: "b_trap", muscles: [.traps], path: "M56.2 26.6C54.8 31.4 50 34.6 41.6 36.8C46.8 39.8 50.6 44.8 53 51.6C55.6 59.2 57.8 67.6 60 76.6V26.6Z"),
        Region(id: "b_dlat", muscles: [.sideDelts], path: "M39.6 37.4C33.6 38.2 29.6 42.2 28.6 48.8C28 53.6 28.6 57.6 30.4 60.8C31.2 54.6 32.6 48.6 35.4 43.6C36.6 41.2 38 39.2 39.6 37.4Z"),
        Region(id: "b_dpost", muscles: [.rearDelts], path: "M41.2 37.6C38.6 39.6 36.6 42.6 35.4 46.2C34 50.2 33 54.6 32.4 59.4C34.6 58.6 36.4 57 37.8 55C39.2 50.8 41 47 43.4 43.8C44.4 42.6 45.4 41.6 46.6 40.6C45 39.4 43.2 38.4 41.2 37.6Z"),
        Region(id: "b_scap", muscles: [.upperBack, .rotatorCuff], path: "M47.4 41.6C43.6 45 40.6 50.2 39.4 56.2C41.8 58.6 45 59.6 48.4 59.4C50.4 59.2 52 58.4 53.2 57.2C52.4 51.4 50.4 46 47.4 41.6Z"),
        Region(id: "b_rhom", muscles: [.upperBack], path: "M54 56.6C55.6 61.6 57.4 67 59.2 72.4L56.6 61.6C55.8 59.8 55 58 54 56.6Z"),
        Region(id: "b_lat", muscles: [.lats], path: "M39 58.4C38.8 66.2 40.4 74.4 43.6 82.2C45.2 86.2 47.2 89.6 49.4 92.4C52.6 89 55.6 85.2 58.4 80.6C57 74.4 55.4 67.6 53.6 60.6C52 61 50.2 61.2 48.4 61.2C45 61.2 41.8 60.2 39 58.4Z"),
        Region(id: "b_obl", muscles: [.obliques], path: "M43.6 85.4C43.8 90.6 44.4 95.4 45.4 99.8L48.6 94.4C46.8 91.8 45.2 88.8 43.6 85.4Z"),
        Region(id: "b_low", muscles: [.lowerBack], path: "M59.2 81C56.8 85.4 53.6 89.6 50.4 93.4C51.8 97.6 52.6 101.8 52.8 106.2C55 107 57.4 107.4 59.8 107.4V81Z"),
        Region(id: "b_tri", muscles: [.triceps], path: "M30.4 62.4C28.4 67.8 27.4 74.4 27.8 81C28 84.2 29.2 86.2 31.2 86.4C33.4 86.6 34.8 84.6 35.4 81.6C36.6 75.4 36.8 68.6 36.2 60.2C34.4 61.6 32.6 62.2 30.4 62.4Z"),
        Region(id: "b_fore", muscles: [.forearms], path: "M28.4 88.6C25.6 95.4 23 104.6 21.4 117.6L25.6 118.4C28.4 108.8 31.6 99.6 34.6 90.8C34.8 89.4 34.4 88.4 33.4 88C31.8 87.6 30 87.8 28.4 88.6Z"),
        Region(id: "b_gmed", muscles: [.gluteusMedius], path: "M45.6 100.4C42.8 103 41.2 106.6 41 110.8C40.8 113.4 41.2 115.8 42 118C45 113.4 48.6 110.2 52.2 108.4C50.4 105.4 48.2 102.8 45.6 100.4Z"),
        Region(id: "b_glu", muscles: [.glutes], path: "M53 109.2C48.2 111.2 44.6 114.8 42.6 119.6C41.8 122 41.6 124.6 42 127.2C45.4 131.6 51.4 133.4 59.2 132.6V109.6C57 109.8 54.8 109.6 53 109.2Z"),
        Region(id: "b_ham", muscles: [.hamstrings], path: "M42.2 130.4C40.6 138.2 40.8 146.4 43 154.2C44 157.6 45.2 160.4 46.6 162.6L50.6 161.4C50.4 155.6 51.2 149.6 53 143.8C54.4 139.6 56 136.4 57.6 134.2C51.6 134.8 46.4 133.4 42.2 130.4Z"),
        Region(id: "b_add", muscles: [.adductors], path: "M58.2 135C56.6 138.6 55.4 142.6 54.6 147C56.6 143.4 58.2 139.6 59.4 135.6Z"),
        Region(id: "b_calf", muscles: [.calves], path: "M45.4 168.6C42.8 174.4 42 181.4 43.2 188.6C44 193.4 45.6 197.4 47.8 200.4C49.2 197.4 50.2 193.6 50.4 189.4L50.6 168.4C48.8 167.8 47 168 45.4 168.6ZM51.6 168.8C54.8 172.6 56.6 178.2 56.6 184.6C56.6 190.6 55 195.8 52.6 199.8C51.6 196.6 51.2 193 51.2 189.4Z"),
    ]

    /// The parts without muscle (head, hands, knees and feet), the same in both views.
    static let base = "M60 4.2C66.2 4.2 70.6 9 70.6 15.4C70.6 21.6 66.4 26.6 60 26.6C53.6 26.6 49.4 21.6 49.4 15.4C49.4 9 53.8 4.2 60 4.2ZM21.2 119.6L25.8 120.4C26.4 124.4 26 128.6 24.4 132.2C23.4 134.4 21 134.6 19.8 132.4C18.6 128.4 19.6 123.6 21.2 119.6ZM98.8 119.6L94.2 120.4C93.6 124.4 94 128.6 95.6 132.2C96.6 134.4 99 134.6 100.2 132.4C101.4 128.4 100.4 123.6 98.8 119.6ZM45.8 161.4C47.6 160.6 49.6 160.2 51.6 160.6C52.4 162.8 52.4 165.2 51.6 167.4C49.6 167.8 47.6 167.6 45.8 166.8C45.2 165 45.2 163.2 45.8 161.4ZM74.2 161.4C72.4 160.6 70.4 160.2 68.4 160.6C67.6 162.8 67.6 165.2 68.4 167.4C70.4 167.8 72.4 167.6 74.2 166.8C74.8 165 74.8 163.2 74.2 161.4ZM47.6 217C46 219.6 44.4 222.4 44.2 225.2C44 227.4 46 228.2 49.4 228C51.6 227.8 52.6 226.6 52.4 224.6C52.2 222 51.6 219.4 50.8 217ZM72.4 217C74 219.6 75.6 222.4 75.8 225.2C76 227.4 74 228.2 70.6 228C68.4 227.8 67.4 226.6 67.6 224.6C67.8 222 68.4 219.4 69.2 217Z"

    static let neck = "M55.6 25.4H64.4V31.4C61.6 32.6 58.4 32.6 55.6 31.4Z"
}
