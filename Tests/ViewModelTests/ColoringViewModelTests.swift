import CoreGraphics
import Testing
@testable import KidsColoring

@MainActor
struct ColoringViewModelTests {
    private let red = KidPalette.colors[0]      // #E53935
    private let green = KidPalette.colors[3]    // #43A047
    private let blue = KidPalette.colors[4]     // #1E88E5

    /// A loaded coloring screen for the "squares" test drawing.
    private func makeVM(audio: FakeAudio = FakeAudio(),
                        store: FakeProgressStore = FakeProgressStore(),
                        onDone: @escaping @MainActor () -> Void = {}) async -> ColoringViewModel {
        let vm = ColoringViewModel(itemId: "squares", profileId: "p1", content: TestDrawings.content(),
                                   audio: audio, progress: store, render: FakeRender(),
                                   language: .en, onDone: onDone, onBack: {})
        await vm.load()
        return vm
    }

    private func tap(_ vm: ColoringViewModel, _ x: CGFloat, _ y: CGFloat) {
        vm.touchBegan(at: CGPoint(x: x, y: y), pointsPerUnit: 1)
        vm.touchEnded()
    }

    private func drag(_ vm: ColoringViewModel, from start: CGPoint, through points: [CGPoint]) {
        vm.touchBegan(at: start, pointsPerUnit: 1)
        for point in points { vm.touchMoved(to: point) }
        vm.touchEnded()
    }

    // MARK: Basics

    @Test func opensWithLargestRegionSuggestedAndNothingToUndo() async {
        let vm = await makeVM()
        #expect(vm.drawing != nil)
        #expect(vm.title == "Squares")
        #expect(vm.activeTool == .fill)
        #expect(!vm.canUndo)
        #expect(!vm.suggestedHexes.isEmpty)
    }

    @Test func unknownItemOpensWithoutDrawingAndIgnoresTouches() async {
        let vm = ColoringViewModel(itemId: "ghost", profileId: "p1", content: FakeContent(), audio: FakeAudio(),
                                   progress: FakeProgressStore(), render: FakeRender(),
                                   language: .en, onDone: {}, onBack: {})
        await vm.load()
        #expect(vm.drawing == nil)
        tap(vm, 30, 30)
        vm.magic()
        #expect(vm.fills.isEmpty)
    }

    // MARK: Fill

    @Test func fillTapColorsRegionAndHighlightsItsSuggestions() async {
        let audio = FakeAudio()
        let vm = await makeVM(audio: audio)
        vm.select(blue)
        tap(vm, 250, 100)
        #expect(vm.fills == ["leaf": "#1E88E5"])
        #expect(vm.suggestedHexes == ["#43A047"])
        #expect(vm.fillFeedbackCount == 1)
        #expect(audio.played.last == .effect(.pop))
        #expect(vm.canUndo)
    }

    @Test func anyColorIsAllowed() async {
        let vm = await makeVM()
        vm.select(blue)   // not a suggestion for body
        tap(vm, 30, 30)
        #expect(vm.fills["body"] == "#1E88E5")
    }

    @Test func refillingSameColorGivesFeedbackButNoUndoEntry() async {
        let vm = await makeVM()
        tap(vm, 30, 30)
        vm.undo()
        tap(vm, 30, 30)
        tap(vm, 30, 30)
        #expect(vm.fillFeedbackCount == 3)
        vm.undo()
        #expect(vm.fills.isEmpty)
        #expect(!vm.canUndo)
    }

    @Test func tapOutsideEverythingDoesNothing() async {
        let vm = await makeVM()
        tap(vm, 150, 280)
        #expect(vm.fills.isEmpty)
        #expect(!vm.canUndo)
    }

    @Test func undoFillRestoresPreviousColor() async {
        let vm = await makeVM()
        tap(vm, 30, 30)
        vm.select(green)
        tap(vm, 30, 30)
        vm.undo()
        #expect(vm.fills["body"] == "#E53935")
        vm.undo()
        #expect(vm.fills["body"] == nil)
    }

    // MARK: Crayon

