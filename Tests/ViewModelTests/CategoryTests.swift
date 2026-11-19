import CoreGraphics
import Foundation
import Testing
@testable import KidsColoring

/// v1.1 categories: stable ids, one details table, per-category palettes, Home grid.
@MainActor
struct CategoryTests {
    typealias Cat = KidsColoring.Category

    // MARK: - Model

    @Test func rawValuesAreStableAndInHomeOrder() {
        #expect(Cat.allCases.map(\.rawValue) == ["fruits", "vegetables", "vehicles", "rescue_pups", "super_kids"])
    }

    @Test func newCategoriesDecodeAndUnknownOnesAreSkipped() {
        let json = """
        {"version": 1, "items": [
          {"id": "car", "category": "vehicles", "svg": "car.svg", "name": {"en": "Car"}, "regions": []},
          {"id": "fire_pup", "category": "rescue_pups", "svg": "fire_pup.svg", "name": {"en": "Fire Pup"}, "regions": []},
          {"id": "star_girl", "category": "super_kids", "svg": "star_girl.svg", "name": {"en": "Star Girl"}, "regions": []},
          {"id": "trex", "category": "dinosaurs", "svg": "trex.svg", "name": {"en": "T. rex"}, "regions": []}
        ]}
        """
        let items = ContentRepository.decodeItems(from: Data(json.utf8))
        #expect(items.map(\.id) == ["car", "fire_pup", "star_girl"])
        #expect(items.map(\.category) == [.vehicles, .rescuePups, .superKids])
    }

    // MARK: - Details table

    @Test(arguments: Cat.allCases)
    func everyCategoryHasCompleteDetails(_ category: Cat) {
        let details = category.details
        #expect(!details.coverItemId.isEmpty)
        #expect(!details.symbol.isEmpty)
        #expect(!details.spokenName.en.isEmpty)
        #expect(details.spokenName.ar?.isEmpty == false)
    }

    @Test func coversAndNamesAreDistinct() {
        let all = Cat.allCases.map(\.details)
        #expect(Set(all.map(\.coverItemId)).count == all.count)
        #expect(Set(all.map(\.spokenName.en)).count == all.count)
    }

    // MARK: - Palettes

    @Test func baseSetHasTenColorsAndNoBlack() {
        let hexes = KidPalette.base.map(\.hex)
        #expect(hexes.count == 10)
        #expect(Set(hexes).count == 10)
        #expect(!hexes.contains("#000000"))
        #expect(Set(KidPalette.colors.map(\.hex)).isSubset(of: Set(hexes)))
        #expect(KidPalette.color(forHex: "#78909c")?.accessibilityName == "Gray")
    }

    @Test(arguments: Cat.allCases)
    func everyPaletteIsEightBaseColors(_ category: Cat) {
        let palette = category.details.palette.map(\.hex)
        #expect(palette.count == 8)
        #expect(Set(palette).count == 8)
        #expect(Set(palette).isSubset(of: Set(KidPalette.base.map(\.hex))))
        // Shown in the base order, so the swatch layout is predictable across categories.
        let order = KidPalette.base.map(\.hex)
        #expect(palette == order.filter(palette.contains))
    }

    @Test func fruitsAndVegetablesKeepTheOriginalPalette() {
        #expect(Cat.fruits.details.palette == KidPalette.colors)
        #expect(Cat.vegetables.details.palette == KidPalette.colors)
    }

    @Test func vehiclesOfferGrayAndSky() {
        let names = Cat.vehicles.details.palette.map(\.accessibilityName)
        #expect(names.contains("Gray"))
        #expect(names.contains("Light blue"))
    }

    // MARK: - Coloring screen uses the category palette

    private func coloringVM(category: Cat, saved: SavedColoring = .empty) async -> ColoringViewModel {
        let base = TestDrawings.squaresItem
        let item = ContentItem(id: "squares", category: category, name: base.name, regions: base.regions)
        let content = FakeContent([item], drawings: ["squares": TestDrawings.squares()])
        let store = FakeProgressStore(colorings: saved == .empty ? [:] : [FakeProgressStore.key("p1", "squares"): saved])
        let vm = ColoringViewModel(itemId: "squares", profileId: "p1", content: content, audio: FakeAudio(),
                                   progress: store, render: FakeRender(), language: .en,
                                   onDone: {}, onBack: {})
        await vm.load()
        return vm
    }

    @Test func coloringScreenShowsTheCategoryPalette() async {
        let vm = await coloringVM(category: .vehicles)
        #expect(vm.palette == Cat.vehicles.details.palette)
        #expect(vm.selectedColor == vm.palette[0])
    }

