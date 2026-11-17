import Foundation

/// A string with per-language variants. English is required; others fall back to English.
/// Also used for per-language audio file names.
struct LocalizedText: Codable, Hashable, Sendable {
    let en: String
    let ar: String?

    init(en: String, ar: String? = nil) {
        self.en = en
        self.ar = ar
    }

    func text(for language: VoiceLanguage) -> String {
        switch language {
        case .en: en
        case .ar: ar ?? en
        }
    }
}

/// A fillable region as declared in `content.json`. Geometry lives in the SVG under the same id.
struct RegionSpec: Codable, Hashable, Sendable {
    let id: String
    /// Suggested `#RRGGBB` colors, best first. Magic uses the first one.
    let suggested: [String]

    init(id: String, suggested: [String]) {
        self.id = id
        self.suggested = suggested
    }

    private enum CodingKeys: String, CodingKey { case id, suggested }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        suggested = (try? container.decode([String].self, forKey: .suggested)) ?? []
    }
}

/// One colorable drawing from the bundled `content.json`.
struct ContentItem: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let category: Category
    /// SVG file name in the bundle, e.g. `apple.svg`.
    let svg: String
    let name: LocalizedText
    /// Celebration line, e.g. "Apples can be red!".
    let colorSentence: LocalizedText?
    let nameAudio: LocalizedText?
    let colorSentenceAudio: LocalizedText?
    let regions: [RegionSpec]

    init(id: String,
         category: Category,
         svg: String? = nil,
         name: LocalizedText,
         colorSentence: LocalizedText? = nil,
         nameAudio: LocalizedText? = nil,
         colorSentenceAudio: LocalizedText? = nil,
         regions: [RegionSpec] = []) {
        self.id = id
        self.category = category
        self.svg = svg ?? "\(id).svg"
        self.name = name
        self.colorSentence = colorSentence
        self.nameAudio = nameAudio
        self.colorSentenceAudio = colorSentenceAudio
        self.regions = regions
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, svg, name, colorSentence, nameAudio, colorSentenceAudio, regions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        category = try c.decode(Category.self, forKey: .category)
        svg = try c.decode(String.self, forKey: .svg)
        name = try c.decode(LocalizedText.self, forKey: .name)
        // Optional extras are tolerant: a malformed value is treated as missing.
        colorSentence = try? c.decodeIfPresent(LocalizedText.self, forKey: .colorSentence)
        nameAudio = try? c.decodeIfPresent(LocalizedText.self, forKey: .nameAudio)
        colorSentenceAudio = try? c.decodeIfPresent(LocalizedText.self, forKey: .colorSentenceAudio)
        regions = (try? c.decode(LossyArray<RegionSpec>.self, forKey: .regions).elements) ?? []
    }
}

/// Per-category voice line files (category names themselves are UI strings).
struct CategoryInfo: Decodable, Hashable, Sendable {
    let id: Category
    let nameAudio: LocalizedText?
}

/// Root of `content.json`.
struct ContentCatalog: Decodable, Sendable {
    static let supportedVersion = 1

    let version: Int
    let categories: [CategoryInfo]
    let items: [ContentItem]

    private enum CodingKeys: String, CodingKey { case version, categories, items }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        categories = (try? container.decode(LossyArray<CategoryInfo>.self, forKey: .categories).elements) ?? []
        // Tolerant: a single bad item is skipped instead of failing the whole catalog.
        items = try container.decode(LossyArray<ContentItem>.self, forKey: .items).elements
    }
}

/// Decodes an array, silently dropping elements that fail to decode.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    /// Always succeeds, so the unkeyed container advances past a bad element.
    private struct Skip: Decodable {
        init(from decoder: Decoder) {}
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                result.append(element)
            } else if (try? container.decode(Skip.self)) == nil {
                break
            }
        }
        elements = result
    }
}
