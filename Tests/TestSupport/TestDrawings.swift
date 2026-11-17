import Foundation
@testable import KidsColoring

/// Small hand-made drawings with known geometry for engine tests (300×300 viewBox).
///
/// "squares": left square (body, 20…140) and right square (leaf, 160…280) side by side,
/// plus a thin stem (145…155 × 20…140) between them, and a small "dot" on top of the left square.
enum TestDrawings {
    static let squaresSVG = """
    <svg viewBox="0 0 300 300">
      <path id="body" d="M20 20 L140 20 L140 140 L20 140 Z"/>
      <path id="leaf" d="M160 20 L280 20 L280 140 L160 140 Z"/>
      <path id="stem" d="M145 20 L155 20 L155 140 L145 140 Z"/>
      <path id="dot" d="M60 60 L100 60 L100 100 L60 100 Z"/>
      <g id="details"><circle cx="200" cy="200" r="5"/></g>
    </svg>
    """

    static let squaresItem = ContentItem(
        id: "squares", category: .fruits, name: LocalizedText(en: "Squares"),
        regions: [
            RegionSpec(id: "body", suggested: ["#E53935", "#43A047"]),
            RegionSpec(id: "leaf", suggested: ["#43A047"]),
            RegionSpec(id: "stem", suggested: ["#6D4C41"]),
            RegionSpec(id: "dot", suggested: []),
        ])

    static func squares() -> Drawing {
        // Test geometry is a constant; a parse failure here is a test bug.
        let document = try! SVGDocumentParser.parse(Data(squaresSVG.utf8))
        return DrawingBuilder.build(item: squaresItem, document: document)
    }

    static func content() -> FakeContent {
        FakeContent([squaresItem], drawings: ["squares": squares()])
    }
}
