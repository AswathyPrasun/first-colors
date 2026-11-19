import CoreGraphics
import Foundation

/// Coloring screen state and intents. All touch points arrive in drawing coordinates.
/// Saved art is loaded in `load()`; fills autosave after every fill, strokes on every finger lift.
@MainActor @Observable
final class ColoringViewModel {
    let itemId: String
    let title: String
    let drawing: Drawing?
    /// The 8 swatches for this picture's category. Saved colors outside it still render.
    let palette: [PaletteColor]

    var selectedColor: PaletteColor = KidPalette.defaultColor
    private(set) var activeTool: ColoringTool = .fill
    private(set) var isHintOn = false
    /// Region whose suggested colors glow in the palette.
    private(set) var highlightedRegionId: String?
    /// Finished strokes (rendered from a cached bitmap that only redraws regions that changed).
    private(set) var strokes: [Stroke] = []
    private(set) var fills: [String: String] = [:]
    /// The stroke under the finger right now (drawn live on top).
    private(set) var liveStroke: Stroke?
    /// Increments on every successful fill; drives the haptic.
    private(set) var fillFeedbackCount = 0
    /// True once the drawing hit the point cap; the view shows a friendly "Great drawing!".
    private(set) var isAtPointLimit = false
    private(set) var canUndo = false
    /// Touches are ignored until saved art has loaded, so nothing is drawn under it.
    private(set) var isLoaded = false
    /// Increments each time saved art is (re)loaded; lets the stroke layer prepare off-main.
    private(set) var loadGeneration = 0

    @ObservationIgnored private var state = ColoringState()
    @ObservationIgnored private var undoStack = UndoStack()
    @ObservationIgnored private var touch: Touch?
    @ObservationIgnored private let audio: any AudioPlaying
    @ObservationIgnored private let progress: any ProgressStoring
    @ObservationIgnored private let render: any RenderServicing
    @ObservationIgnored private let profileId: String
    @ObservationIgnored private let autosave: AutosaveQueue
    /// Something changed since the last thumbnail was written.
    @ObservationIgnored private var needsThumbnail = false
    @ObservationIgnored private var isFinishing = false
    @ObservationIgnored private let onDone: @MainActor () -> Void
    @ObservationIgnored private let onBack: @MainActor () -> Void

    /// Bookkeeping for the gesture in progress.
    private enum Touch {
        case fill
        case crayon(StrokeBuilder)
        case eraser(start: CGPoint, maxMove: CGFloat, removed: [RemovedStroke], originalIndex: [UUID: Int])
        case ignored
    }

    init(itemId: String,
         profileId: String,
         content: any ContentProviding,
         audio: any AudioPlaying,
         progress: any ProgressStoring,
         render: any RenderServicing,
         language: VoiceLanguage,
         onDone: @escaping @MainActor () -> Void,
         onBack: @escaping @MainActor () -> Void) {
        self.itemId = itemId
        self.profileId = profileId
        // Unknown item ids (e.g. from an old save) still open a usable screen.
        self.title = content.item(id: itemId)?.name.text(for: language) ?? ""
        self.drawing = content.drawing(for: itemId)
        self.palette = content.item(id: itemId)?.category.details.palette ?? KidPalette.colors
        self.selectedColor = palette.first ?? KidPalette.defaultColor
        self.audio = audio
        self.progress = progress
        self.render = render
        self.autosave = AutosaveQueue(store: progress, itemId: itemId, profileId: profileId)
        self.onDone = onDone
        self.onBack = onBack
        if let drawing { highlightedRegionId = FillEngine.largestRegionId(in: drawing) }
    }

    // MARK: - Derived state

    /// Hex values of the palette colors that should glow.
    var suggestedHexes: Set<String> {
        guard let id = highlightedRegionId, let region = drawing?.region(id: id) else { return [] }
        return Set(region.suggested)
    }

    var isTouchActive: Bool { touch != nil }

    // MARK: - Loading

