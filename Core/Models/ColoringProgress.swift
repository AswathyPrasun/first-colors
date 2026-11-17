import Foundation

/// Saved progress for one drawing (`<itemId>.json`), kept tiny: fills only.
/// Crayon strokes live in a separate `<itemId>.strokes` file (CLAUDE.md §8).
struct ColoringProgress: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var itemId: String
    var updatedAt: Date
    /// regionId → `#RRGGBB`
    var fills: [String: String]
    var strokesFile: String?
    /// Set when the child taps Done; such items show in My Art and get a check in the picker.
    var completedAt: Date?

    init(itemId: String, updatedAt: Date = Date(), fills: [String: String] = [:],
         strokesFile: String? = nil, completedAt: Date? = nil) {
        self.version = Self.currentVersion
        self.itemId = itemId
        self.updatedAt = updatedAt
        self.fills = fills
        self.strokesFile = strokesFile
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case version, itemId, updatedAt, fills, strokesFile, completedAt
    }

    /// Tolerant: unknown keys are ignored, bad fill values are dropped, optional fields default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        itemId = try c.decode(String.self, forKey: .itemId)
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? .distantPast
        let rawFills = (try? c.decode([String: String].self, forKey: .fills)) ?? [:]
        fills = rawFills.compactMapValues(HexColor.normalized)
        strokesFile = try? c.decodeIfPresent(String.self, forKey: .strokesFile)
        completedAt = try? c.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

/// Everything needed to reopen a drawing.
struct SavedColoring: Equatable, Sendable {
    var fills: [String: String] = [:]
    var strokes: [Stroke] = []
    var completedAt: Date?

    static let empty = SavedColoring()
}

/// Lightweight listing entry for the picker and My Art.
struct ProgressSummary: Equatable, Sendable {
    let itemId: String
    let updatedAt: Date
    let completedAt: Date?
    let hasThumbnail: Bool

    var isCompleted: Bool { completedAt != nil }
}