    @Test func unknownItemFallsBackToTheOriginalPalette() {
        let vm = ColoringViewModel(itemId: "ghost", profileId: "p1", content: FakeContent(), audio: FakeAudio(),
                                   progress: FakeProgressStore(), render: FakeRender(), language: .en,
                                   onDone: {}, onBack: {})
        #expect(vm.palette == KidPalette.colors)
    }

    @Test func savedColorsOutsideThePaletteStillLoad() async {
        // Pink isn't in the Vehicles palette, and #123456 isn't in any palette: both are kept.
        let saved = SavedColoring(fills: ["body": "#F06292", "leaf": "#123456"])
        let vm = await coloringVM(category: .vehicles, saved: saved)
        #expect(!vm.palette.map(\.hex).contains("#F06292"))
        #expect(vm.fills["body"] == "#F06292")
        #expect(vm.fills["leaf"] == "#123456")
    }

    // MARK: - Home

    private func homeVM(content: FakeContent) -> HomeViewModel {
        HomeViewModel(audio: FakeAudio(),
                      profiles: ProfileService(store: FakeProgressStore(), settings: FakeSettings()),
                      content: content, progress: FakeProgressStore(),
                      onSelectCategory: { _ in }, onOpenGallery: {}, onOpenParentArea: {}, onSwitchProfile: {})
    }

    @Test func homeListsCategoriesInFixedOrder() {
        let items = [
            ContentItem(id: "star_girl", category: .superKids, name: LocalizedText(en: "Star Girl")),
            ContentItem(id: "car", category: .vehicles, name: LocalizedText(en: "Car")),
            ContentItem(id: "carrot", category: .vegetables, name: LocalizedText(en: "Carrot")),
            ContentItem(id: "fire_pup", category: .rescuePups, name: LocalizedText(en: "Fire Pup")),
            ContentItem(id: "apple", category: .fruits, name: LocalizedText(en: "Apple")),
        ]
        #expect(homeVM(content: FakeContent(items)).categories == Cat.allCases)
    }

    @Test func homeHidesCategoriesWithNoDrawings() {
        #expect(homeVM(content: FakeContent()).categories == [.fruits, .vegetables])
        #expect(homeVM(content: FakeContent([])).categories.isEmpty)
    }

    @Test func homeSpeaksTheCategoryName() {
        let audio = FakeAudio()
        let vm = HomeViewModel(audio: audio,
                               profiles: ProfileService(store: FakeProgressStore(), settings: FakeSettings()),
                               content: FakeContent(), progress: FakeProgressStore(),
                               onSelectCategory: { _ in }, onOpenGallery: {}, onOpenParentArea: {}, onSwitchProfile: {})
        vm.speak(.vehicles)
        #expect(audio.played == [.categoryName(.vehicles)])
    }

    @Test func spokenFallbackUsesTheDetailsTable() {
        let catalog = AudioCatalog(content: FakeContent(), fileExists: { _ in false }, speechFallback: true)
        #expect(catalog.source(for: .categoryName(.rescuePups), language: .en) == .speech(text: "Rescue Pups", language: .en))
        #expect(catalog.source(for: .categoryName(.vehicles), language: .ar) == .speech(text: "مركبات", language: .ar))
    }

    // MARK: - Audio

    @Test func finishSoundsAreSetForTheNewCategoriesOnly() {
        #expect(Cat.fruits.details.finishSound == nil)
        #expect(Cat.vegetables.details.finishSound == nil)
        #expect(Cat.vehicles.details.finishSound == .vroom)
        #expect(Cat.rescuePups.details.finishSound == .woof)
        #expect(Cat.superKids.details.finishSound == .whoosh)
    }

    @Test(arguments: [(Cat.vehicles, SoundEffect.vroom), (.rescuePups, .woof), (.superKids, .whoosh)])
    func celebrationAddsTheCategorySound(_ category: Cat, _ sound: SoundEffect) {
        let audio = FakeAudio()
        let item = ContentItem(id: "thing", category: category, name: LocalizedText(en: "Thing"))
        let vm = CelebrationViewModel(itemId: "thing", profileId: "p1", content: FakeContent([item]), audio: audio,
                                      progress: FakeProgressStore(), language: .en, onColorMore: {}, onMyArt: {})
        vm.appear()
        #expect(audio.played == [.effect(.cheer), .effect(sound), .colorSentence(itemId: "thing")])
    }

