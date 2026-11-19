import CoreGraphics
import Foundation
import Testing
@testable import KidsColoring

struct AudioCatalogTests {
    private let content = FakeContent([
        ContentItem(id: "apple", category: .fruits, name: LocalizedText(en: "Apple", ar: "تفاحة"),
                    colorSentence: LocalizedText(en: "Apples can be red!", ar: "التفاح أحمر!"),
                    nameAudio: LocalizedText(en: "apple_en.m4a", ar: "apple_ar.m4a"),
                    colorSentenceAudio: LocalizedText(en: "apple_sentence_en.m4a", ar: "apple_sentence_ar.m4a")),
    ])

    private func catalog(files: Set<String>, speech: Bool) -> AudioCatalog {
        AudioCatalog(content: content, fileExists: { files.contains($0) }, speechFallback: speech)
    }

    @Test func recordedVoiceLinesWinInTheChosenLanguage() {
        let catalog = catalog(files: ["apple_en.m4a", "apple_ar.m4a"], speech: true)
        #expect(catalog.source(for: .itemName(itemId: "apple"), language: .en) == .file("apple_en.m4a"))
        #expect(catalog.source(for: .itemName(itemId: "apple"), language: .ar) == .file("apple_ar.m4a"))
    }

    @Test func missingRecordingSpeaksInDebugAndIsSilentInRelease() {
        let debug = catalog(files: [], speech: true)
        #expect(debug.source(for: .colorSentence(itemId: "apple"), language: .en) ==
                .speech(text: "Apples can be red!", language: .en))
        #expect(debug.source(for: .categoryName(.vegetables), language: .en) ==
                .speech(text: "Veggies", language: .en))
        let release = catalog(files: [], speech: false)
        #expect(release.source(for: .colorSentence(itemId: "apple"), language: .en) == .none)
    }

    @Test func effectsMapToBundledFilesAndUnknownItemsAreQuiet() {
        let catalog = catalog(files: Set(SoundEffect.allCases.map(\.fileName)), speech: false)
        #expect(catalog.source(for: .effect(.pop), language: .en) == .file("sfx_pop.m4a"))
        #expect(catalog.source(for: .effect(.crayon), language: .en) == .file("sfx_crayon_loop.m4a"))
        #expect(catalog.source(for: .itemName(itemId: "ghost"), language: .en) == .none)
    }

    @Test func everySoundEffectAndTheMusicShipInTheApp() {
        let lookup = BundleLookup(bundle: .main)
        for effect in SoundEffect.allCases {
            #expect(lookup.url(for: effect.fileName) != nil, "\(effect.fileName) missing")
        }
        #expect(lookup.url(for: AudioCatalog.musicFile) != nil)
    }
}

@MainActor
struct HomeAndCelebrationTests {
    @Test func homeShowsUpToThreeLatestFinishedPictures() async {
        let store = FakeProgressStore()
        let settings = FakeSettings()
        let profiles = ProfileService(store: store, settings: settings)
        let bear = await profiles.add(.bear)!
        for (index, item) in ["apple", "banana", "carrot"].enumerated() {
            await store.saveFills(["body": "#E53935"], itemId: item, profileId: bear.id)
            await store.saveThumbnail(Data("png".utf8), itemId: item, profileId: bear.id)
            await store.markCompleted(itemId: item, profileId: bear.id)
            if index == 0 { await store.saveFills([:], itemId: "unfinished", profileId: bear.id) }
        }
        let vm = HomeViewModel(audio: FakeAudio(), profiles: profiles, content: FakeContent(), progress: store,
                               onSelectCategory: { _ in }, onOpenGallery: {}, onOpenParentArea: {}, onSwitchProfile: {})
        await vm.refreshLatestArt()
        #expect(vm.latestArt.count == 3)
        #expect(vm.avatar == .bear)
        #expect(vm.profileId == bear.id)
    }

