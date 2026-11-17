import CoreGraphics
import Foundation
import Testing
@testable import KidsColoring

struct FillEngineTests {
    let drawing = TestDrawings.squares()

    @Test func pointInRegion() {
        #expect(FillEngine.regionId(at: CGPoint(x: 30, y: 30), in: drawing) == "body")
        #expect(FillEngine.regionId(at: CGPoint(x: 250, y: 100), in: drawing) == "leaf")
        #expect(FillEngine.regionId(at: CGPoint(x: 150, y: 80), in: drawing) == "stem")
    }

    @Test func regionDrawnOnTopWinsWhereShapesOverlap() {
        // (80, 80) is inside both "body" and "dot"; the dot is on top.
        #expect(FillEngine.regionId(at: CGPoint(x: 80, y: 80), in: drawing) == "dot")
        #expect(drawing.region(id: "body")?.visiblePath.contains(CGPoint(x: 80, y: 80)) == false)
    }

    @Test func smallRegionsAreCheckedFirst() {
        let order = FillEngine.smallestFirst(drawing).map(\.id)
        #expect(order.first == "stem")
        #expect(Set(order.suffix(2)) == Set(["body", "leaf"]))
    }

    @Test func slopPicksTheSmallestNearbyRegion() {
        // Just outside the thin stem, in the gap toward the body: the stem wins over the body.
        #expect(FillEngine.regionId(at: CGPoint(x: 143, y: 80), in: drawing) == "stem")
        // Far from everything: nothing.
        #expect(FillEngine.regionId(at: CGPoint(x: 150, y: 250), in: drawing) == nil)
        // No slop: the gap is empty.
        #expect(FillEngine.regionId(at: CGPoint(x: 142, y: 80), in: drawing, slop: 0) == nil)
    }

    @Test func largestRegionStartsTheSuggestions() {
        #expect(["body", "leaf"].contains(FillEngine.largestRegionId(in: drawing)))
    }

    @Test func magicUsesFirstSuggestionAndKeepsRegionsWithoutOne() {
        let fills = FillEngine.magicFills(for: drawing, current: ["dot": "#1E88E5", "body": "#FDD835"])
        #expect(fills == ["body": "#E53935", "leaf": "#43A047", "stem": "#6D4C41", "dot": "#1E88E5"])
    }
}

struct StrokeEngineTests {
    @Test func dropsPointsCloserThanMinimumSpacing() {
        var builder = StrokeBuilder(regionId: "body", color: "#E53935", start: .zero, minDistance: 2)
        // 1.41 < 2 is dropped, 2 is kept, 3 is dropped (1 away), 5 is kept.
        let kept = [CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 0), CGPoint(x: 3, y: 0), CGPoint(x: 5, y: 0)]
            .map { builder.add($0) }
        #expect(kept == [false, true, false, true])
        #expect(builder.stroke.points.map(\.x) == [0, 2, 5])
        #expect(builder.stroke.width == CrayonStyle.width)
    }

    @Test func smoothedPathPassesThroughEndsAndUsesQuadCurves() {
        let points = [StrokePoint(x: 0, y: 0), StrokePoint(x: 10, y: 10), StrokePoint(x: 20, y: 0), StrokePoint(x: 30, y: 10)]
        var quads = 0
        var last = CGPoint.zero
        StrokeGeometry.path(for: points).forEach { element in
            switch element {
            case .quadCurve(let to, _): quads += 1; last = to
            case .line(let to): last = to
            default: break
            }
        }
        #expect(quads == 2)
        #expect(last == CGPoint(x: 30, y: 10))
    }

    @Test func singlePointMakesADot() {
        let path = StrokeGeometry.path(for: [StrokePoint(x: 5, y: 5)])
        #expect(!path.isEmpty)
        #expect(StrokeGeometry.path(for: []).isEmpty)
    }

    @Test func eraserTouchesStrokesWithinReach() {
        let stroke = Stroke(regionId: "body", color: "#E53935", width: 10,
                            points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 100, y: 0)])
        #expect(StrokeGeometry.stroke(stroke, isTouchedAt: CGPoint(x: 50, y: 15), radius: 12))   // 15 ≤ 12+5
        #expect(!StrokeGeometry.stroke(stroke, isTouchedAt: CGPoint(x: 50, y: 20), radius: 12))
        #expect(StrokeGeometry.stroke(stroke, isTouchedAt: CGPoint(x: 110, y: 0), radius: 12))   // past the end cap
    }
}

