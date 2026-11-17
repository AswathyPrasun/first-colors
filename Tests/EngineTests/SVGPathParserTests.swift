import CoreGraphics
import SwiftUI
import Testing
@testable import KidsColoring

/// Flattened path elements for exact assertions.
private enum E: Equatable {
    case move(CGPoint), line(CGPoint), quad(CGPoint, CGPoint), curve(CGPoint, CGPoint, CGPoint), close
}

private func elements(_ path: Path) -> [E] {
    var out: [E] = []
    path.forEach { element in
        switch element {
        case .move(let p): out.append(.move(p))
        case .line(let p): out.append(.line(p))
        case .quadCurve(let p, let c): out.append(.quad(c, p))
        case .curve(let p, let c1, let c2): out.append(.curve(c1, c2, p))
        case .closeSubpath: out.append(.close)
        }
    }
    return out
}

private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

private func approx(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 0.5) -> Bool {
    abs(a.minX - b.minX) < tolerance && abs(a.minY - b.minY) < tolerance
        && abs(a.width - b.width) < tolerance && abs(a.height - b.height) < tolerance
}

struct SVGPathParserTests {
    @Test func absoluteLinesAndClose() throws {
        let path = try SVGPathParser.parse("M0 0 L10 0 L10 10 Z")
        #expect(elements(path) == [.move(p(0, 0)), .line(p(10, 0)), .line(p(10, 10)), .close])
    }