    @Test func crayonStrokeStaysInStartingRegion() async {
        let audio = FakeAudio()
        let vm = await makeVM(audio: audio)
        vm.select(.crayon)
        vm.touchBegan(at: CGPoint(x: 30, y: 120), pointsPerUnit: 1)
        #expect(vm.liveStroke?.regionId == "body")
        vm.touchMoved(to: CGPoint(x: 200, y: 120))    // wanders into the leaf
        #expect(vm.liveStroke?.points.count == 2)
        vm.touchEnded()
        #expect(vm.liveStroke == nil)
        #expect(vm.strokes.count == 1)
        #expect(vm.strokes[0].regionId == "body")
        #expect(vm.strokes[0].color == "#E53935")
        #expect(audio.loops == [.crayon])
        #expect(audio.stopLoopCount == 1)
    }

    @Test func crayonDropsPointsCloserThanTwoScreenPoints() async {
        let vm = await makeVM()
        vm.select(.crayon)
        // 2 screen points per drawing unit → minimum spacing is 1 drawing unit.
        vm.touchBegan(at: CGPoint(x: 30, y: 30), pointsPerUnit: 2)
        vm.touchMoved(to: CGPoint(x: 30.5, y: 30))
        vm.touchMoved(to: CGPoint(x: 31.2, y: 30))
        vm.touchEnded()
        #expect(vm.strokes[0].points.count == 2)
    }

    @Test func crayonStartingOutsideTheDrawingIsIgnored() async {
        let vm = await makeVM()
        vm.select(.crayon)
        drag(vm, from: CGPoint(x: 150, y: 280), through: [CGPoint(x: 30, y: 30)])
        #expect(vm.strokes.isEmpty)
    }

    @Test func secondTouchBeganWhileDrawingIsIgnored() async {
        let vm = await makeVM()
        vm.select(.crayon)
        vm.touchBegan(at: CGPoint(x: 30, y: 30), pointsPerUnit: 1)
        vm.touchBegan(at: CGPoint(x: 250, y: 30), pointsPerUnit: 1)   // palm
        vm.touchEnded()
        #expect(vm.strokes.count == 1)
        #expect(vm.strokes[0].regionId == "body")
    }

    @Test func undoStrokeRemovesIt() async {
        let vm = await makeVM()
        vm.select(.crayon)
        drag(vm, from: CGPoint(x: 30, y: 30), through: [CGPoint(x: 60, y: 30)])
        vm.undo()
        #expect(vm.strokes.isEmpty)
        #expect(!vm.canUndo)
    }

    @Test func pointLimitEndsTheStrokeWithACelebration() async {
        let vm = await makeVM()
        vm.select(.crayon)
        vm.touchBegan(at: CGPoint(x: 21, y: 21), pointsPerUnit: 1)
        var x: CGFloat = 21
        for index in 0..<(CrayonStyle.maxPointsPerDrawing + 10) {
            x = x >= 139 ? 21 : x + 3
            vm.touchMoved(to: CGPoint(x: x, y: 21 + CGFloat(index % 100)))
            if vm.isAtPointLimit { break }
        }
        #expect(vm.isAtPointLimit)
        #expect(vm.strokes.count == 1)
        #expect(vm.liveStroke == nil)
        // Further crayon touches are ignored, but fill still works.
        drag(vm, from: CGPoint(x: 30, y: 30), through: [CGPoint(x: 60, y: 30)])
        #expect(vm.strokes.count == 1)
        vm.select(.fill)
        tap(vm, 250, 30)
        #expect(vm.fills["leaf"] != nil)
    }

    // MARK: Eraser

    @Test func eraserDragRemovesTouchedStrokesAsOneUndoableAction() async {
        let vm = await makeVM()
        vm.select(.crayon)
        drag(vm, from: CGPoint(x: 30, y: 30), through: [CGPoint(x: 130, y: 30)])     // A
        drag(vm, from: CGPoint(x: 30, y: 130), through: [CGPoint(x: 130, y: 130)])   // B
        drag(vm, from: CGPoint(x: 200, y: 30), through: [CGPoint(x: 260, y: 30)])    // C (leaf)
        tap(vm, 250, 120)   // crayon dot in leaf (D)
        vm.select(.fill)
        tap(vm, 250, 100)
        vm.select(.eraser)
        // Drag down the left side of the body: touches A and B, not C/D, and is not a tap.
        drag(vm, from: CGPoint(x: 40, y: 30), through: [CGPoint(x: 40, y: 80), CGPoint(x: 40, y: 130)])
        #expect(vm.strokes.count == 2)
        #expect(vm.fills["leaf"] != nil)
        vm.undo()
        #expect(vm.strokes.count == 4)
        #expect(vm.strokes.map(\.regionId) == ["body", "body", "leaf", "leaf"])
    }

