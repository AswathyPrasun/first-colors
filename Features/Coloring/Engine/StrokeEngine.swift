import CoreGraphics
import SwiftUI

/// Crayon constants in drawing units (300-unit drawing shown at ~340pt).
enum CrayonStyle {
    /// ≈ 22pt on a 340pt canvas (CLAUDE.md: 18–24pt).
    static let width: Float = 19.5
    static let opacity: Double = 0.92
    /// Drop points closer than this many *screen points* to the previous one.
    static let minPointSpacing: CGFloat = 2
    /// Eraser reach around the finger.
    static let eraserRadius: CGFloat = 14
    /// A gesture that moves less than this (drawing units) counts as a tap.
    static let tapTolerance: CGFloat = 9
    /// Cap on points per drawing (CLAUDE.md §8); past it we celebrate instead of erroring.
    static let maxPointsPerDrawing = 50_000
}

/// Accumulates one stroke's points while the finger moves.
struct StrokeBuilder {
    private(set) var stroke: Stroke
    /// Minimum distance between kept points, in drawing units.
    let minDistance: CGFloat

    init(regionId: String, color: String, start: CGPoint, minDistance: CGFloat,
         width: Float = CrayonStyle.width) {
        stroke = Stroke(regionId: regionId, color: color, width: width, points: [StrokePoint(start)])
        self.minDistance = minDistance
    }

    /// Adds `point` unless it is too close to the last kept point. Returns whether it was kept.
    @discardableResult
    mutating func add(_ point: CGPoint) -> Bool {
        if let last = stroke.points.last?.cgPoint, hypot(point.x - last.x, point.y - last.y) < minDistance {
            return false
        }
        stroke.points.append(StrokePoint(point))
        return true
    }
}

enum StrokeGeometry {
    /// Smooth path through the points: quadratic curves through the midpoints.
    /// A single point becomes a zero-length line, which round caps draw as a dot.
    /// Built as a `CGMutablePath` directly (the bitmap cache draws thousands of these).
    static func cgPath(for points: [StrokePoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first?.cgPoint else { return path }
        path.move(to: first)
        switch points.count {
        case 1:
            path.addLine(to: first)
        case 2:
            path.addLine(to: points[1].cgPoint)
        default:
            path.addLine(to: midpoint(first, points[1].cgPoint))
            for index in 1..<(points.count - 1) {
                let control = points[index].cgPoint
                path.addQuadCurve(to: midpoint(control, points[index + 1].cgPoint), control: control)
            }
            path.addLine(to: points[points.count - 1].cgPoint)
        }
        return path
    }

    static func path(for points: [StrokePoint]) -> Path {
        Path(cgPath(for: points))
    }

    static func strokeStyle(width: Float) -> StrokeStyle {
        StrokeStyle(lineWidth: CGFloat(width), lineCap: .round, lineJoin: .round)
    }

    /// Does an eraser at `point` (radius `radius`) touch the stroke?
    static func stroke(_ stroke: Stroke, isTouchedAt point: CGPoint, radius: CGFloat) -> Bool {
        let reach = radius + CGFloat(stroke.width) / 2
        let reach2 = reach * reach
        let points = stroke.points
        guard let first = points.first?.cgPoint else { return false }
        if points.count == 1 { return distanceSquared(point, first) <= reach2 }
        for index in 1..<points.count {
            if distanceSquared(point, toSegment: points[index - 1].cgPoint, points[index].cgPoint) <= reach2 {
                return true
            }
        }
        return false
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private static func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
    }

    private static func distanceSquared(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let length2 = dx * dx + dy * dy
        guard length2 > 0 else { return distanceSquared(p, a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length2))
        return distanceSquared(p, CGPoint(x: a.x + t * dx, y: a.y + t * dy))
    }
}
