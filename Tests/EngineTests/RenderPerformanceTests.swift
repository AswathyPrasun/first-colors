import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import KidsColoring

/// Long-session performance: 2,000 strokes on the apple (CLAUDE.md §11 / build prompt §7).
///
/// Optional: `TEST_RUNNER_PERF_REPORT_DIR=/some/folder` writes the timings to `perf.txt`.
struct RenderPerformanceTests {
    private let canvas = CGSize(width: 340, height: 340)
    private let displayScale: CGFloat = 3

    private func strokes(on drawing: Drawing, count: Int, pointsEach: Int = 30) -> [Stroke] {
        let regions = drawing.regions
        return (0..<count).map { index in
            let region = regions[index % regions.count]
            let box = region.bounds
            var x = CGFloat.random(in: box.minX...box.maxX)
            var y = CGFloat.random(in: box.minY...box.maxY)
            let points = (0..<pointsEach).map { _ -> StrokePoint in
                x += CGFloat.random(in: -6...6)
                y += CGFloat.random(in: -6...6)
                return StrokePoint(CGPoint(x: x, y: y))
            }
            return Stroke(regionId: region.id, color: KidPalette.colors[index % 8].hex,
                          width: CrayonStyle.width, points: points)
        }
    }

    private func milliseconds(_ body: () -> Void) -> Double {
        let elapsed = ContinuousClock().measure(body)
        return Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
    }

