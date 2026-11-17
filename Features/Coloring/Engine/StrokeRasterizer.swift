import CoreGraphics
import SwiftUI

/// Cached bitmap of all *finished* crayon strokes (CLAUDE.md §6 performance).
///
/// Visible region shapes never overlap, so each region's strokes are tracked separately:
/// - a new stroke is drawn on top of the bitmap (cheap);
/// - undo / erase clears and redraws only the regions whose strokes changed;
/// - the in-progress stroke is never drawn here (`LiveStrokeLayer` draws it on top).
/// Each stroke is clipped to the visible shape of the region where it started.
///
/// Not thread-safe: one thread at a time. It may be built on a background task and then
/// handed to the main thread (hence `@unchecked Sendable`), but never shared concurrently.
final class StrokeRasterizer: @unchecked Sendable {
    /// Crayon has soft edges; 2× is indistinguishable from 3× and has 2.25× fewer pixels.
    static let maxScale: CGFloat = 2

    private struct Key: Equatable {
        let itemId: String
        let pixelWidth: Int
        let pixelHeight: Int
    }

    private var key: Key?
    private var context: CGContext?
    private var drawn: [String: [UUID]] = [:]
    private var cachedImage: CGImage?
    private var clipPaths: [String: CGPath] = [:]
    private var clearRect: CGRect = .zero
    /// Bitmap and bookkeeping from just before the last single-stroke append,
    /// so undoing the newest stroke (the most common undo) is instant.
    private var snapshot: (image: CGImage, drawn: [String: [UUID]])?

    /// How many times a region had to be cleared and redrawn (exposed for tests).
    private(set) var regionRedrawCount = 0
    /// How many times the whole bitmap was (re)created (exposed for tests).
    private(set) var contextCreationCount = 0
    /// How many times an undo was served from the snapshot (exposed for tests).
    private(set) var snapshotRestoreCount = 0

    func image(strokes: [Stroke], drawing: Drawing, size: CGSize, scale displayScale: CGFloat) -> CGImage? {
        let scale = min(displayScale, Self.maxScale)
        let pixelWidth = Int((size.width * scale).rounded())
        let pixelHeight = Int((size.height * scale).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        let newKey = Key(itemId: drawing.itemId, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        if newKey != key || context == nil {
            guard makeContext(for: newKey, drawing: drawing, size: size, scale: scale) else { return nil }
        }

        // Group by region, keeping each region's stroke order.
        var groups: [String: [Stroke]] = [:]
        for stroke in strokes { groups[stroke.regionId, default: []].append(stroke) }
        let target = groups.mapValues { $0.map(\.id) }

        if target == drawn { return cachedImage ?? context?.makeImage() }

        // Undo of the newest stroke: put the previous bitmap back.
        if let snapshot, snapshot.drawn == target {
            restore(snapshot.image)
            drawn = snapshot.drawn
            cachedImage = snapshot.image
            self.snapshot = nil
            snapshotRestoreCount += 1
            return cachedImage
        }

        // Exactly one new stroke on top: remember the current bitmap first.
        let added = strokes.count - drawn.values.reduce(0) { $0 + $1.count }
        if added == 1, let current = cachedImage, isPureAppend(target) {
            snapshot = (current, drawn)
        } else {
            snapshot = nil
        }

        var changed = cachedImage == nil
        for (regionId, regionStrokes) in groups {
            let ids = regionStrokes.map(\.id)
            let old = drawn[regionId] ?? []
            guard ids != old else { continue }
            if ids.count > old.count, Array(ids.prefix(old.count)) == old {
                draw(regionStrokes[old.count...], in: regionId)
            } else {
                clear(regionId)
                draw(regionStrokes[...], in: regionId)
            }
            drawn[regionId] = ids
            changed = true
        }
        for regionId in Array(drawn.keys) where groups[regionId] == nil {
            clear(regionId)
            drawn[regionId] = nil
            changed = true
        }
        if changed { cachedImage = context?.makeImage() }
        return cachedImage
    }

    private func isPureAppend(_ target: [String: [UUID]]) -> Bool {
        for (regionId, old) in drawn {
            guard let ids = target[regionId], ids.count >= old.count, Array(ids.prefix(old.count)) == old else {
                return false
            }
        }
        return true
    }

    private func restore(_ image: CGImage) {
        guard let ctx = context else { return }
        ctx.saveGState()
        ctx.concatenate(ctx.ctm.inverted())   // back to raw pixel space
        let rect = CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height)
        ctx.clear(rect)
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }

    private func makeContext(for newKey: Key, drawing: Drawing, size: CGSize, scale: CGFloat) -> Bool {
        guard let ctx = CGContext(
            data: nil, width: newKey.pixelWidth, height: newKey.pixelHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        // Flip to a top-left origin, then map drawing units to pixels.
        ctx.translateBy(x: 0, y: CGFloat(newKey.pixelHeight))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.concatenate(DrawingRenderer.transform(for: drawing.viewBox, in: size))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        context = ctx
        key = newKey
        drawn = [:]
        cachedImage = nil
        snapshot = nil
        clipPaths = Dictionary(uniqueKeysWithValues: drawing.regions.map { ($0.id, $0.visiblePath.cgPath) })
        clearRect = drawing.viewBox.insetBy(dx: -drawing.viewBox.width, dy: -drawing.viewBox.height)
        contextCreationCount += 1
        return true
    }

    private func clear(_ regionId: String) {
        guard let ctx = context, let clip = clipPaths[regionId] else { return }
        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        ctx.clear(clearRect)
        ctx.restoreGState()
        regionRedrawCount += 1
    }

    private func draw(_ strokes: ArraySlice<Stroke>, in regionId: String) {
        // Strokes for regions that no longer exist (old saves) are skipped.
        guard let ctx = context, let clip = clipPaths[regionId], !strokes.isEmpty else { return }
        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        for stroke in strokes {
            guard let rgb = HexColor.parse(stroke.color) else { continue }
            ctx.setStrokeColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                               green: CGFloat((rgb >> 8) & 0xFF) / 255,
                               blue: CGFloat(rgb & 0xFF) / 255,
                               alpha: CrayonStyle.opacity)
            ctx.setLineWidth(CGFloat(stroke.width))
            ctx.addPath(StrokeGeometry.cgPath(for: stroke.points))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
}
