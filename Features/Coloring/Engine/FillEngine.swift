import CoreGraphics
import SwiftUI

/// Hit-testing for taps on the drawing. All coordinates are drawing units.
enum FillEngine {
    /// Extra reach around a tap so toddlers can hit thin parts (stems) or land on the outline.
    static let defaultSlop: CGFloat = 12

    /// Regions ordered smallest first, so a tap near a stem picks the stem, not the big body.
    static func smallestFirst(_ drawing: Drawing) -> [DrawingRegion] {
        drawing.regions.sorted {
            let a = $0.bounds.width * $0.bounds.height
            let b = $1.bounds.width * $1.bounds.height
            return a == b ? $0.id < $1.id : a < b
        }
    }

    /// The region under `point`, or the smallest region within `slop` of it.
    static func regionId(at point: CGPoint, in drawing: Drawing, slop: CGFloat = defaultSlop) -> String? {
        let ordered = smallestFirst(drawing)
        // Visible paths never overlap, so at most one region contains the point exactly.
        if let direct = ordered.first(where: { $0.visiblePath.contains(point) }) {
            return direct.id
        }
        guard slop > 0 else { return nil }
        // Probe two rings around the point; the smallest region touched wins.
        var probes: [CGPoint] = []
        for radius in [slop / 2, slop] {
            for k in 0..<8 {
                let angle = CGFloat(k) * .pi / 4
                probes.append(CGPoint(x: point.x + radius * cos(angle), y: point.y + radius * sin(angle)))
            }
        }
        return ordered.first { region in
            region.bounds.insetBy(dx: -slop, dy: -slop).contains(point)
                && probes.contains { region.visiblePath.contains($0) }
        }?.id
    }

    /// The region suggestions start on: the largest one (e.g. the apple body).
    static func largestRegionId(in drawing: Drawing) -> String? {
        smallestFirst(drawing).last?.id
    }

    /// Magic: every region gets its first suggested color (regions without suggestions keep theirs).
    static func magicFills(for drawing: Drawing, current: [String: String]) -> [String: String] {
        var fills = current
        for region in drawing.regions {
            if let first = region.suggested.first { fills[region.id] = first }
        }
        return fills
    }
}
