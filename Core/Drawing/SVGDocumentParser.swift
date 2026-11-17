import CoreGraphics
import Foundation
import SwiftUI

/// The subset of an SVG file the app understands.
///
/// Authoring convention (see README "Adding drawings"):
/// - `<svg viewBox="0 0 300 300">`
/// - Fillable regions: `<path id="body" d="…"/>` (also `circle` / `ellipse`), in z-order (later = on top).
///   Each `id` must match a region id in `content.json`.
/// - Non-fillable face and decoration: inside `<g id="details">`. Circles/ellipses are filled with
///   the outline color (eyes, seeds); paths are stroked (smiles, lines).
/// - Presentation attributes (`fill`, `stroke`, …) are ignored by the app; they only make the
///   file look right in an SVG editor.
struct SVGDocument: Sendable {
    struct Shape: Sendable {
        enum Kind: Sendable { case path, circle, ellipse }
        let id: String?
        let kind: Kind
        let isDetail: Bool
        let path: Path
    }

    let viewBox: CGRect
    let shapes: [Shape]
}

enum SVGDocumentError: Error, Equatable {
    case malformedXML(String)
    case notSVG
}

enum SVGDocumentParser {
    static let detailsGroupId = "details"
    static let defaultViewBox = CGRect(x: 0, y: 0, width: 300, height: 300)

    static func parse(_ data: Data) throws -> SVGDocument {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else {
            throw SVGDocumentError.malformedXML(parser.parserError?.localizedDescription ?? "unknown")
        }
        guard delegate.sawSVG else { throw SVGDocumentError.notSVG }
        return SVGDocument(viewBox: delegate.viewBox ?? defaultViewBox, shapes: delegate.shapes)
    }

    static func parseViewBox(_ text: String) -> CGRect? {
        let parts = text.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" || $0 == "\n" })
            .compactMap { Double($0) }
        guard parts.count == 4, parts[2] > 0, parts[3] > 0 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var sawSVG = false
        var viewBox: CGRect?
        var shapes: [SVGDocument.Shape] = []
        /// One entry per open `<g>`: whether it is (or is inside) the details group.
        private var groupStack: [Bool] = []

        private var inDetails: Bool { groupStack.last ?? false }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes: [String: String] = [:]) {
            switch elementName {
            case "svg":
                sawSVG = true
                if let box = attributes["viewBox"].flatMap(SVGDocumentParser.parseViewBox) {
                    viewBox = box
                } else if let w = attributes["width"].flatMap(Self.length),
                          let h = attributes["height"].flatMap(Self.length), w > 0, h > 0 {
                    viewBox = CGRect(x: 0, y: 0, width: w, height: h)
                }
            case "g":
                groupStack.append(inDetails || attributes["id"] == SVGDocumentParser.detailsGroupId)
            case "path":
                guard let d = attributes["d"] else { return }
                do {
                    let path = try SVGPathParser.parse(d)
                    add(.path, path: path, id: attributes["id"])
                } catch {
                    Log.content.error("Skipping bad path \(attributes["id"] ?? "?", privacy: .public): \(String(describing: error), privacy: .public)")
                }
            case "circle":
                let cx = attributes["cx"].flatMap(Self.length) ?? 0
                let cy = attributes["cy"].flatMap(Self.length) ?? 0
                guard let r = attributes["r"].flatMap(Self.length), r > 0 else { return }
                let rect = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
                add(.circle, path: Path(ellipseIn: rect), id: attributes["id"])
            case "ellipse":
                let cx = attributes["cx"].flatMap(Self.length) ?? 0
                let cy = attributes["cy"].flatMap(Self.length) ?? 0
                guard let rx = attributes["rx"].flatMap(Self.length),
                      let ry = attributes["ry"].flatMap(Self.length), rx > 0, ry > 0 else { return }
                let rect = CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry)
                add(.ellipse, path: Path(ellipseIn: rect), id: attributes["id"])
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?) {
            if elementName == "g", !groupStack.isEmpty { groupStack.removeLast() }
        }

        private func add(_ kind: SVGDocument.Shape.Kind, path: Path, id: String?) {
            guard !path.isEmpty else { return }
            shapes.append(SVGDocument.Shape(id: id, kind: kind, isDetail: inDetails, path: path))
        }

        /// Parses a plain number, ignoring a trailing `px`.
        private static func length(_ text: String) -> CGFloat? {
            let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "px", with: "")
            guard let value = Double(trimmed), value.isFinite else { return nil }
            return CGFloat(value)
        }
    }
}
