import SwiftUI

/// Minimal SVG path-data parser — supports exactly the commands used by the
/// body-silhouette artwork (`M`, `L`, `H`, `V`, `C`, `Z`, all absolute), so
/// the raw `d` strings can be drawn as a native SwiftUI `Path` without
/// shipping a general-purpose SVG renderer.
enum SVGPathParser {
    static func path(from d: String) -> Path {
        var path = Path()
        var numbers: [Double] = []
        var numberStart: String.Index?
        var command: Character?
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        func flushNumber(at end: String.Index) {
            guard let start = numberStart, start < end else { numberStart = nil; return }
            if let value = Double(d[start..<end]) { numbers.append(value) }
            numberStart = nil
        }

        func apply(_ command: Character) {
            switch command {
            case "M":
                var isFirstPair = true
                var i = 0
                while i + 1 < numbers.count {
                    let point = CGPoint(x: numbers[i], y: numbers[i + 1])
                    if isFirstPair {
                        path.move(to: point)
                        subpathStart = point
                        isFirstPair = false
                    } else {
                        path.addLine(to: point)
                    }
                    current = point
                    i += 2
                }
            case "L":
                var i = 0
                while i + 1 < numbers.count {
                    let point = CGPoint(x: numbers[i], y: numbers[i + 1])
                    path.addLine(to: point)
                    current = point
                    i += 2
                }
            case "H":
                for x in numbers {
                    let point = CGPoint(x: x, y: current.y)
                    path.addLine(to: point)
                    current = point
                }
            case "V":
                for y in numbers {
                    let point = CGPoint(x: current.x, y: y)
                    path.addLine(to: point)
                    current = point
                }
            case "C":
                var i = 0
                while i + 5 < numbers.count {
                    let control1 = CGPoint(x: numbers[i], y: numbers[i + 1])
                    let control2 = CGPoint(x: numbers[i + 2], y: numbers[i + 3])
                    let end = CGPoint(x: numbers[i + 4], y: numbers[i + 5])
                    path.addCurve(to: end, control1: control1, control2: control2)
                    current = end
                    i += 6
                }
            case "Z", "z":
                path.closeSubpath()
                current = subpathStart
            default:
                break
            }
            numbers.removeAll()
        }

        var index = d.startIndex
        while index < d.endIndex {
            let char = d[index]
            if char.isLetter {
                flushNumber(at: index)
                if let command { apply(command) }
                command = char
                numbers.removeAll()
            } else if char == "-" || char == "+" {
                // A sign starts a new number even without preceding
                // whitespace (e.g. "10-5" is the two numbers 10 and -5).
                if numberStart != nil { flushNumber(at: index) }
                numberStart = index
            } else if char.isNumber || char == "." {
                if numberStart == nil { numberStart = index }
            } else {
                flushNumber(at: index)
            }
            index = d.index(after: index)
        }
        flushNumber(at: d.endIndex)
        if let command { apply(command) }

        return path
    }
}