struct ColoringStateTests {
    private let stroke1 = Stroke(regionId: "body", color: "#E53935", width: 20, points: [StrokePoint(x: 1, y: 1)])
    private let stroke2 = Stroke(regionId: "leaf", color: "#43A047", width: 20, points: [StrokePoint(x: 2, y: 2)])
    private let stroke3 = Stroke(regionId: "body", color: "#1E88E5", width: 20, points: [StrokePoint(x: 3, y: 3)])

    @Test func fillAndRevert() {
        var state = ColoringState()
        let action = ColoringAction.fill(regionId: "body", oldColor: nil, newColor: "#E53935")
        state.apply(action)
        #expect(state.fills == ["body": "#E53935"])
        state.revert(action)
        #expect(state.fills.isEmpty)
    }

    @Test func strokeAndRevert() {
        var state = ColoringState()
        state.apply(.stroke(stroke1))
        #expect(state.strokes == [stroke1])
        #expect(state.totalPoints == 1)
        state.revert(.stroke(stroke1))
        #expect(state.strokes.isEmpty)
    }

    @Test func eraseRevertRestoresOriginalOrderAndFills() {
        var state = ColoringState(fills: ["body": "#E53935"], strokes: [stroke1, stroke2, stroke3])
        let action = ColoringAction.erase(
            removed: [RemovedStroke(index: 2, stroke: stroke3), RemovedStroke(index: 0, stroke: stroke1)],
            clearedFills: ["body": "#E53935"])
        state.apply(action)
        #expect(state.strokes == [stroke2])
        #expect(state.fills.isEmpty)
        state.revert(action)
        #expect(state.strokes == [stroke1, stroke2, stroke3])
        #expect(state.fills == ["body": "#E53935"])
    }

    @Test func magicAndRevert() {
        var state = ColoringState(fills: ["leaf": "#1E88E5"])
        let action = ColoringAction.magic(previousFills: ["leaf": "#1E88E5"], newFills: ["leaf": "#43A047", "body": "#E53935"])
        state.apply(action)
        #expect(state.fills == ["leaf": "#43A047", "body": "#E53935"])
        state.revert(action)
        #expect(state.fills == ["leaf": "#1E88E5"])
    }

    @Test func undoStackIsCappedAndLIFO() {
        var stack = UndoStack(limit: 3)
        for index in 0..<5 {
            stack.push(.fill(regionId: "r\(index)", oldColor: nil, newColor: "#E53935"))
        }
        #expect(stack.actions.count == 3)
        var popped: [ColoringAction?] = []
        for _ in 0..<4 { popped.append(stack.pop()) }
        #expect(popped == [
            .fill(regionId: "r4", oldColor: nil, newColor: "#E53935"),
            .fill(regionId: "r3", oldColor: nil, newColor: "#E53935"),
            .fill(regionId: "r2", oldColor: nil, newColor: "#E53935"),
            nil,
        ])
        #expect(UndoStack().limit == 50)
    }
}

/// Crayon clipping, checked on real pixels.
struct StrokeRasterizerTests {
    let drawing = TestDrawings.squares()

    private func alpha(_ image: CGImage, at point: CGPoint, scale: CGFloat) -> UInt8 {
        // Draw the single pixel into a 1×1 buffer to read it back.
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let x = point.x * scale, y = point.y * scale
        context.draw(image, in: CGRect(x: -x, y: -(CGFloat(image.height) - y - 1),
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        return pixel[3]
    }

    @Test func strokeIsClippedToItsStartingRegion() throws {
        // Horizontal stroke from inside "body" across the stem into "leaf".
        let stroke = Stroke(regionId: "body", color: "#E53935", width: 20,
                            points: [StrokePoint(x: 30, y: 120), StrokePoint(x: 270, y: 120)])
        let rasterizer = StrokeRasterizer()
        // Canvas == viewBox size so drawing units map 1:1 to points.
        let image = try #require(rasterizer.image(strokes: [stroke], drawing: drawing,
                                                  size: CGSize(width: 300, height: 300), scale: 1))
        #expect(alpha(image, at: CGPoint(x: 50, y: 120), scale: 1) > 200)     // inside body: painted
        #expect(alpha(image, at: CGPoint(x: 150, y: 120), scale: 1) == 0)     // stem: clipped
        #expect(alpha(image, at: CGPoint(x: 220, y: 120), scale: 1) == 0)     // leaf: clipped
        #expect(alpha(image, at: CGPoint(x: 50, y: 150), scale: 1) == 0)      // below the body: clipped
    }

