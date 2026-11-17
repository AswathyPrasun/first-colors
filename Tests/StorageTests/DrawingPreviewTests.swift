import Foundation
import SwiftUI
import Testing
@testable import KidsColoring

/// Opt-in art review: renders every drawing (blank + suggested colors) to a contact sheet.
/// Run with `TEST_RUNNER_DRAWING_PREVIEW_DIR=/some/folder xcodebuild test …`.
@MainActor
struct DrawingPreviewTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DRAWING_PREVIEW_DIR"] != nil))
    func renderContactSheets() throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DRAWING_PREVIEW_DIR"]!)
        let repo = ContentRepository(bundle: .main)
        var report = "item.region\tlongSide\tdiskRadius\n"

        for category in KidsColoring.Category.allCases {
            let drawings = repo.items(in: category).compactMap { repo.drawing(for: $0.id) }
            let sheet = VStack(spacing: 8) {
                ForEach(Array(stride(from: 0, to: drawings.count, by: 5)), id: \.self) { start in
                    HStack(spacing: 8) {
                        ForEach(drawings[start..<min(start + 5, drawings.count)], id: \.itemId) { drawing in
                            VStack(spacing: 4) {
                                DrawingPicture(drawing: drawing).frame(width: 220, height: 220)
                                DrawingPicture(drawing: drawing, fills: Self.suggestedFills(drawing))
                                    .frame(width: 220, height: 220)
                            }
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(white: 0.85))

            let renderer = ImageRenderer(content: sheet)
            renderer.scale = 1
            let data = try #require(renderer.uiImage?.pngData())
            try data.write(to: directory.appendingPathComponent("\(category.rawValue).png"))

            for drawing in drawings {
                for region in drawing.regions {
                    let m = RegionMetrics(region)
                    report += "\(drawing.itemId).\(region.id)\t\(Int(m.longSide))\t\(Int(m.largestDiskRadius))\n"
                }
            }
        }
        try report.write(to: directory.appendingPathComponent("metrics.tsv"), atomically: true, encoding: .utf8)
    }

    private static func suggestedFills(_ drawing: Drawing) -> [String: Color] {
        var fills: [String: Color] = [:]
        for region in drawing.regions {
            if let hex = region.suggested.first, let color = Color(hexString: hex) { fills[region.id] = color }
        }
        return fills
    }
}
