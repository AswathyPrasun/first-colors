import CoreGraphics
import Foundation
import SwiftUI

enum SVGPathError: Error, Equatable {
    case missingMoveTo
    case unexpectedCharacter(Character, offset: Int)
    case missingNumber(command: Character, offset: Int)
}

/// Converts SVG path data (`d` attribute) into a SwiftUI `Path`.
///
/// Supports `M L H V C S Q T A Z`, absolute and relative, implicit command repetition,
/// compact number syntax (`10-20`, `.5.5`, `1e2`) and compact arc flags (`0110 0`).
/// Arcs are converted to cubic Béziers (SVG 1.1 implementation notes, F.6.5).
enum SVGPathParser {
    static func parse(_ data: String) throws -> Path {
        var scanner = Scanner(Array(data.utf8))
        var builder = Builder()
        var command: UInt8?

        while true {
            scanner.skipSeparators()
            guard !scanner.isAtEnd else { break }

            if let letter = scanner.commandLetter() {
                scanner.advance()
                if command == nil, letter != UInt8(ascii: "M"), letter != UInt8(ascii: "m") {
                    throw SVGPathError.missingMoveTo
                }
                command = letter
                // Z takes no parameters; run it right away.
                if letter == UInt8(ascii: "Z") || letter == UInt8(ascii: "z") {
                    builder.close()
                    continue
                }
            } else {
                // Implicit repetition of the previous command.
                guard let previous = command else { throw SVGPathError.missingMoveTo }
                if previous == UInt8(ascii: "Z") || previous == UInt8(ascii: "z") || !scanner.startsNumber {
                    throw SVGPathError.unexpectedCharacter(scanner.currentCharacter, offset: scanner.offset)
                }
            }

            guard let current = command else { throw SVGPathError.missingMoveTo }
            try builder.apply(current, scanner: &scanner)

            // After a moveto, further coordinate pairs are implicit linetos.
            if current == UInt8(ascii: "M") { command = UInt8(ascii: "L") }
            if current == UInt8(ascii: "m") { command = UInt8(ascii: "l") }
        }
        return builder.path
    }
}

// MARK: - Path building

private struct Builder {
    var path = Path()
    private var current = CGPoint.zero
    private var subpathStart = CGPoint.zero
    private var lastCubicControl: CGPoint?
    private var lastQuadControl: CGPoint?
    private var needsMoveAfterClose = false

    mutating func close() {
        path.closeSubpath()
        current = subpathStart
        lastCubicControl = nil
        lastQuadControl = nil
        needsMoveAfterClose = true
    }

    mutating func apply(_ command: UInt8, scanner: inout Scanner) throws {
        let relative = command >= UInt8(ascii: "a")
        let upper = relative ? command - 32 : command
        let name = Character(UnicodeScalar(command))
        let base = relative ? current : .zero

        func number() throws -> CGFloat { try scanner.number(command: name) }
        func point() throws -> CGPoint {
            let x = try number()
            let y = try number()
            return CGPoint(x: base.x + x, y: base.y + y)
        }

        if upper != UInt8(ascii: "M"), needsMoveAfterClose {
            path.move(to: current)
        }
        needsMoveAfterClose = false

        var cubicControl: CGPoint?
        var quadControl: CGPoint?

        switch upper {
        case UInt8(ascii: "M"):
            let p = try point()
            path.move(to: p)
            current = p
            subpathStart = p
        case UInt8(ascii: "L"):
            let p = try point()
            path.addLine(to: p)
            current = p
        case UInt8(ascii: "H"):
            let x = try number()
            let p = CGPoint(x: relative ? current.x + x : x, y: current.y)
            path.addLine(to: p)
            current = p
        case UInt8(ascii: "V"):
            let y = try number()
            let p = CGPoint(x: current.x, y: relative ? current.y + y : y)
            path.addLine(to: p)
            current = p
        case UInt8(ascii: "C"):
            let c1 = try point()
            let c2 = try point()
            let p = try point()
            path.addCurve(to: p, control1: c1, control2: c2)
            cubicControl = c2
            current = p
        case UInt8(ascii: "S"):
            let c1 = lastCubicControl.map { reflect($0, about: current) } ?? current
            let c2 = try point()
            let p = try point()
            path.addCurve(to: p, control1: c1, control2: c2)
            cubicControl = c2
            current = p
        case UInt8(ascii: "Q"):
            let c = try point()
            let p = try point()
            path.addQuadCurve(to: p, control: c)
            quadControl = c
            current = p
        case UInt8(ascii: "T"):
            let c = lastQuadControl.map { reflect($0, about: current) } ?? current
            let p = try point()
            path.addQuadCurve(to: p, control: c)
            quadControl = c
            current = p
        case UInt8(ascii: "A"):
            let rx = try number()
            let ry = try number()
            let rotation = try number()
            let largeArc = try scanner.flag(command: name)
            let sweep = try scanner.flag(command: name)
            let p = try point()
            if let curves = ArcConverter.cubics(from: current, rx: rx, ry: ry, rotationDegrees: rotation,
                                                largeArc: largeArc, sweep: sweep, to: p) {
                for curve in curves {
                    path.addCurve(to: curve.end, control1: curve.control1, control2: curve.control2)
                }
            } else {
                // Zero radius: the spec says draw a straight line.
                path.addLine(to: p)
            }
            current = p
        default:
            throw SVGPathError.unexpectedCharacter(name, offset: scanner.offset)
        }

        lastCubicControl = cubicControl
        lastQuadControl = quadControl
    }

