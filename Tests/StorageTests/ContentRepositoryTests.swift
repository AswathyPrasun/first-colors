import Foundation
import Testing
@testable import KidsColoring

struct ContentRepositoryTests {
    @Test func decodesValidCatalog() {
        let json = """
        { "version": 1, "items": [
          { "id": "apple", "category": "fruits", "svg": "x.svg", "name": { "en": "Apple" } },
          { "id": "carrot", "category": "vegetables", "svg": "x.svg", "name": { "en": "Carrot", "ar": "جزرة" } }
        ] }
        """
        let items = ContentRepository.decodeItems(from: Data(json.utf8))
        #expect(items.map(\.id) == ["apple", "carrot"])
    }

    @Test func skipsItemsWithUnknownCategoryOrMissingFields() {
        let json = """
        { "version": 1, "items": [
          { "id": "lion", "category": "animals", "svg": "x.svg", "name": { "en": "Lion" } },
          { "id": "broken" },
          42,
          { "id": "pear", "category": "fruits", "svg": "x.svg", "name": { "en": "Pear" } }
        ] }
        """
        let items = ContentRepository.decodeItems(from: Data(json.utf8))
        #expect(items.map(\.id) == ["pear"])
    }

    @Test func corruptJSONGivesEmptyCatalogInsteadOfCrashing() {
        #expect(ContentRepository.decodeItems(from: Data("not json {".utf8)).isEmpty)
        #expect(ContentRepository.decodeItems(from: Data()).isEmpty)
    }

    @Test func duplicateIdsKeepFirst() {
        let repo = ContentRepository(items: [
            ContentItem(id: "apple", category: .fruits, name: LocalizedText(en: "Apple")),
            ContentItem(id: "apple", category: .vegetables, name: LocalizedText(en: "Other")),
        ])
        #expect(repo.items(in: .fruits).count == 1)
        #expect(repo.items(in: .vegetables).isEmpty)
        #expect(repo.item(id: "apple")?.name.en == "Apple")
    }

    @Test func bundledContentLoads() {
        let repo = ContentRepository(bundle: Bundle(for: BundleToken.self))
        // The test bundle has no content.json; the app bundle does.
        #expect(repo.items(in: .fruits).isEmpty)
        let app = ContentRepository(bundle: .main)
        #expect(app.item(id: "apple") != nil)
    }

    @Test func missingResourceIsEmpty() {
        let repo = ContentRepository(bundle: .main, resource: "does-not-exist")
        #expect(repo.items(in: .fruits).isEmpty)
    }
}

private final class BundleToken {}

struct HexColorTests {
    @Test func parsesAndNormalizes() {
        #expect(HexColor.parse("#E53935") == 0xE53935)
        #expect(HexColor.parse("e53935") == 0xE53935)
        #expect(HexColor.normalized("#e53935") == "#E53935")
    }

    @Test func rejectsGarbage() {
        #expect(HexColor.parse("") == nil)
        #expect(HexColor.parse("#FFF") == nil)
        #expect(HexColor.parse("#GGGGGG") == nil)
        #expect(HexColor.parse("#E539351") == nil)
    }

    @Test func paletteIsExactlyEightValidColors() {
        #expect(KidPalette.colors.count == 8)
        #expect(Set(KidPalette.colors.map(\.hex)).count == 8)
        for color in KidPalette.colors {
            #expect(HexColor.normalized(color.hex) == color.hex)
        }
        #expect(KidPalette.color(forHex: "#43a047")?.accessibilityName == "Green")
    }
}