    @Test func relativeCommandsAndHV() throws {
        let path = try SVGPathParser.parse("m10 10 h20 v20 H10 V10 l5 5 z")
        #expect(elements(path) == [
            .move(p(10, 10)), .line(p(30, 10)), .line(p(30, 30)), .line(p(10, 30)),
            .line(p(10, 10)), .line(p(15, 15)), .close,
        ])
    }

    @Test func implicitLinetoAfterMoveto() throws {
        #expect(elements(try SVGPathParser.parse("M0 0 10 0 10 10")) ==
                [.move(p(0, 0)), .line(p(10, 0)), .line(p(10, 10))])
        #expect(elements(try SVGPathParser.parse("m5 5 10 0 0 10")) ==
                [.move(p(5, 5)), .line(p(15, 5)), .line(p(15, 15))])
    }

    @Test func compactNumberSyntax() throws {
        #expect(elements(try SVGPathParser.parse("M10-20L.5.5")) == [.move(p(10, -20)), .line(p(0.5, 0.5))])
        // Values chosen to be exact in Float, which SwiftUI's Path stores internally.
        #expect(elements(try SVGPathParser.parse("M1e1,2E+1 L-1.25e-1 3")) ==
                [.move(p(10, 20)), .line(p(-0.125, 3))])
        #expect(elements(try SVGPathParser.parse("M 1 , 2\n\tL3,4")) == [.move(p(1, 2)), .line(p(3, 4))])
    }

    @Test func cubicAndSmoothCubicReflection() throws {
        let path = try SVGPathParser.parse("M0 0 C0 10 20 10 20 0 S40 -10 40 0")
        #expect(elements(path) == [
            .move(p(0, 0)),
            .curve(p(0, 10), p(20, 10), p(20, 0)),
            .curve(p(20, -10), p(40, -10), p(40, 0)),
        ])
    }

    @Test func smoothCubicWithoutPreviousCurveUsesCurrentPoint() throws {
        let path = try SVGPathParser.parse("M0 0 S10 10 20 0")
        #expect(elements(path) == [.move(p(0, 0)), .curve(p(0, 0), p(10, 10), p(20, 0))])
    }

    @Test func quadraticAndSmoothQuadratic() throws {
        let path = try SVGPathParser.parse("M0 0 Q10 10 20 0 T40 0 t20 0")
        #expect(elements(path) == [
            .move(p(0, 0)), .quad(p(10, 10), p(20, 0)), .quad(p(30, -10), p(40, 0)), .quad(p(50, 10), p(60, 0)),
        ])
    }

    @Test func relativeCubic() throws {
        let path = try SVGPathParser.parse("M10 10 c0 10 20 10 20 0")
        #expect(elements(path) == [.move(p(10, 10)), .curve(p(10, 20), p(30, 20), p(30, 10))])
    }

    @Test func semicircleArc() throws {
        // Sweep 1 from (0,0) to (20,0) around (10,0) goes through (10,-10) in SVG's y-down space.
        let path = try SVGPathParser.parse("M0 0 A10 10 0 0 1 20 0")
        #expect(approx(path.boundingRect, CGRect(x: 0, y: -10, width: 20, height: 10)))
        let last = elements(path).last
        if case .curve(_, _, let end) = last { #expect(end == p(20, 0)) } else { Issue.record("expected curve") }
    }

    @Test func fullCircleFromTwoArcsContainsCenter() throws {
        let path = try SVGPathParser.parse("M40 100 A60 60 0 1 0 160 100 A60 60 0 1 0 40 100 Z")
        #expect(approx(path.boundingRect, CGRect(x: 40, y: 40, width: 120, height: 120), tolerance: 0.2))
        #expect(path.contains(p(100, 100)))
        #expect(!path.contains(p(45, 45)))
    }

    @Test func arcLargeArcAndSweepFlagsPickTheRightArc() throws {
        // Same endpoints and radius; the four flag combinations give four different arcs.
        let small = try SVGPathParser.parse("M0 0 A20 20 0 0 1 20 20").boundingRect
        let large = try SVGPathParser.parse("M0 0 A20 20 0 1 1 20 20").boundingRect
        #expect(small.width < 21 && small.height < 21)
        #expect(large.width > 35 && large.height > 35)
    }

    @Test func compactArcFlags() throws {
        let compact = try SVGPathParser.parse("M0 0a10 10 0 0120 0").boundingRect
        let spaced = try SVGPathParser.parse("M0 0 a10 10 0 0 1 20 0").boundingRect
        #expect(approx(compact, spaced, tolerance: 0.001))
    }

    @Test func outOfRangeRadiiAreScaledUp() throws {
        // Radius 1 can't span 20 units; spec says scale it to the minimum (10), giving a semicircle.
        let path = try SVGPathParser.parse("M0 0 A1 1 0 0 1 20 0")
        #expect(approx(path.boundingRect, CGRect(x: 0, y: -10, width: 20, height: 10)))
    }

    @Test func rotatedEllipticalArc() throws {
        let path = try SVGPathParser.parse("M0 0 A20 10 90 0 1 0 40")
        // Rotated 90°, the x-radius becomes vertical: half-ellipse 10 wide, 40 tall.
        #expect(approx(path.boundingRect, CGRect(x: 0, y: 0, width: 10, height: 40)))
    }

    @Test func zeroRadiusArcIsALine() throws {
        #expect(elements(try SVGPathParser.parse("M0 0 A0 10 0 0 1 20 0")) == [.move(p(0, 0)), .line(p(20, 0))])
    }

    @Test func arcToSamePointIsSkipped() throws {
        #expect(elements(try SVGPathParser.parse("M5 5 A10 10 0 0 1 5 5")) == [.move(p(5, 5))])
    }

    @Test func drawingAfterCloseStartsFromSubpathStart() throws {
        let path = try SVGPathParser.parse("M10 10 L20 10 Z l5 5")
        #expect(elements(path) == [.move(p(10, 10)), .line(p(20, 10)), .close, .move(p(10, 10)), .line(p(15, 15))])
    }

    @Test func multipleSubpaths() throws {
        let path = try SVGPathParser.parse("M0 0 L1 0 Z M5 5 L6 5 Z")
        #expect(elements(path).filter { $0 == .close }.count == 2)
    }

    @Test func emptyStringGivesEmptyPath() throws {
        #expect(try SVGPathParser.parse("").isEmpty)
        #expect(try SVGPathParser.parse("   ").isEmpty)
    }

    @Test func errorsInsteadOfCrashing() {
        #expect(throws: SVGPathError.missingMoveTo) { try SVGPathParser.parse("L10 10") }
        #expect(throws: SVGPathError.missingMoveTo) { try SVGPathParser.parse("10 10") }
        #expect(throws: SVGPathError.missingNumber(command: "M", offset: 3)) { try SVGPathParser.parse("M10") }
        #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0 0 X 5") }
        #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0 0 Z 5 5") }
        #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0 0 A10 10 0 2 1 5 5") }
        #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0 0 L-.e") }
    }
}

