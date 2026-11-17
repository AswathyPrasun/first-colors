import CoreGraphics
import Foundation

/// A point in drawing coordinates (the SVG viewBox space), never screen points,
/// so strokes line up on every device size. `Float` keeps saved strokes compact.
struct StrokePoint: Codable, Hashable, Sendable {
    var x: Float
    var y: Float

    init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        x = Float(point.x)
        y = Float(point.y)
    }

    var cgPoint: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
}

/// One crayon stroke, clipped to the region where it started (CLAUDE.md §6).
struct Stroke: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let regionId: String
    /// `#RRGGBB`
    let color: String
    /// Brush width in drawing units.
    let width: Float
    var points: [StrokePoint]

    init(id: UUID = UUID(), regionId: String, color: String, width: Float, points: [StrokePoint] = []) {
        self.id = id
        self.regionId = regionId
        self.color = color
        self.width = width
        self.points = points
    }
}
