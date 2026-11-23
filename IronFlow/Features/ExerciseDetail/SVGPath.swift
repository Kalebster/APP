import SwiftUI

/// Reads the path data of an SVG, as the prototype's drawings write it: the absolute commands M, L, H, V, C
/// and Z, with numbers separated by spaces or commas (a minus sign or a second decimal point also starts
/// a new number). A command it does not know ends the path there, so a drawing never comes out wrong
/// silently: the tests read every path of the body figure.
enum SVGPath {
    static func parse(_ data: String) -> Path {
        var path = Path()
        var scanner = NumberScanner(data)
        var command: Character?
        var current = CGPoint.zero
        while let next = scanner.nextCommandOrNumber() {
            switch next {
            case .command(let letter):
                command = letter
                if letter == "Z" || letter == "z" {
                    path.closeSubpath()
                }
                continue
            case .number(let first):
                scanner.pushBack(first)
            }
            guard let letter = command else { return path }
            switch letter {
            case "M":
                guard let point = scanner.point() else { return path }
                path.move(to: point)
                current = point
                // Further pairs after a move are lines.
                command = "L"
            case "L":
                guard let point = scanner.point() else { return path }
                path.addLine(to: point)
                current = point
            case "H":
                guard let x = scanner.number() else { return path }
                current = CGPoint(x: x, y: current.y)
                path.addLine(to: current)
            case "V":
                guard let y = scanner.number() else { return path }
                current = CGPoint(x: current.x, y: y)
                path.addLine(to: current)
            case "C":
                guard let control1 = scanner.point(), let control2 = scanner.point(), let end = scanner.point() else { return path }
                path.addCurve(to: end, control1: control1, control2: control2)
                current = end
            default:
                return path
            }
        }
        return path
    }

    /// Reads the commands and numbers of path data, one at a time.
    private struct NumberScanner {
        enum Token {
            case command(Character)
            case number(Double)
        }

        private let characters: [Character]
        private var index = 0
        private var pending: Double?

        init(_ data: String) {
            characters = Array(data)
        }

        mutating func pushBack(_ number: Double) {
            pending = number
        }

        mutating func nextCommandOrNumber() -> Token? {
            if let pending {
                self.pending = nil
                return .number(pending)
            }
            skipSeparators()
            guard index < characters.count else { return nil }
            let character = characters[index]
            if character.isLetter {
                index += 1
                return .command(character)
            }
            return readNumber().map(Token.number)
        }

        mutating func number() -> Double? {
            if let pending {
                self.pending = nil
                return pending
            }
            skipSeparators()
            return readNumber()
        }

        mutating func point() -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return CGPoint(x: x, y: y)
        }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index] == " " || characters[index] == "," {
                index += 1
            }
        }

        private mutating func readNumber() -> Double? {
            var text = ""
            var hasPoint = false
            while index < characters.count {
                let character = characters[index]
                if character == "-" || character == "+" {
                    guard text.isEmpty else { break }
                } else if character == "." {
                    guard !hasPoint else { break }
                    hasPoint = true
                } else if !character.isNumber {
                    break
                }
                text.append(character)
                index += 1
            }
            return Double(text)
        }
    }
}