    private func reflect(_ point: CGPoint, about center: CGPoint) -> CGPoint {
        CGPoint(x: 2 * center.x - point.x, y: 2 * center.y - point.y)
    }
}

// MARK: - Arc conversion

enum ArcConverter {
    struct Cubic: Equatable {
        let control1: CGPoint
        let control2: CGPoint
        let end: CGPoint
    }

    /// Returns `nil` when a radius is zero (caller draws a line), `[]` when start == end.
    static func cubics(from start: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, rotationDegrees: CGFloat,
                       largeArc: Bool, sweep: Bool, to end: CGPoint) -> [Cubic]? {
        if start == end { return [] }
        var rx = abs(rxIn)
        var ry = abs(ryIn)
        if rx == 0 || ry == 0 { return nil }

        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        // Step 1: compute (x1', y1').
        let dx2 = (start.x - end.x) / 2
        let dy2 = (start.y - end.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        // Correct out-of-range radii.
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let scale = sqrt(lambda)
            rx *= scale
            ry *= scale
        }

        // Step 2: compute (cx', cy').
        let rx2 = rx * rx, ry2 = ry * ry
        let numerator = rx2 * ry2 - rx2 * y1p * y1p - ry2 * x1p * x1p
        let denominator = rx2 * y1p * y1p + ry2 * x1p * x1p
        var coefficient = denominator == 0 ? 0 : sqrt(max(0, numerator / denominator))
        if largeArc == sweep { coefficient = -coefficient }
        let cxp = coefficient * (rx * y1p / ry)
        let cyp = coefficient * -(ry * x1p / rx)

        // Step 3: compute (cx, cy).
        let cx = cosPhi * cxp - sinPhi * cyp + (start.x + end.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (start.y + end.y) / 2

        // Step 4: start angle and sweep.
        let v1 = CGPoint(x: (x1p - cxp) / rx, y: (y1p - cyp) / ry)
        let v2 = CGPoint(x: (-x1p - cxp) / rx, y: (-y1p - cyp) / ry)
        let theta1 = angle(CGPoint(x: 1, y: 0), v1)
        var delta = angle(v1, v2).truncatingRemainder(dividingBy: 2 * .pi)
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }

        // Split into ≤ 90° pieces and approximate each with one cubic.
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2) - 1e-9)))
        let step = delta / CGFloat(segments)
        let t = 4.0 / 3.0 * tan(step / 4)

        func pointAt(_ theta: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cosPhi * cos(theta) - ry * sinPhi * sin(theta),
                    y: cy + rx * sinPhi * cos(theta) + ry * cosPhi * sin(theta))
        }
        func derivativeAt(_ theta: CGFloat) -> CGPoint {
            CGPoint(x: -rx * cosPhi * sin(theta) - ry * sinPhi * cos(theta),
                    y: -rx * sinPhi * sin(theta) + ry * cosPhi * cos(theta))
        }

        var result: [Cubic] = []
        for index in 0..<segments {
            let a = theta1 + CGFloat(index) * step
            let b = a + step
            let pa = pointAt(a), da = derivativeAt(a)
            let pb = index == segments - 1 ? end : pointAt(b)
            let db = derivativeAt(b)
            result.append(Cubic(
                control1: CGPoint(x: pa.x + t * da.x, y: pa.y + t * da.y),
                control2: CGPoint(x: pb.x - t * db.x, y: pb.y - t * db.y),
                end: pb))
        }
        return result
    }

    private static func angle(_ u: CGPoint, _ v: CGPoint) -> CGFloat {
        atan2(u.x * v.y - u.y * v.x, u.x * v.x + u.y * v.y)
    }
}