    @Test func celebrationShowsTheCategoryCheer() {
        func cheer(_ category: Cat?) -> String {
            let items = category.map { [ContentItem(id: "thing", category: $0, name: LocalizedText(en: "Thing"))] } ?? []
            let vm = CelebrationViewModel(itemId: "thing", profileId: "p1", content: FakeContent(items),
                                          audio: FakeAudio(), progress: FakeProgressStore(), language: .en,
                                          onColorMore: {}, onMyArt: {})
            return String(localized: vm.cheer)
        }
        #expect(cheer(.fruits) == "Yummy!")
        #expect(cheer(.vegetables) == "Yummy!")
        #expect(cheer(.vehicles) == "Vroom!")
        #expect(cheer(.rescuePups) == "Woof woof!")
        #expect(cheer(.superKids) == "Super!")
        #expect(cheer(nil) == "Yummy!")   // unknown item from an old save
    }

    @Test func bundledCategoryVoiceFilesFollowTheNamingScheme() {
        let repo = ContentRepository(bundle: .main)
        for category in Cat.allCases {
            let audio = repo.categoryInfo(category)?.nameAudio
            #expect(audio?.en == "category_\(category.rawValue)_en.m4a", "\(category)")
            #expect(audio?.ar == "category_\(category.rawValue)_ar.m4a", "\(category)")
        }
    }

    /// Debug builds speak every new name and sentence until recordings exist; release stays silent.
    @Test func newItemsSpeakInDebugAndStaySilentInRelease() {
        let repo = ContentRepository(bundle: .main)
        let debug = AudioCatalog(content: repo, fileExists: { _ in false }, speechFallback: true)
        let release = AudioCatalog(content: repo, fileExists: { _ in false }, speechFallback: false)
        for category in [Cat.vehicles, .rescuePups, .superKids] {
            for item in repo.items(in: category) {
                for language in VoiceLanguage.allCases {
                    #expect(debug.source(for: .itemName(itemId: item.id), language: language)
                            == .speech(text: item.name.text(for: language), language: language), "\(item.id)")
                    let sentence = item.colorSentence?.text(for: language) ?? ""
                    #expect(debug.source(for: .colorSentence(itemId: item.id), language: language)
                            == .speech(text: sentence, language: language), "\(item.id) sentence")
                    #expect(release.source(for: .itemName(itemId: item.id), language: language) == .none)
                }
            }
        }
    }

    @Test func recordedFilesWinOnceTheyAreAdded() {
        let repo = ContentRepository(bundle: .main)
        let catalog = AudioCatalog(content: repo, fileExists: { $0 == "fire_pup_ar.m4a" }, speechFallback: false)
        #expect(catalog.source(for: .itemName(itemId: "fire_pup"), language: .ar) == .file("fire_pup_ar.m4a"))
        #expect(catalog.source(for: .itemName(itemId: "fire_pup"), language: .en) == .none)
    }

    // MARK: - Home grid layout

    @Test func iPhoneUsesTwoColumnsWithACenteredLastRow() {
        let layout = HomeLayout(width: 370, isRegular: false, categoryCount: 5)
        #expect(layout.columns == 2)
        #expect(layout.rows(of: Array(1...5)) == [[1, 2], [3, 4], [5]])
        #expect(layout.tileHeight >= 150)
        #expect(layout.tileWidth * 2 + DSMetrics.spacing <= 370 + 0.5)
    }

    @Test func iPadPortraitUsesThreeColumnsAndLandscapeFive() {
        let portrait = HomeLayout(width: 1000, isRegular: true, categoryCount: 5)
        #expect(portrait.columns == 3)
        let landscape = HomeLayout(width: 1340, isRegular: true, categoryCount: 5)
        #expect(landscape.columns == 5)
        #expect(landscape.rows(of: Array(1...5)).count == 1)
        #expect(landscape.contentWidth <= 1340 + 0.5)
    }

    @Test func fewCategoriesNeverMakeHugeTiles() {
        let layout = HomeLayout(width: 1340, isRegular: true, categoryCount: 2)
        #expect(layout.columns == 2)
        #expect(layout.tileWidth <= 340)
    }

    @Test(arguments: [(370.0, false), (330.0, false), (790.0, true), (1000.0, true), (1340.0, true)])
    func pictureFitsBetweenSpeakerAndTitle(width: Double, regular: Bool) {
        let layout = HomeLayout(width: width, isRegular: regular, categoryCount: 5)
        #expect(layout.pictureSize >= 70)
        #expect(layout.pictureSize <= layout.tileWidth)
        // 40pt above the picture for the speaker button, ~60pt below for the title.
        #expect(layout.pictureSize + 100 <= layout.tileHeight + 0.5)
    }
}