    private func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }

    /// One on-screen frame while drawing, done the same way the layers do it:
    /// fills + cached stroke bitmap + live stroke (clipped) + outlines and face.
    private func renderFrame(drawing: Drawing, fills: [String: CGColor], strokeImage: CGImage,
                             live: Stroke, into ctx: CGContext) {
        let transform = DrawingRenderer.transform(for: drawing.viewBox, in: canvas)
        ctx.saveGState()
        ctx.clear(CGRect(origin: .zero, size: canvas))
        ctx.saveGState()
        ctx.concatenate(transform)
        for region in drawing.regions {
            ctx.addPath(region.visiblePath.cgPath)
            ctx.setFillColor(fills[region.id] ?? CGColor(gray: 1, alpha: 1))
            ctx.fillPath()
        }
        ctx.restoreGState()
        ctx.draw(strokeImage, in: CGRect(origin: .zero, size: canvas))
        ctx.concatenate(transform)
        if let region = drawing.region(id: live.regionId) {
            ctx.saveGState()
            ctx.addPath(region.visiblePath.cgPath)
            ctx.clip()
            ctx.setLineWidth(CGFloat(live.width))
            ctx.setLineCap(.round)
            ctx.setStrokeColor(CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.92))
            ctx.addPath(StrokeGeometry.path(for: live.points).cgPath)
            ctx.strokePath()
            ctx.restoreGState()
        }
        ctx.setFillColor(CGColor(gray: 0.12, alpha: 1))
        for region in drawing.regions {
            ctx.addPath(region.outline.cgPath)
            ctx.fillPath()
        }
        for detail in drawing.details {
            ctx.addPath(detail.path.cgPath)
            if detail.style == .fill { ctx.fillPath() } else {
                ctx.setLineWidth(DrawingStyle.detailLineWidth)
                ctx.strokePath()
            }
        }
        ctx.restoreGState()
    }

    @Test func twoThousandStrokesStayUnderOneFrame() throws {
        let drawing = try #require(ContentRepository(bundle: .main).drawing(for: "apple"))
        let all = strokes(on: drawing, count: 2_000)
        let rasterizer = StrokeRasterizer()

        // Opening a drawing that already has 2,000 strokes (one-time, when the screen appears).
        let initialBuild = milliseconds {
            _ = rasterizer.image(strokes: all, drawing: drawing, size: canvas, scale: displayScale)
        }

        // Lifting the finger: one more stroke is drawn on top of the cached bitmap.
        let extra = strokes(on: drawing, count: 2)
        let append = milliseconds {
            _ = rasterizer.image(strokes: all + [extra[0]], drawing: drawing, size: canvas, scale: displayScale)
        }
        #expect(rasterizer.regionRedrawCount == 0)

        // Undo of the newest stroke: the bitmap from before it is restored.
        let undo = milliseconds {
            _ = rasterizer.image(strokes: all, drawing: drawing, size: canvas, scale: displayScale)
        }
        #expect(rasterizer.snapshotRestoreCount == 1)

        // An older undo (or eraser) clears and redraws just one region.
        let regionRedraw = milliseconds {
            _ = rasterizer.image(strokes: Array(all.dropLast()), drawing: drawing, size: canvas, scale: displayScale)
        }
        #expect(rasterizer.regionRedrawCount == 1)

        let strokeImage = try #require(rasterizer.image(strokes: all, drawing: drawing, size: canvas, scale: displayScale))
        let live = strokes(on: drawing, count: 1, pointsEach: 150)[0]
        let fills = Dictionary(uniqueKeysWithValues: drawing.regions.map {
            ($0.id, CGColor(red: 0.98, green: 0.55, blue: 0, alpha: 1))
        })
        func makeContext() throws -> CGContext {
            let ctx = try #require(CGContext(
                data: nil, width: Int(canvas.width * displayScale), height: Int(canvas.height * displayScale),
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.translateBy(x: 0, y: canvas.height * displayScale)
            ctx.scaleBy(x: displayScale, y: -displayScale)
            return ctx
        }
        let transform = DrawingRenderer.transform(for: drawing.viewBox, in: canvas)

        // While the finger moves, only the live-stroke layer re-renders (its own Canvas).
        let liveContext = try makeContext()
        let liveFrames = (0..<20).map { _ in
            milliseconds {
                liveContext.saveGState()
                liveContext.clear(CGRect(origin: .zero, size: canvas))
                liveContext.concatenate(transform)
                if let region = drawing.region(id: live.regionId) {
                    liveContext.addPath(region.visiblePath.cgPath)
                    liveContext.clip()
                }
                liveContext.setLineWidth(CGFloat(live.width))
                liveContext.setLineCap(.round)
                liveContext.setLineJoin(.round)
                liveContext.setStrokeColor(CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.92))
                liveContext.addPath(StrokeGeometry.cgPath(for: live.points))
                liveContext.strokePath()
                liveContext.restoreGState()
            }
        }
        let liveFrame = median(liveFrames)

        // Every layer at once on the CPU (what a first appearance or rotation costs).
        // On device the layers are separate GPU-composited Canvases, so this over-states a frame.
        let allContext = try makeContext()
        renderFrame(drawing: drawing, fills: fills, strokeImage: strokeImage, live: live, into: allContext)
        let allLayers = median((0..<10).map { _ in
            milliseconds { renderFrame(drawing: drawing, fills: fills, strokeImage: strokeImage, live: live, into: allContext) }
        })

        let report = String(
            format: "perf (2,000 strokes): first build %.0fms, finish stroke %.2fms, undo newest %.2fms, older undo %.0fms, live frame %.2fms, all layers on CPU %.1fms",
            initialBuild, append, undo, regionRedraw, liveFrame, allLayers)
        print(report)
        if let dir = ProcessInfo.processInfo.environment["PERF_REPORT_DIR"] {
            try? report.write(toFile: dir + "/perf.txt", atomically: true, encoding: .utf8)
        }

        #expect(liveFrame < 16, "a live drawing frame took \(liveFrame)ms")
        #expect(append < 16, "finishing a stroke took \(append)ms")
        #expect(undo < 16, "undoing the newest stroke took \(undo)ms")
        #expect(allLayers < 33, "drawing every layer took \(allLayers)ms")
        #expect(regionRedraw < 500, "older undo took \(regionRedraw)ms")
        #expect(initialBuild < 1_000, "initial build took \(initialBuild)ms")
    }
}
