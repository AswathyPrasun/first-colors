import Testing
@testable import KidsColoring

@MainActor
private func makeProfiles() -> ProfileService {
    ProfileService(store: FakeProgressStore(), settings: FakeSettings())
}

@MainActor
struct HomeViewModelTests {
    @Test func selectingCategorySpeaksAndNavigates() {
        let audio = FakeAudio()
        let selected = CallbackRecorder<KidsColoring.Category>()
        let vm = HomeViewModel(audio: audio, profiles: makeProfiles(), content: FakeContent(), progress: FakeProgressStore(),
                               onSelectCategory: selected.record,
                               onOpenGallery: {},
                               onOpenParentArea: {},
                               onSwitchProfile: {})

        vm.selectCategory(.vegetables)

        #expect(selected.values == [.vegetables])
        #expect(audio.played == [.categoryName(.vegetables)])
    }

    @Test func speakerOnlySpeaks() {
        let audio = FakeAudio()
        let selected = CallbackRecorder<KidsColoring.Category>()
        let vm = HomeViewModel(audio: audio, profiles: makeProfiles(), content: FakeContent(), progress: FakeProgressStore(), onSelectCategory: selected.record,
                               onOpenGallery: {}, onOpenParentArea: {}, onSwitchProfile: {})

        vm.speak(.fruits)

        #expect(selected.count == 0)
        #expect(audio.played == [.categoryName(.fruits)])
    }

    @Test func galleryAndParentCallbacks() {
        var gallery = 0
        var parent = 0
        let vm = HomeViewModel(audio: FakeAudio(), profiles: makeProfiles(), content: FakeContent(), progress: FakeProgressStore(), onSelectCategory: { _ in },
                               onOpenGallery: { gallery += 1 },
                               onOpenParentArea: { parent += 1 },
                               onSwitchProfile: {})
        vm.openGallery()
        vm.openParentArea()
        #expect(gallery == 1)
        #expect(parent == 1)
    }
}

@MainActor
struct PickerViewModelTests {
    @Test func listsOnlyItemsInCategory() {
        let vm = PickerViewModel(category: .fruits, profileId: "p1", content: FakeContent(), audio: FakeAudio(),
                                 progress: FakeProgressStore(), render: FakeRender(), language: .en, onSelect: { _ in }, onBack: {})
        #expect(vm.tiles.map(\.id) == ["apple", "banana"])
        #expect(vm.tiles.map(\.name) == ["Apple", "Banana"])
    }

    @Test func namesFollowVoiceLanguageWithEnglishFallback() {
        let vm = PickerViewModel(category: .fruits, profileId: "p1", content: FakeContent(), audio: FakeAudio(),
                                 progress: FakeProgressStore(), render: FakeRender(), language: .ar, onSelect: { _ in }, onBack: {})
        #expect(vm.tiles.map(\.name) == ["تفاحة", "Banana"])
    }

    @Test func selectSpeaksNameAndNavigates() {
        let audio = FakeAudio()
        let selected = CallbackRecorder<String>()
        let vm = PickerViewModel(category: .fruits, profileId: "p1", content: FakeContent(), audio: audio,
                                 progress: FakeProgressStore(), render: FakeRender(), language: .en, onSelect: selected.record, onBack: {})

        vm.select("apple")

        #expect(selected.values == ["apple"])
        #expect(audio.played == [.itemName(itemId: "apple")])
    }

    @Test func backCallsBack() {
        var back = 0
        let vm = PickerViewModel(category: .fruits, profileId: "p1", content: FakeContent(), audio: FakeAudio(),
                                 progress: FakeProgressStore(), render: FakeRender(), language: .en, onSelect: { _ in }, onBack: { back += 1 })
        vm.back()
        #expect(back == 1)
    }
}

@MainActor
struct CelebrationViewModelTests {
    @Test func appearPlaysOnlyOnce() {
        let audio = FakeAudio()
        let vm = CelebrationViewModel(itemId: "apple", profileId: "p1", content: FakeContent(), audio: audio, progress: FakeProgressStore(),
                                      language: .en, onColorMore: {}, onMyArt: {})
        vm.appear()
        vm.appear()
        #expect(audio.played == [.effect(.cheer), .colorSentence(itemId: "apple")])
        #expect(vm.itemName == "Apple")
        #expect(vm.message == "Apples can be red!")
    }

    @Test func buttonsCallCoordinator() {
        var more = 0
        var art = 0
        let vm = CelebrationViewModel(itemId: "apple", profileId: "p1", content: FakeContent(), audio: FakeAudio(), progress: FakeProgressStore(),
                                      language: .en, onColorMore: { more += 1 }, onMyArt: { art += 1 })
        vm.colorMore()
        vm.openMyArt()
        #expect(more == 1)
        #expect(art == 1)
    }
}

@MainActor
struct ParentHomeViewModelTests {
    @Test func togglesWriteThroughToSettings() {
        let settings = FakeSettings()
        let audio = FakeAudio()
        let vm = ParentHomeViewModel(settings: settings, audio: audio, progress: FakeProgressStore(), profiles: makeProfiles(), onShowProfiles: {}, onFinish: {})
        vm.soundEnabled = false
        vm.musicEnabled = false
        vm.voiceLanguage = .ar
        #expect(settings.soundEnabled == false)
        #expect(settings.musicEnabled == false)
        #expect(settings.voiceLanguage == .ar)
        #expect(audio.settingsChanges == 3)
    }
}