    /// Loads the child's saved fills and strokes. Unknown regions (from an older drawing
    /// version) are ignored, and a corrupt save simply opens a blank page.
    func load() async {
        guard !isLoaded else { return }
        guard let drawing else {
            isLoaded = true
            return
        }
        let saved = await progress.loadColoring(itemId: itemId, profileId: profileId)
        let regionIds = Set(drawing.regions.map(\.id))
        state = ColoringState(
            fills: saved.fills.filter { regionIds.contains($0.key) },
            strokes: saved.strokes.filter { regionIds.contains($0.regionId) })
        undoStack.removeAll()
        isAtPointLimit = state.totalPoints >= CrayonStyle.maxPointsPerDrawing
        fills = state.fills
        strokes = state.strokes
        canUndo = false
        loadGeneration += 1
        isLoaded = true
    }

    // MARK: - Palette and tools

    func select(_ color: PaletteColor) {
        selectedColor = color
        audio.play(.effect(.tap))
        // Picking a color while erasing means "I want to color again".
        if activeTool == .eraser { activeTool = .fill }
    }

    func select(_ tool: ColoringTool) {
        activeTool = tool
        audio.play(.effect(.tap))
    }

    func toggleHint() {
        isHintOn.toggle()
        audio.play(.effect(.tap))
    }

    func magic() {
        guard let drawing, isLoaded else { return }
        let newFills = FillEngine.magicFills(for: drawing, current: state.fills)
        audio.play(.effect(.sparkle))
        fillFeedbackCount += 1
        guard newFills != state.fills else { return }
        perform(.magic(previousFills: state.fills, newFills: newFills))
        isHintOn = false
    }

    func undo() {
        guard let action = undoStack.pop() else { return }
        state.revert(action)
        let touchesStrokes: Bool
        switch action {
        case .stroke, .erase: touchesStrokes = true
        case .fill, .magic: touchesStrokes = false
        }
        publish(strokesChanged: touchesStrokes)
        audio.play(.effect(.tap))
    }

    // MARK: - Touches (drawing coordinates)

    /// - Parameter pointsPerUnit: screen points per drawing unit, for the 2pt point spacing.
    func touchBegan(at point: CGPoint, pointsPerUnit: CGFloat) {
        guard let drawing, isLoaded, touch == nil else { return }
        switch activeTool {
        case .fill:
            touch = .fill
            fill(at: point, in: drawing)
        case .crayon:
            guard !isAtPointLimit,
                  let regionId = FillEngine.regionId(at: point, in: drawing) else {
                touch = .ignored
                return
            }
            highlight(regionId)
            let spacing = CrayonStyle.minPointSpacing / max(pointsPerUnit, 0.01)
            let builder = StrokeBuilder(regionId: regionId, color: selectedColor.hex, start: point, minDistance: spacing)
            touch = .crayon(builder)
            liveStroke = builder.stroke
            audio.startLoop(.crayon)
        case .eraser:
            let index = Dictionary(uniqueKeysWithValues: state.strokes.enumerated().map { ($1.id, $0) })
            touch = .eraser(start: point, maxMove: 0, removed: [], originalIndex: index)
            erase(at: point)
        }
    }

    func touchMoved(to point: CGPoint) {
        switch touch {
        case .crayon(var builder):
            guard builder.add(point) else { return }
            if state.totalPoints + builder.stroke.points.count >= CrayonStyle.maxPointsPerDrawing {
                touch = .crayon(builder)
                isAtPointLimit = true
                touchEnded()
                audio.play(.effect(.cheer))
                return
            }
            touch = .crayon(builder)
            liveStroke = builder.stroke
        case .eraser:
            erase(at: point)
        case .fill, .ignored, nil:
            break
        }
    }

    func touchEnded() {
        defer { touch = nil }
        switch touch {
        case .crayon(let builder):
            liveStroke = nil
            audio.stopLoop()
            perform(.stroke(builder.stroke), strokesChanged: true)
        case let .eraser(start, maxMove, removedDuringDrag, originalIndex):
            var removed = removedDuringDrag
            var clearedFills: [String: String] = [:]
            // A tap with the eraser clears the whole region: its fill and all its crayon.
            if maxMove < CrayonStyle.tapTolerance, let drawing,
               let regionId = FillEngine.regionId(at: start, in: drawing) {
                highlight(regionId)
                if let color = state.fills[regionId] { clearedFills[regionId] = color }
                let regionStrokes = state.strokes.filter { $0.regionId == regionId }
                removed += regionStrokes.map { RemovedStroke(index: originalIndex[$0.id] ?? 0, stroke: $0) }
                state.apply(.erase(removed: [], clearedFills: clearedFills))
                let ids = Set(regionStrokes.map(\.id))
                state.strokes.removeAll { ids.contains($0.id) }
            }
            guard !removed.isEmpty || !clearedFills.isEmpty else { return }
            // Everything is already off the page; record a single undoable action.
            undoStack.push(.erase(removed: removed, clearedFills: clearedFills))
            publish(strokesChanged: true)
            audio.play(.effect(.pop))
        case .fill, .ignored, nil:
            break
        }
    }