    @Test func eraserTapClearsTheRegionFillAndItsCrayon() async {
        let vm = await makeVM()
        tap(vm, 250, 100)                       // fill leaf
        vm.select(.crayon)
        drag(vm, from: CGPoint(x: 200, y: 30), through: [CGPoint(x: 260, y: 30)])
        drag(vm, from: CGPoint(x: 30, y: 30), through: [CGPoint(x: 60, y: 30)])
        vm.select(.eraser)
        tap(vm, 250, 120)                       // far from the leaf stroke, but a tap
        #expect(vm.fills["leaf"] == nil)
        #expect(vm.strokes.map(\.regionId) == ["body"])
        vm.undo()
        #expect(vm.fills["leaf"] == "#E53935")
        #expect(vm.strokes.map(\.regionId) == ["leaf", "body"])
    }

    @Test func eraserOnEmptySpaceRecordsNothing() async {
        let vm = await makeVM()
        vm.select(.eraser)
        tap(vm, 250, 100)
        #expect(!vm.canUndo)
    }

    @Test func pickingAColorLeavesEraserMode() async {
        let vm = await makeVM()
        vm.select(.eraser)
        vm.select(green)
        #expect(vm.activeTool == .fill)
        vm.select(.crayon)
        vm.select(blue)
        #expect(vm.activeTool == .crayon)
    }

    // MARK: Hint and Magic

    @Test func hintToggles() async {
        let vm = await makeVM()
        vm.toggleHint()
        #expect(vm.isHintOn)
        vm.toggleHint()
        #expect(!vm.isHintOn)
    }

    @Test func magicFillsEverythingAndUndoesInOneStep() async {
        let audio = FakeAudio()
        let vm = await makeVM(audio: audio)
        vm.select(blue)
        tap(vm, 80, 80)          // dot (no suggestions) keeps blue
        vm.toggleHint()
        vm.magic()
        #expect(vm.fills == ["body": "#E53935", "leaf": "#43A047", "stem": "#6D4C41", "dot": "#1E88E5"])
        #expect(!vm.isHintOn)
        #expect(audio.played.last == .effect(.sparkle))
        vm.undo()
        #expect(vm.fills == ["dot": "#1E88E5"])
    }

    @Test func magicTwiceAddsOnlyOneUndo() async {
        let vm = await makeVM()
        vm.magic()
        vm.magic()
        vm.undo()
        #expect(vm.fills.isEmpty)
        #expect(!vm.canUndo)
    }

    // MARK: Mixed undo

    @Test func mixedFillCrayonEraserUndoUnwindsInOrder() async {
        let vm = await makeVM()
        tap(vm, 30, 30)                                                              // 1 fill body
        vm.select(.crayon)
        drag(vm, from: CGPoint(x: 30, y: 120), through: [CGPoint(x: 120, y: 120)])  // 2 stroke
        vm.select(.eraser)
        drag(vm, from: CGPoint(x: 60, y: 120), through: [CGPoint(x: 90, y: 120)])   // 3 erase stroke
        vm.magic()                                                                   // 4 magic
        #expect(vm.strokes.isEmpty)
        vm.undo()   // 4
        #expect(vm.fills == ["body": "#E53935"])
        vm.undo()   // 3
        #expect(vm.strokes.count == 1)
        vm.undo()   // 2
        #expect(vm.strokes.isEmpty)
        vm.undo()   // 1
        #expect(vm.fills.isEmpty)
        #expect(!vm.canUndo)
    }

    @Test func doneCallsCoordinator() async {
        var done = 0
        let vm = await makeVM(onDone: { done += 1 })
        vm.done()
        vm.done()   // double tap is ignored
        await waitUntil { done > 0 }
        #expect(done == 1)
    }
}
