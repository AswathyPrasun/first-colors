import SwiftUI

/// The interactive drawing. Four stacked layers, each re-rendering only when its own data changes:
/// 1. white + fills (+ hint preview) · 2. cached finished strokes · 3. live stroke · 4. outlines + face.
/// Touches are converted to drawing coordinates before reaching the ViewModel.
struct DrawingCanvas: View {
    let vm: ColoringViewModel
    let drawing: Drawing

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                FillLayer(vm: vm, drawing: drawing)
                StrokeLayer(vm: vm, drawing: drawing)
                LiveStrokeLayer(vm: vm, drawing: drawing)
                OutlineLayer(drawing: drawing)
            }
            .contentShape(Rectangle())
            .gesture(drawGesture(size: size))
        }
        .aspectRatio(drawing.viewBox.width / drawing.viewBox.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text(vm.title))
        .accessibilityValue(Text(colorSummary))
        .accessibilityHint(Text("Swipe up or down to choose a part to color with \(vm.selectedColor.accessibilityName)"))
        .accessibilityActions {
            // VoiceOver can't scribble, so every part gets a "color it" action.
            ForEach(drawing.regions) { region in
                Button("Color the \(Self.spokenName(region.id))") { vm.fillRegion(region.id) }
            }
        }
        .accessibilityIdentifier("drawingCanvas")
    }

    /// "3 of 4 parts colored", so VoiceOver users know how far they are.
    private var colorSummary: String {
        let colored = drawing.regions.filter { vm.fills[$0.id] != nil }.count
        return String(localized: "\(colored) of \(drawing.regions.count) parts colored")
    }

    /// "leftLeaf" → "left leaf", "front_wheel" → "front wheel", "body" → "body".
    static func spokenName(_ regionId: String) -> String {
        var words = ""
        for character in regionId {
            if character == "_" || character == "-" {
                if !words.isEmpty, words.last != " " { words.append(" ") }
                continue
            }
            if character.isUppercase, !words.isEmpty, words.last != " " { words.append(" ") }
            words.append(character.lowercased())
        }
        return words
    }

    /// One drag gesture handles taps (fill / eraser tap) and drags (crayon / eraser).
    /// SwiftUI's drag gesture follows a single touch, so extra fingers (a resting palm) don't draw.
    private func drawGesture(size: CGSize) -> some Gesture {
        let transform = DrawingRenderer.transform(for: drawing.viewBox, in: size)
        let inverse = transform.inverted()
        let pointsPerUnit = transform.a
        return DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = value.location.applying(inverse)
                if vm.isTouchActive {
                    vm.touchMoved(to: point)
                } else {
                    vm.touchBegan(at: point, pointsPerUnit: pointsPerUnit)
                }
            }
            .onEnded { _ in vm.touchEnded() }
    }
}

private struct FillLayer: View {
    let vm: ColoringViewModel
    let drawing: Drawing

    var body: some View {
        let fills = vm.fills
        let hint = vm.isHintOn
        Canvas { context, size in
            var colors: [String: Color] = [:]
            for (regionId, hex) in fills {
                if let color = Color(hexString: hex) { colors[regionId] = color }
            }
            DrawingRenderer.drawBackgroundAndFills(drawing, fills: colors, in: context, size: size)
            guard hint else { return }
            var ctx = context
            ctx.concatenate(DrawingRenderer.transform(for: drawing.viewBox, in: size))
            for region in drawing.regions where fills[region.id] == nil {
                if let hex = region.suggested.first, let color = Color(hexString: hex) {
                    ctx.fill(region.visiblePath, with: .color(color.opacity(0.3)))
                }
            }
        }
    }
}

private struct StrokeLayer: View {
    let vm: ColoringViewModel
    let drawing: Drawing
    @State private var rasterizer: StrokeRasterizer?
    @Environment(\.displayScale) private var displayScale

    private struct PrepareKey: Hashable {
        let generation: Int
        let width: CGFloat
        let height: CGFloat
    }

    var body: some View {
        let strokes = vm.strokes
        let generation = vm.loadGeneration
        let scale = displayScale
        GeometryReader { proxy in
            let rasterizer = rasterizer
            Canvas { context, size in
                guard let rasterizer,
                      let image = rasterizer.image(strokes: strokes, drawing: drawing, size: size, scale: scale)
                else { return }
                context.draw(Image(decorative: image, scale: 1), in: CGRect(origin: .zero, size: size))
            }
            .task(id: PrepareKey(generation: generation, width: proxy.size.width, height: proxy.size.height)) {
                await prepare(size: proxy.size, scale: scale)
            }
        }
    }

    /// A freshly opened drawing with lots of saved crayon gets its first bitmap built
    /// off the main thread, so opening the screen never stutters. Later strokes are
    /// added incrementally on the main thread (cheap).
    private func prepare(size: CGSize, scale: CGFloat) async {
        let fresh = StrokeRasterizer()
        let saved = vm.strokes
        if saved.count > 100, size.width > 0 {
            let drawing = drawing
            rasterizer = await Task.detached(priority: .userInitiated) {
                _ = fresh.image(strokes: saved, drawing: drawing, size: size, scale: scale)
                return fresh
            }.value
        } else {
            rasterizer = fresh
        }
    }
}

private struct LiveStrokeLayer: View {
    let vm: ColoringViewModel
    let drawing: Drawing

    var body: some View {
        let stroke = vm.liveStroke
        Canvas { context, size in
            guard let stroke, let region = drawing.region(id: stroke.regionId),
                  let color = Color(hexString: stroke.color) else { return }
            var ctx = context
            ctx.concatenate(DrawingRenderer.transform(for: drawing.viewBox, in: size))
            ctx.clip(to: region.visiblePath)
            ctx.stroke(StrokeGeometry.path(for: stroke.points),
                       with: .color(color.opacity(CrayonStyle.opacity)),
                       style: StrokeGeometry.strokeStyle(width: stroke.width))
        }
        .allowsHitTesting(false)
    }
}

private struct OutlineLayer: View {
    let drawing: Drawing

    var body: some View {
        Canvas { context, size in
            DrawingRenderer.drawOutlinesAndDetails(drawing, in: context, size: size)
        }
        .allowsHitTesting(false)
    }
}