    // MARK: - Navigation and audio

    func speak() { audio.play(.itemName(itemId: itemId)) }

    /// Saves everything, writes the thumbnail, marks the drawing finished, then celebrates.
    func done() {
        guard !isFinishing else { return }
        isFinishing = true
        Task {
            await finishSaving(markCompleted: true)
            onDone()
            isFinishing = false
        }
    }

    /// Finishes saving (usually a few milliseconds) and then leaves, so the picker shows
    /// the up-to-date thumbnail.
    func back() {
        guard !isFinishing else { return }
        isFinishing = true
        Task {
            await finishSaving(markCompleted: false)
            onBack()
            isFinishing = false
        }
    }

    /// Flushes autosave and refreshes the thumbnail (used by Done, Back and when the app
    /// goes to the background).
    func finishSaving(markCompleted: Bool) async {
        if touch != nil { touchEnded() }
        await autosave.flush()
        if needsThumbnail || markCompleted, drawing != nil, isLoaded {
            needsThumbnail = false
            if let png = await render.thumbnailPNG(itemId: itemId, fills: state.fills, strokes: state.strokes) {
                await progress.saveThumbnail(png, itemId: itemId, profileId: profileId)
            }
        }
        if markCompleted {
            await progress.markCompleted(itemId: itemId, profileId: profileId)
        }
    }

    // MARK: - Private

    private func fill(at point: CGPoint, in drawing: Drawing) {
        guard let regionId = FillEngine.regionId(at: point, in: drawing) else { return }
        fillRegion(regionId)
    }

    /// Fills a region by id with the selected color (taps and VoiceOver actions).
    func fillRegion(_ regionId: String) {
        guard isLoaded, drawing?.region(id: regionId) != nil else { return }
        highlight(regionId)
        let newColor = selectedColor.hex
        let oldColor = state.fills[regionId]
        audio.play(.effect(.pop))
        fillFeedbackCount += 1
        // Same color again: still positive feedback, but no undo entry.
        guard oldColor != newColor else { return }
        perform(.fill(regionId: regionId, oldColor: oldColor, newColor: newColor))
    }

    /// Removes strokes touched by the eraser during a drag (undo is recorded on lift).
    private func erase(at point: CGPoint) {
        guard case .eraser(let start, var maxMove, var removed, let originalIndex) = touch else { return }
        maxMove = max(maxMove, hypot(point.x - start.x, point.y - start.y))
        let hit = state.strokes.filter {
            StrokeGeometry.stroke($0, isTouchedAt: point, radius: CrayonStyle.eraserRadius)
        }
        if !hit.isEmpty {
            let ids = Set(hit.map(\.id))
            removed += hit.map { RemovedStroke(index: originalIndex[$0.id] ?? 0, stroke: $0) }
            state.strokes.removeAll { ids.contains($0.id) }
            strokes = state.strokes
        }
        touch = .eraser(start: start, maxMove: maxMove, removed: removed, originalIndex: originalIndex)
    }

    private func perform(_ action: ColoringAction, strokesChanged: Bool = false) {
        state.apply(action)
        undoStack.push(action)
        publish(strokesChanged: strokesChanged)
    }

    private func highlight(_ regionId: String) {
        if highlightedRegionId != regionId { highlightedRegionId = regionId }
    }

    /// Copies engine state into the observed properties (only the ones that changed).
    private func publish(strokesChanged: Bool) {
        if fills != state.fills {
            fills = state.fills
            autosave.save(fills: state.fills)
            needsThumbnail = true
        }
        if strokesChanged {
            strokes = state.strokes
            autosave.save(strokes: state.strokes)
            needsThumbnail = true
        }
        if canUndo != undoStack.canUndo { canUndo = undoStack.canUndo }
    }
}
