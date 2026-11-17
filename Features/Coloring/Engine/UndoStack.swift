import Foundation

/// A stroke removed by the eraser, with its position so undo restores the same layering.
struct RemovedStroke: Hashable, Sendable {
    let index: Int
    let stroke: Stroke
}

/// Every undoable change on the coloring screen. One stack covers fill and crayon (CLAUDE.md §6).
enum ColoringAction: Hashable, Sendable {
    /// `newColor == nil` clears the region.
    case fill(regionId: String, oldColor: String?, newColor: String?)
    /// Undo removes the stroke.
    case stroke(Stroke)
    /// Undo restores the strokes (at their old positions) and any fills the eraser cleared.
    case erase(removed: [RemovedStroke], clearedFills: [String: String])
    /// Undo restores the previous fills exactly.
    case magic(previousFills: [String: String], newFills: [String: String])
}

/// What is on the page: region fills and crayon strokes (bottom → top).
struct ColoringState: Equatable, Sendable {
    var fills: [String: String] = [:]
    var strokes: [Stroke] = []

    var totalPoints: Int { strokes.reduce(0) { $0 + $1.points.count } }

    mutating func apply(_ action: ColoringAction) {
        switch action {
        case let .fill(regionId, _, newColor):
            fills[regionId] = newColor
        case let .stroke(stroke):
            strokes.append(stroke)
        case let .erase(removed, clearedFills):
            let ids = Set(removed.map(\.stroke.id))
            strokes.removeAll { ids.contains($0.id) }
            for regionId in clearedFills.keys { fills[regionId] = nil }
        case let .magic(_, newFills):
            fills = newFills
        }
    }

    mutating func revert(_ action: ColoringAction) {
        switch action {
        case let .fill(regionId, oldColor, _):
            fills[regionId] = oldColor
        case let .stroke(stroke):
            strokes.removeAll { $0.id == stroke.id }
        case let .erase(removed, clearedFills):
            for item in removed.sorted(by: { $0.index < $1.index }) {
                strokes.insert(item.stroke, at: min(item.index, strokes.count))
            }
            for (regionId, color) in clearedFills { fills[regionId] = color }
        case let .magic(previousFills, _):
            fills = previousFills
        }
    }
}

/// Bounded LIFO of actions. The oldest action is dropped past the limit to cap memory.
struct UndoStack: Sendable {
    static let defaultLimit = 50

    let limit: Int
    private(set) var actions: [ColoringAction] = []

    init(limit: Int = UndoStack.defaultLimit) {
        self.limit = max(1, limit)
    }

    var canUndo: Bool { !actions.isEmpty }

    mutating func push(_ action: ColoringAction) {
        actions.append(action)
        if actions.count > limit { actions.removeFirst(actions.count - limit) }
    }

    mutating func pop() -> ColoringAction? {
        actions.popLast()
    }

    mutating func removeAll() { actions.removeAll() }
}
