import CoreGraphics
import SwiftUI

/// Line widths in drawing units (a 300×300 drawing shown at ~340pt ≈ 7pt outlines).
enum DrawingStyle {
    static let outlineWidth: CGFloat = 6.5
    static let detailLineWidth: CGFloat = 5.5
}

/// A fillable region, ready to render and hit-test. All geometry is in drawing coordinates.
struct DrawingRegion: Identifiable, Sendable {
    let id: String
    /// Normalized `#RRGGBB` suggestions, best first.
    let suggested: [String]
    /// The shape as authored.
    let path: Path
    /// The part of the shape that is actually visible (authored shape minus every region drawn
    /// above it). Fills, crayon clipping and hit-testing all use this, so regions never overlap.
    let visiblePath: Path
    /// The region's outline as a filled shape, with the parts hidden under higher regions removed.
    let outline: Path

    var bounds: CGRect { visiblePath.boundingRect }
}

/// Face and decoration drawn on top of everything; never fillable.
struct DrawingDetail: Sendable {
    enum Style: Sendable { case fill, stroke }
    let path: Path
    let style: Style
}

/// A parsed, render-ready drawing. Regions are in z-order (first = bottom).
struct Drawing: Sendable {
    let itemId: String
    let viewBox: CGRect
    let regions: [DrawingRegion]
    let details: [DrawingDetail]

    func region(id: String) -> DrawingRegion? {
        regions.first { $0.id == id }
    }
}

enum DrawingBuilder {
    /// Combines the content spec (which regions exist, suggested colors) with the SVG geometry.
    /// Regions listed in JSON but missing from the SVG are skipped and logged; id'd SVG shapes
    /// that are not listed in JSON are drawn as plain lines so the art still looks complete.
    static func build(item: ContentItem, document: SVGDocument) -> Drawing {
        let specs = Dictionary(item.regions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var regionShapes: [(spec: RegionSpec, path: Path)] = []
        var details: [DrawingDetail] = []

        for shape in document.shapes {
            if !shape.isDetail, let id = shape.id, let spec = specs[id], seen.insert(id).inserted {
                regionShapes.append((spec, shape.path))
            } else if shape.isDetail {
                details.append(DrawingDetail(path: shape.path, style: shape.kind == .path ? .stroke : .fill))
            } else {
                details.append(DrawingDetail(path: shape.path, style: .stroke))
            }
        }

        for spec in item.regions where !seen.contains(spec.id) {
            Log.content.error("\(item.id, privacy: .public): region \(spec.id, privacy: .public) missing from SVG")
        }

        let outlineStyle = StrokeStyle(lineWidth: DrawingStyle.outlineWidth, lineCap: .round, lineJoin: .round)
        var regions: [DrawingRegion] = []
        var above = Path()   // union of everything drawn above the current region

        for (spec, path) in regionShapes.reversed() {
            let stroked = path.strokedPath(outlineStyle)
            let covered = !above.isEmpty && above.boundingRect.intersects(stroked.boundingRect)
            let visible = covered ? path.subtracting(above) : path
            let outline = covered ? stroked.subtracting(above) : stroked
            regions.append(DrawingRegion(
                id: spec.id,
                suggested: spec.suggested.compactMap(HexColor.normalized),
                path: path,
                visiblePath: visible,
                outline: outline))
            above = above.isEmpty ? path : above.union(path)
        }

        return Drawing(itemId: item.id, viewBox: document.viewBox,
                       regions: regions.reversed(), details: details)
    }
}