// MARK: - Scanner

private struct Scanner {
    private let bytes: [UInt8]
    private(set) var offset = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var isAtEnd: Bool { offset >= bytes.count }

    var currentCharacter: Character {
        isAtEnd ? " " : Character(UnicodeScalar(bytes[offset]))
    }

    mutating func advance() { offset += 1 }

    mutating func skipSeparators() {
        while offset < bytes.count {
            switch bytes[offset] {
            case 0x20, 0x09, 0x0A, 0x0D, 0x0C, UInt8(ascii: ","): offset += 1
            default: return
            }
        }
    }

    func commandLetter() -> UInt8? {
        guard !isAtEnd else { return nil }
        let byte = bytes[offset]
        return Self.commands.contains(byte) ? byte : nil
    }

    var startsNumber: Bool {
        guard !isAtEnd else { return false }
        let byte = bytes[offset]
        return Self.isDigit(byte) || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+") || byte == UInt8(ascii: ".")
    }

    mutating func number(command: Character) throws -> CGFloat {
        skipSeparators()
        let start = offset
        if offset < bytes.count, bytes[offset] == UInt8(ascii: "-") || bytes[offset] == UInt8(ascii: "+") {
            offset += 1
        }
        var sawDigits = false
        while offset < bytes.count, Self.isDigit(bytes[offset]) { offset += 1; sawDigits = true }
        if offset < bytes.count, bytes[offset] == UInt8(ascii: ".") {
            offset += 1
            while offset < bytes.count, Self.isDigit(bytes[offset]) { offset += 1; sawDigits = true }
        }
        guard sawDigits else {
            offset = start
            throw SVGPathError.missingNumber(command: command, offset: start)
        }
        if offset < bytes.count, bytes[offset] == UInt8(ascii: "e") || bytes[offset] == UInt8(ascii: "E") {
            var lookahead = offset + 1
            if lookahead < bytes.count, bytes[lookahead] == UInt8(ascii: "-") || bytes[lookahead] == UInt8(ascii: "+") {
                lookahead += 1
            }
            if lookahead < bytes.count, Self.isDigit(bytes[lookahead]) {
                offset = lookahead
                while offset < bytes.count, Self.isDigit(bytes[offset]) { offset += 1 }
            }
        }
        let text = String(decoding: bytes[start..<offset], as: UTF8.self)
        guard let value = Double(text), value.isFinite else {
            throw SVGPathError.missingNumber(command: command, offset: start)
        }
        return CGFloat(value)
    }

    /// Arc flags are single `0`/`1` characters and may be written without separators.
    mutating func flag(command: Character) throws -> Bool {
        skipSeparators()
        guard offset < bytes.count else { throw SVGPathError.missingNumber(command: command, offset: offset) }
        switch bytes[offset] {
        case UInt8(ascii: "0"): offset += 1; return false
        case UInt8(ascii: "1"): offset += 1; return true
        default: throw SVGPathError.missingNumber(command: command, offset: offset)
        }
    }

    private static let commands = Set("MmLlHhVvCcSsQqTtAaZz".utf8)

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }
}
