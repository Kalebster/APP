import SwiftUI
import Testing
@testable import IronFlow

/// The body figure of the exercise screen, read from the prototype's paths.
struct BodyFigurePathsTests {
    @Test("Every region of both views is read whole, inside the drawing, and mirrored across x = 120")
    func regionsAreRead() {
        #expect(BodyFigurePaths.front.count == 14)
        #expect(BodyFigurePaths.back.count == 15)
        let box = BodyFigurePaths.viewBox.insetBy(dx: -0.5, dy: -0.5)
        for (regions, drawn) in [(BodyFigurePaths.front, BodyFigurePaths.frontRegions), (BodyFigurePaths.back, BodyFigurePaths.backRegions)] {
            #expect(regions.count == drawn.count)
            for (region, path) in zip(regions, drawn) {
                let left = SVGPath.parse(region.path).boundingRect
                #expect(left.width > 0 && left.height > 0, "\(region.id) was not read")
                #expect(box.contains(path.path.boundingRect), "\(region.id) leaves the drawing: \(path.path.boundingRect)")
                // Both sides: the mirror image ends where the left side starts, across x = 120.
                #expect(abs(path.path.boundingRect.maxX - (120 - left.minX)) < 0.01, "\(region.id) is not mirrored")
            }
        }
        #expect(BodyFigurePaths.skin.boundingRect.width > 60)
    }

    @Test("Every muscle is drawn in at least one region, and every region shows a muscle")
    func everyMuscleDrawn() {
        let regions = BodyFigurePaths.front + BodyFigurePaths.back
        #expect(Set(regions.flatMap(\.muscles)) == Set(Muscle.allCases))
        #expect(regions.allSatisfy { !$0.muscles.isEmpty })
    }

    @Test("The path reader follows the commands M, L, H, V, C and Z")
    func pathCommands() {
        let path = SVGPath.parse("M10 10H20V30L10 30ZM40 40C40 50 50 50 50 40Z")
        let bounds = path.boundingRect
        #expect(bounds.minX == 10 && bounds.minY == 10 && bounds.maxX == 50)
        // The curve reaches 47,5; its control points, 50.
        #expect(bounds.maxY >= 47.4 && bounds.maxY <= 50)
        #expect(SVGPath.parse("").isEmpty)
        // An unknown command ends the path there.
        #expect(SVGPath.parse("M0 0L10 10Q5 5 0 0").boundingRect == CGRect(x: 0, y: 0, width: 10, height: 10))
    }
}
