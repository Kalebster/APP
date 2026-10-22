import SwiftUI

/// The icon of an equipment, as in the model: lines on a 24 × 24 grid, 2 units wide, with rounded ends
/// and corners. It fills its frame, so the line grows with the icon. Decorative: the text next to it
/// says what it is.
struct EquipmentIcon: View {
    let equipment: Equipment

    var body: some View {
        EquipmentShape(equipment: equipment)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// The outline of an equipment icon, ready to be filled.
struct EquipmentShape: Shape {
    let equipment: Equipment

    nonisolated func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let scale = side / 24
        let lines = Self.lines(of: equipment)
        let transform = CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
            .scaledBy(x: scale, y: scale)
        return lines
            .applying(transform)
            .strokedPath(StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))
    }

    /// The lines of the icon on the 24 × 24 grid, from the SVG paths of the model.
    nonisolated private static func lines(of equipment: Equipment) -> Path {
        var path = Path()
        func line(_ points: CGPoint...) {
            path.addLines(points)
        }
        func circle(_ x: CGFloat, _ y: CGFloat, radius: CGFloat) {
            path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x, y: y)
        }

        switch equipment {
        case .barbell:
            // M2 12h20 M5 8v8 M19 8v8 M8 9v6 M16 9v6
            line(point(2, 12), point(22, 12))
            line(point(5, 8), point(5, 16))
            line(point(19, 8), point(19, 16))
            line(point(8, 9), point(8, 15))
            line(point(16, 9), point(16, 15))
        case .dumbbell:
            // M7 12h10 M4 9v6 M7 8v8 M17 8v8 M20 9v6
            line(point(7, 12), point(17, 12))
            line(point(4, 9), point(4, 15))
            line(point(7, 8), point(7, 16))
            line(point(17, 8), point(17, 16))
            line(point(20, 9), point(20, 15))
        case .machine:
            // A 14 × 18 rectangle at 5, 3 with corners of 2; M9 7h6 M9 11h6 M12 15v3
            path.addRoundedRect(in: CGRect(x: 5, y: 3, width: 14, height: 18), cornerSize: CGSize(width: 2, height: 2))
            line(point(9, 7), point(15, 7))
            line(point(9, 11), point(15, 11))
            line(point(12, 15), point(12, 18))
        case .cable:
            // A circle of radius 3 at 12, 6; M12 9v12 M8 21h8
            circle(12, 6, radius: 3)
            line(point(12, 9), point(12, 21))
            line(point(8, 21), point(16, 21))
        case .bodyweight:
            // A circle of radius 2 at 12, 5; M12 7v7 M8 10h8 M9 21l3-7 3 7
            circle(12, 5, radius: 2)
            line(point(12, 7), point(12, 14))
            line(point(8, 10), point(16, 10))
            line(point(9, 21), point(12, 14), point(15, 21))
        case .kettlebell:
            // M9 6a3 3 0 0 1 6 0 (the handle, over the top); a circle of radius 6 at 12, 13
            path.move(to: point(9, 6))
            path.addArc(center: point(12, 6), radius: 3, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            circle(12, 13, radius: 6)
        case .smith:
            // M6 3v18 M18 3v18 M3 10h18 M3 21h6 M15 21h6
            line(point(6, 3), point(6, 21))
            line(point(18, 3), point(18, 21))
            line(point(3, 10), point(21, 10))
            line(point(3, 21), point(9, 21))
            line(point(15, 21), point(21, 21))
        case .band:
            // M3 12c2.5-5 4.5 5 7 0s4.5 5 7 0 3 3 4 1 (the smooth curves reflect the previous control point)
            path.move(to: point(3, 12))
            path.addCurve(to: point(10, 12), control1: point(5.5, 7), control2: point(7.5, 17))
            path.addCurve(to: point(17, 12), control1: point(12.5, 7), control2: point(14.5, 17))
            path.addCurve(to: point(21, 13), control1: point(19.5, 7), control2: point(20, 15))
        case .plate:
            // Circles of radius 9 and 2.5 at 12, 12
            circle(12, 12, radius: 9)
            circle(12, 12, radius: 2.5)
        }
        return path
    }
}
