import Foundation

/// Modal tools (one is always active). Undo, Hint and Magic are one-shot actions, not tools.
enum ColoringTool: Equatable, Sendable {
    case fill
    case crayon
    case eraser
}