    @Test func homeIllustrationsUseTheRealDrawingsInSuggestedColors() {
        let content = ContentRepository(bundle: .main)
        let vm = HomeViewModel(audio: FakeAudio(), profiles: ProfileService(store: FakeProgressStore(), settings: FakeSettings()),
                               content: content, progress: FakeProgressStore(),
                               onSelectCategory: { _ in }, onOpenGallery: {}, onOpenParentArea: {}, onSwitchProfile: {})
        let apple = vm.illustration(for: .fruits)
        #expect(apple?.drawing.itemId == "apple")
        #expect(apple?.fills["body"] == "#E53935")
        #expect(vm.illustration(for: .vegetables)?.drawing.itemId == "carrot")
    }

    @Test func celebrationLoadsTheFinishedPicture() async {
        let saved = SavedColoring(fills: ["body": "#E53935", "gone": "#43A047"],
                                  strokes: [Stroke(regionId: "leaf", color: "#43A047", width: 19.5, points: [StrokePoint(x: 200, y: 30)])])
        let store = FakeProgressStore(colorings: [FakeProgressStore.key("p1", "squares"): saved])
        let vm = CelebrationViewModel(itemId: "squares", profileId: "p1", content: TestDrawings.content(),
                                      audio: FakeAudio(), progress: store, language: .en,
                                      onColorMore: {}, onMyArt: {})
        #expect(!vm.isLoaded)
        await vm.load()
        #expect(vm.isLoaded)
        #expect(vm.fills == ["body": "#E53935"])
        #expect(vm.strokes.count == 1)
        #expect(vm.drawing != nil)
    }

    @Test func confettiIsDeterministic() {
        var a = SeededGenerator(seed: 42), b = SeededGenerator(seed: 42)
        #expect((0..<10).map { _ in a.next() } == (0..<10).map { _ in b.next() })
    }

    @Test func reachingThePointLimitCheers() async {
        let audio = FakeAudio()
        let vm = ColoringViewModel(itemId: "squares", profileId: "p1", content: TestDrawings.content(),
                                   audio: audio, progress: FakeProgressStore(), render: FakeRender(),
                                   language: .en, onDone: {}, onBack: {})
        await vm.load()
        vm.select(.crayon)
        vm.touchBegan(at: CGPoint(x: 21, y: 21), pointsPerUnit: 1)
        var x: CGFloat = 21
        for index in 0..<(CrayonStyle.maxPointsPerDrawing + 10) where !vm.isAtPointLimit {
            x = x >= 139 ? 21 : x + 3
            vm.touchMoved(to: CGPoint(x: x, y: 21 + CGFloat(index % 100)))
        }
        #expect(audio.played.last == .effect(.cheer))
    }
}

@MainActor
struct AccessibilityTests {
    @Test func voiceOverCanColorEveryRegionByName() async {
        let vm = ColoringViewModel(itemId: "squares", profileId: "p1", content: TestDrawings.content(),
                                   audio: FakeAudio(), progress: FakeProgressStore(), render: FakeRender(),
                                   language: .en, onDone: {}, onBack: {})
        vm.fillRegion("leaf")
        #expect(vm.fills.isEmpty)          // not before loading
        await vm.load()
        vm.select(KidPalette.colors[4])
        vm.fillRegion("leaf")
        vm.fillRegion("ghost")             // unknown ids are ignored
        #expect(vm.fills == ["leaf": "#1E88E5"])
        #expect(vm.canUndo)
    }

    @Test func regionIdsReadAsWords() {
        #expect(DrawingCanvas.spokenName("leftLeaf") == "left leaf")
        #expect(DrawingCanvas.spokenName("body") == "body")
        #expect(DrawingCanvas.spokenName("whiteRind") == "white rind")
        #expect(DrawingCanvas.spokenName("front_wheel") == "front wheel")
        #expect(DrawingCanvas.spokenName("bigWheel") == "big wheel")
    }

    /// VoiceOver reads every part of every shipped drawing as plain lowercase words.
    @Test func everyBundledPartHasASpokenName() {
        let repo = ContentRepository(bundle: .main)
        for item in KidsColoring.Category.allCases.flatMap({ repo.items(in: $0) }) {
            for region in item.regions {
                let name = DrawingCanvas.spokenName(region.id)
                #expect(!name.isEmpty, "\(item.id).\(region.id)")
                #expect(name.allSatisfy { $0.isLowercase || $0 == " " }, "\(item.id).\(region.id) reads as \(name)")
                #expect(!name.contains("  "), "\(item.id).\(region.id)")
            }
        }
    }
}