struct SVGDocumentParserTests {
    private let svg = """
    <?xml version="1.0"?>
    <svg viewBox="0 0 300 300" fill="#fff">
      <path id="body" d="M0 0 L100 0 L100 100 Z"/>
      <circle id="dot" cx="50" cy="50" r="10"/>
      <path id="broken" d="L5 5"/>
      <g id="details"><circle cx="10" cy="10" r="2"/><g><path d="M0 0 L5 5"/></g></g>
      <ellipse cx="5" cy="5" rx="2" ry="3"/>
    </svg>
    """

    @Test func parsesShapesGroupsAndViewBox() throws {
        let doc = try SVGDocumentParser.parse(Data(svg.utf8))
        #expect(doc.viewBox == CGRect(x: 0, y: 0, width: 300, height: 300))
        // The broken path is skipped, everything else survives in document order.
        #expect(doc.shapes.map(\.id) == ["body", "dot", nil, nil, nil])
        #expect(doc.shapes.map(\.isDetail) == [false, false, true, true, false])
        #expect(doc.shapes.map(\.kind) == [.path, .circle, .circle, .path, .ellipse])
    }

    @Test func rejectsGarbage() {
        #expect(throws: SVGDocumentError.self) { try SVGDocumentParser.parse(Data("<svg><path".utf8)) }
        #expect(throws: SVGDocumentError.notSVG) { try SVGDocumentParser.parse(Data("<html/>".utf8)) }
        #expect(throws: SVGDocumentError.self) { try SVGDocumentParser.parse(Data()) }
    }

    @Test func viewBoxParsing() {
        #expect(SVGDocumentParser.parseViewBox("0,0,10,20") == CGRect(x: 0, y: 0, width: 10, height: 20))
        #expect(SVGDocumentParser.parseViewBox("0 0 0 20") == nil)
        #expect(SVGDocumentParser.parseViewBox("nope") == nil)
    }

    @Test func fallsBackToWidthHeight() throws {
        let doc = try SVGDocumentParser.parse(Data(#"<svg width="200px" height="100"><path id="a" d="M0 0 L1 1 Z"/></svg>"#.utf8))
        #expect(doc.viewBox == CGRect(x: 0, y: 0, width: 200, height: 100))
    }
}

struct DrawingBuilderTests {
    /// Big square with a small square on top of its corner.
    private let svg = """
    <svg viewBox="0 0 300 300">
      <path id="base" d="M50 50 L250 50 L250 250 L50 250 Z"/>
      <path id="extra" d="M0 0 L10 0 L10 10 Z"/>
      <path id="top" d="M200 200 L280 200 L280 280 L200 280 Z"/>
      <g id="details"><circle cx="100" cy="100" r="5"/><path d="M90 120 L110 120"/></g>
    </svg>
    """

    private func build(regions: [RegionSpec]) throws -> Drawing {
        let item = ContentItem(id: "test", category: .fruits, name: LocalizedText(en: "Test"), regions: regions)
        return DrawingBuilder.build(item: item, document: try SVGDocumentParser.parse(Data(svg.utf8)))
    }

    @Test func regionsFollowSVGZOrderAndJSONMembership() throws {
        let drawing = try build(regions: [
            RegionSpec(id: "top", suggested: ["#e53935", "bad"]),
            RegionSpec(id: "base", suggested: []),
            RegionSpec(id: "ghost", suggested: []),
        ])
        #expect(drawing.regions.map(\.id) == ["base", "top"])           // SVG order; ghost skipped
        #expect(drawing.region(id: "top")?.suggested == ["#E53935"])   // normalized, invalid dropped
        // Un-listed id'd shape becomes a stroked detail; plus 2 real details.
        #expect(drawing.details.count == 3)
        #expect(drawing.details.filter { $0.style == .fill }.count == 1)
    }

    @Test func lowerRegionLosesTheAreaCoveredByUpperRegion() throws {
        let drawing = try build(regions: [RegionSpec(id: "base", suggested: []), RegionSpec(id: "top", suggested: [])])
        let base = try #require(drawing.region(id: "base"))
        let top = try #require(drawing.region(id: "top"))
        let overlap = CGPoint(x: 225, y: 225)
        #expect(base.path.contains(overlap))
        #expect(!base.visiblePath.contains(overlap))
        #expect(top.visiblePath.contains(overlap))
        #expect(base.visiblePath.contains(CGPoint(x: 100, y: 100)))
        // The hidden part of the lower outline is removed too.
        #expect(!base.outline.contains(CGPoint(x: 250, y: 240)))
        #expect(base.outline.contains(CGPoint(x: 250, y: 120)))
    }
}

