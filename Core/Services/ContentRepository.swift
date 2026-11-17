import Foundation
import os

/// Read-only access to the bundled drawings.
protocol ContentProviding: Sendable {
    func items(in category: Category) -> [ContentItem]
    func item(id: String) -> ContentItem?
    func categoryInfo(_ category: Category) -> CategoryInfo?
    /// Parsed geometry for an item, or `nil` if its SVG is missing or unusable.
    func drawing(for itemId: String) -> Drawing?
}

/// Loads `content.json` from the app bundle once and SVG drawings lazily (cached).
/// Never throws: missing or corrupt files are logged and skipped, so the app always launches.
final class ContentRepository: ContentProviding {
    private let allItems: [ContentItem]
    private let byId: [String: ContentItem]
    private let categories: [Category: CategoryInfo]
    private let svgLoader: @Sendable (String) -> Data?
    private let drawingCache = OSAllocatedUnfairLock<[String: Drawing]>(initialState: [:])

    init(items: [ContentItem],
         categories: [CategoryInfo] = [],
         svgLoader: @escaping @Sendable (String) -> Data? = { _ in nil }) {
        var seen = Set<String>()
        // Keep the first occurrence of each id so duplicates can't confuse saves.
        let unique = items.filter { seen.insert($0.id).inserted }
        allItems = unique
        byId = Dictionary(uniqueKeysWithValues: unique.map { ($0.id, $0) })
        self.categories = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.svgLoader = svgLoader
    }

    convenience init(bundle: Bundle, resource: String = "content") {
        let loader: @Sendable (String) -> Data? = { fileName in
            let name = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            guard let url = bundle.url(forResource: name, withExtension: ext.isEmpty ? "svg" : ext) else {
                return nil
            }
            return try? Data(contentsOf: url)
        }
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            Log.content.error("Missing \(resource, privacy: .public).json in bundle")
            self.init(items: [], svgLoader: loader)
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let catalog = Self.decodeCatalog(from: data)
            self.init(items: catalog?.items ?? [], categories: catalog?.categories ?? [], svgLoader: loader)
        } catch {
            Log.content.error("Could not read content: \(error.localizedDescription, privacy: .public)")
            self.init(items: [], svgLoader: loader)
        }
    }

    static func decodeCatalog(from data: Data) -> ContentCatalog? {
        do {
            let catalog = try JSONDecoder().decode(ContentCatalog.self, from: data)
            if catalog.version > ContentCatalog.supportedVersion {
                Log.content.notice("Content version \(catalog.version) is newer than supported; decoding tolerantly")
            }
            return catalog
        } catch {
            Log.content.error("Corrupt content JSON: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func decodeItems(from data: Data) -> [ContentItem] {
        decodeCatalog(from: data)?.items ?? []
    }

    func items(in category: Category) -> [ContentItem] {
        allItems.filter { $0.category == category }
    }

    func item(id: String) -> ContentItem? {
        byId[id]
    }

    func categoryInfo(_ category: Category) -> CategoryInfo? {
        categories[category]
    }

    func drawing(for itemId: String) -> Drawing? {
        if let cached = drawingCache.withLock({ $0[itemId] }) { return cached }
        guard let item = byId[itemId] else { return nil }
        guard let data = svgLoader(item.svg) else {
            Log.content.error("Missing drawing \(item.svg, privacy: .public)")
            return nil
        }
        let drawing: Drawing
        do {
            drawing = DrawingBuilder.build(item: item, document: try SVGDocumentParser.parse(data))
        } catch {
            Log.content.error("Bad drawing \(item.svg, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
        guard !drawing.regions.isEmpty else {
            Log.content.error("Drawing \(item.svg, privacy: .public) has no usable regions")
            return nil
        }
        drawingCache.withLock { $0[itemId] = drawing }
        return drawing
    }
}