    @Test func strokesUnderAnUpperRegionAreHidden() throws {
        // The dot sits on top of the body; a body stroke must not paint over it.
        let stroke = Stroke(regionId: "body", color: "#E53935", width: 20,
                            points: [StrokePoint(x: 30, y: 80), StrokePoint(x: 130, y: 80)])
        let image = try #require(StrokeRasterizer().image(strokes: [stroke], drawing: drawing,
                                                          size: CGSize(width: 300, height: 300), scale: 1))
        #expect(alpha(image, at: CGPoint(x: 40, y: 80), scale: 1) > 200)
        #expect(alpha(image, at: CGPoint(x: 80, y: 80), scale: 1) == 0)
    }

    @Test func appendIsIncrementalAndRemovalRedrawsOnlyThatRegion() throws {
        let rasterizer = StrokeRasterizer()
        let size = CGSize(width: 300, height: 300)
        let a = Stroke(regionId: "body", color: "#E53935", width: 20, points: [StrokePoint(x: 30, y: 30)])
        let b = Stroke(regionId: "leaf", color: "#43A047", width: 20, points: [StrokePoint(x: 200, y: 30)])
        _ = rasterizer.image(strokes: [a], drawing: drawing, size: size, scale: 1)
        _ = rasterizer.image(strokes: [a, b], drawing: drawing, size: size, scale: 1)
        #expect(rasterizer.regionRedrawCount == 0)       // both were appends
        let image = try #require(rasterizer.image(strokes: [b], drawing: drawing, size: size, scale: 1))
        #expect(rasterizer.regionRedrawCount == 1)       // only "body" was cleared
        #expect(rasterizer.contextCreationCount == 1)
        #expect(alpha(image, at: CGPoint(x: 30, y: 30), scale: 1) == 0)   // a was removed
        #expect(alpha(image, at: CGPoint(x: 200, y: 30), scale: 1) > 200)
    }

    @Test func undoingNewestStrokeRestoresTheSnapshotExactly() throws {
        let rasterizer = StrokeRasterizer()
        let size = CGSize(width: 300, height: 300)
        let a = Stroke(regionId: "body", color: "#E53935", width: 20, points: [StrokePoint(x: 30, y: 30)])
        let b = Stroke(regionId: "body", color: "#1E88E5", width: 20, points: [StrokePoint(x: 120, y: 120)])
        _ = rasterizer.image(strokes: [a], drawing: drawing, size: size, scale: 1)
        _ = rasterizer.image(strokes: [a, b], drawing: drawing, size: size, scale: 1)
        let image = try #require(rasterizer.image(strokes: [a], drawing: drawing, size: size, scale: 1))
        #expect(rasterizer.snapshotRestoreCount == 1)
        #expect(rasterizer.regionRedrawCount == 0)
        #expect(alpha(image, at: CGPoint(x: 30, y: 30), scale: 1) > 200)
        #expect(alpha(image, at: CGPoint(x: 120, y: 120), scale: 1) == 0)
        // Drawing again after the restore keeps working.
        let again = try #require(rasterizer.image(strokes: [a, b], drawing: drawing, size: size, scale: 1))
        #expect(alpha(again, at: CGPoint(x: 120, y: 120), scale: 1) > 200)
    }

    @Test func strokesForUnknownRegionsAreSkipped() throws {
        let ghost = Stroke(regionId: "ghost", color: "#E53935", width: 20, points: [StrokePoint(x: 30, y: 30)])
        let image = try #require(StrokeRasterizer().image(strokes: [ghost], drawing: drawing,
                                                          size: CGSize(width: 300, height: 300), scale: 1))
        #expect(alpha(image, at: CGPoint(x: 30, y: 30), scale: 1) == 0)
    }

    @Test func strokesLineUpOnDifferentCanvasSizes() throws {
        // Same stroke, iPhone-ish and iPad-ish canvases: the painted spot maps to the same drawing point.
        let stroke = Stroke(regionId: "body", color: "#E53935", width: 20, points: [StrokePoint(x: 50, y: 50)])
        for (side, scale) in [(CGFloat(340), CGFloat(2)), (CGFloat(700), CGFloat(2)), (CGFloat(320), CGFloat(1))] {
            let image = try #require(StrokeRasterizer().image(strokes: [stroke], drawing: drawing,
                                                              size: CGSize(width: side, height: side), scale: scale))
            let unit = side / 300
            #expect(alpha(image, at: CGPoint(x: 50 * unit, y: 50 * unit), scale: scale) > 200)
            #expect(alpha(image, at: CGPoint(x: 50 * unit + 25 * unit, y: 50 * unit), scale: scale) == 0)
        }
    }
}
