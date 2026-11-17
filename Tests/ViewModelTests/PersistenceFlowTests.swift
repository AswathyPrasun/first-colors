import CoreGraphics
import Foundation
import Testing
@testable import KidsColoring

@MainActor
struct ProfileServiceTests {
    @Test func firstProfileBecomesActiveAndIsSaved() async {
        let store = FakeProgressStore()
        let settings = FakeSettings()
        let service = ProfileService(store: store, settings: settings)
        await service.load()
        #expect(service.profiles.isEmpty)
        let bear = await service.add(.bear)
        #expect(service.activeProfile == bear)
        #expect(settings.activeProfileId == bear?.id)
        #expect(await store.loadProfiles().profiles.map(\.avatar) == [.bear])
    }

    @Test func avatarsAreUniqueAndCappedAtFour() async {
        let service = ProfileService(store: FakeProgressStore(), settings: FakeSettings())
        await service.add(.bear)
        #expect(await service.add(.bear) == nil)
        await service.add(.bunny)
        await service.add(.cat)
        await service.add(.lion)
        #expect(service.profiles.count == 4)
        #expect(!service.canAddProfile)
        #expect(service.availableAvatars.isEmpty)
    }

    @Test func deletingActiveProfileSwitchesAndRemovesArt() async {
        let store = FakeProgressStore()
        let service = ProfileService(store: store, settings: FakeSettings())
        let bear = await service.add(.bear)!
        let lion = await service.add(.lion)!
        service.activate(profileId: lion.id)
        await service.delete(profileId: lion.id)
        #expect(service.activeProfile == bear)
        #expect(await store.deletedProfiles == [lion.id])
        // The last profile can't be deleted.
        await service.delete(profileId: bear.id)
        #expect(service.profiles == [bear])
    }

    @Test func staleActiveIdFallsBackToFirstProfile() async {
        let bear = Profile(avatar: .bear)
        let settings = FakeSettings()
        settings.activeProfileId = "deleted-elsewhere"
        let service = ProfileService(store: FakeProgressStore(profiles: [bear]), settings: settings)
        await service.load()
        #expect(service.activeProfile == bear)
    }

    @Test func changeAvatarOnlyToAFreeOne() async {
        let service = ProfileService(store: FakeProgressStore(), settings: FakeSettings())
        let bear = await service.add(.bear)!
        await service.add(.cat)
        await service.changeAvatar(profileId: bear.id, to: .cat)
        #expect(service.profiles.first?.avatar == .bear)
        await service.changeAvatar(profileId: bear.id, to: .lion)
        #expect(service.profiles.first?.avatar == .lion)
    }

    @Test func failedSaveKeepsWorkingInMemory() async {
        let store = FakeProgressStore()
        await store.setFailWrites(true)
        let service = ProfileService(store: store, settings: FakeSettings())
        #expect(await service.add(.bear) != nil)
        #expect(service.profiles.count == 1)
    }
}

@MainActor
struct ColoringPersistenceTests {
    private func makeVM(store: FakeProgressStore, onDone: @escaping @MainActor () -> Void = {},
                        onBack: @escaping @MainActor () -> Void = {}) async -> ColoringViewModel {
        let vm = ColoringViewModel(itemId: "squares", profileId: "p1", content: TestDrawings.content(),
                                   audio: FakeAudio(), progress: store, render: FakeRender(),
                                   language: .en, onDone: onDone, onBack: onBack)
        await vm.load()
        return vm
    }

    private func tap(_ vm: ColoringViewModel, _ x: CGFloat, _ y: CGFloat) {
        vm.touchBegan(at: CGPoint(x: x, y: y), pointsPerUnit: 1)
        vm.touchEnded()
    }

    @Test func fillAutosavesRightAway() async {
        let store = FakeProgressStore()
        let vm = await makeVM(store: store)
        tap(vm, 30, 30)
        await vm.finishSaving(markCompleted: false)
        #expect(await store.coloring("p1", "squares")?.fills == ["body": "#E53935"])
    }

    @Test func strokeIsSavedWhenTheFingerLifts() async {
        let store = FakeProgressStore()
        let vm = await makeVM(store: store)
        vm.select(.crayon)
        vm.touchBegan(at: CGPoint(x: 30, y: 30), pointsPerUnit: 1)
        vm.touchMoved(to: CGPoint(x: 60, y: 30))
        #expect(await store.strokeSaves == 0)          // not on every point
        vm.touchEnded()
        await waitUntil { await store.strokeSaves == 1 }
        #expect(await store.coloring("p1", "squares")?.strokes.count == 1)
    }

    @Test func reopeningRestoresFillsAndStrokesAndIgnoresUnknownRegions() async {
        let saved = SavedColoring(
            fills: ["body": "#E53935", "ghostRegion": "#43A047"],
            strokes: [Stroke(regionId: "leaf", color: "#1E88E5", width: 19.5, points: [StrokePoint(x: 200, y: 30)]),
                      Stroke(regionId: "removedPart", color: "#1E88E5", width: 19.5, points: [StrokePoint(x: 1, y: 1)])])
        let store = FakeProgressStore(colorings: [FakeProgressStore.key("p1", "squares"): saved])
        let vm = await makeVM(store: store)
        #expect(vm.fills == ["body": "#E53935"])
        #expect(vm.strokes.map(\.regionId) == ["leaf"])
        #expect(!vm.canUndo)   // loading is not an undoable action
        #expect(vm.loadGeneration == 1)
    }

    @Test func touchesBeforeLoadAreIgnored() async {
        let vm = ColoringViewModel(itemId: "squares", profileId: "p1", content: TestDrawings.content(),
                                   audio: FakeAudio(), progress: FakeProgressStore(), render: FakeRender(),
                                   language: .en, onDone: {}, onBack: {})
        tap(vm, 30, 30)
        #expect(vm.fills.isEmpty)
        await vm.load()
        tap(vm, 30, 30)
        #expect(vm.fills["body"] != nil)
    }

    @Test func doneSavesThumbnailMarksCompletedThenCelebrates() async {
        let store = FakeProgressStore()
        var celebrated = false
        let vm = await makeVM(store: store, onDone: {
            celebrated = true
        })
        tap(vm, 30, 30)
        vm.done()
        await waitUntil { celebrated }
        #expect(await store.thumbnailSaves == 1)
        #expect(await store.completedMarks == 1)
        #expect(await store.coloring("p1", "squares")?.completedAt != nil)
    }

    @Test func backSavesAThumbnailOnlyWhenSomethingChanged() async {
        let store = FakeProgressStore()
        var left = 0
        let vm = await makeVM(store: store, onBack: { left += 1 })
        vm.back()
        await waitUntil { left == 1 }
        #expect(await store.thumbnailSaves == 0)

        let vm2 = await makeVM(store: store, onBack: { left += 1 })
        tap(vm2, 30, 30)
        vm2.back()
        await waitUntil { left == 2 }
        #expect(await store.thumbnailSaves == 1)
        #expect(await store.completedMarks == 0)
    }

    @Test func undoIsSavedToo() async {
        let store = FakeProgressStore()
        let vm = await makeVM(store: store)
        tap(vm, 30, 30)
        vm.undo()
        await vm.finishSaving(markCompleted: false)
        #expect(await store.coloring("p1", "squares")?.fills == [:])
    }

    @Test func fullDiskNeverStopsTheChild() async {
        let store = FakeProgressStore()
        await store.setFailWrites(true)
        let vm = await makeVM(store: store)
        tap(vm, 30, 30)
        vm.select(.crayon)
        vm.touchBegan(at: CGPoint(x: 200, y: 30), pointsPerUnit: 1)
        vm.touchEnded()
        await vm.finishSaving(markCompleted: true)
        #expect(vm.fills["body"] == "#E53935")
        #expect(vm.strokes.count == 1)
    }

    @Test func autosaveCoalescesBursts() async {
        let store = FakeProgressStore()
        let queue = AutosaveQueue(store: store, itemId: "squares", profileId: "p1")
        for index in 0..<50 {
            queue.save(strokes: [Stroke(regionId: "body", color: "#E53935", width: 19.5,
                                        points: [StrokePoint(x: Float(index), y: 0)])])
        }
        await queue.flush()
        // The first write starts right away; the other 49 collapse into one.
        #expect(queue.writeCount <= 2)
        #expect(await store.coloring("p1", "squares")?.strokes.first?.points.first?.x == 49)
    }
}

@MainActor
struct StartAndProfileFlowTests {
    @Test func firstLaunchShowsThePickerAndPickingAnAvatarGoesHome() async {
        let store = FakeProgressStore()
        let coordinator = AppCoordinator(deps: makeTestContainer(store: store))
        await coordinator.start()
        #expect(coordinator.root == .profilePicker)
        #expect(await store.prepared == 1)

        var chosen = 0
        let picker = ProfilePickerViewModel(profiles: coordinator.deps.profiles, audio: FakeAudio(),
                                            onChosen: { chosen += 1; coordinator.profileChosen() },
                                            onAddProfile: {})
        #expect(picker.isFirstLaunch)
        #expect(picker.choices.map(\.avatar) == Avatar.allCases)
        #expect(!picker.canAddProfile)
        await picker.choose(.new(.bunny))
        #expect(chosen == 1)
        #expect(coordinator.root == .home)
        #expect(coordinator.deps.profiles.activeProfile?.avatar == .bunny)
    }

    @Test func singleProfileSkipsThePicker() async {
        let coordinator = AppCoordinator(deps: makeTestContainer(store: FakeProgressStore(profiles: [Profile(avatar: .cat)])))
        await coordinator.start()
        #expect(coordinator.root == .home)
        coordinator.switchProfile()          // nobody to switch to
        #expect(coordinator.root == .home)
    }

    @Test func siblingsSeeThePickerAndCanSwitchFromHome() async {
        let bear = Profile(avatar: .bear), lion = Profile(avatar: .lion)
        let coordinator = AppCoordinator(deps: makeTestContainer(store: FakeProgressStore(profiles: [bear, lion])))
        await coordinator.start()
        #expect(coordinator.root == .profilePicker)
        let picker = ProfilePickerViewModel(profiles: coordinator.deps.profiles, audio: FakeAudio(),
                                            onChosen: { coordinator.profileChosen() }, onAddProfile: {})
        #expect(picker.canAddProfile)
        await picker.choose(.existing(lion))
        #expect(coordinator.deps.profiles.activeProfile == lion)
        coordinator.showPicker(.fruits)
        coordinator.switchProfile()
        #expect(coordinator.root == .profilePicker)
        #expect(coordinator.path.isEmpty)
    }

    @Test func addProfileFromPickerOpensParentProfiles() async {
        let coordinator = AppCoordinator(deps: makeTestContainer(store: FakeProgressStore(profiles: [Profile(avatar: .bear), Profile(avatar: .cat)])))
        await coordinator.start()
        coordinator.openParentArea(start: .profiles)
        if case .parentArea(let start)? = coordinator.sheet { #expect(start == .profiles) } else { Issue.record("no sheet") }
    }
}

@MainActor
struct SavedArtScreensTests {
    private func store() -> FakeProgressStore {
        FakeProgressStore(colorings: [
            FakeProgressStore.key("p1", "apple"): SavedColoring(fills: ["body": "#E53935"], completedAt: Date(timeIntervalSince1970: 100)),
            FakeProgressStore.key("p1", "banana"): SavedColoring(fills: ["body": "#FDD835"], completedAt: Date(timeIntervalSince1970: 200)),
            FakeProgressStore.key("p1", "carrot"): SavedColoring(fills: ["body": "#FB8C00"]),          // not finished
            FakeProgressStore.key("p1", "dragonfruit"): SavedColoring(completedAt: Date()),            // no longer in the app
            FakeProgressStore.key("p2", "apple"): SavedColoring(completedAt: Date()),                  // someone else's
        ])
    }

    @Test func galleryShowsOnlyThisChildsFinishedArtNewestFirst() async {
        var opened: [String] = []
        let vm = GalleryViewModel(profileId: "p1", content: FakeContent(), progress: store(),
                                  onOpen: { opened.append($0) }, onBack: {})
        #expect(!vm.isEmpty)    // not "empty" before loading
        await vm.load()
        #expect(vm.entries.map(\.id) == ["banana", "apple"])
        vm.open("banana")
        #expect(opened == ["banana"])
    }

    @Test func emptyGallery() async {
        let vm = GalleryViewModel(profileId: "nobody", content: FakeContent(), progress: store(),
                                  onOpen: { _ in }, onBack: {})
        await vm.load()
        #expect(vm.isEmpty)
    }

    @Test func pickerShowsCheckBadgesAndLoadsThumbnails() async {
        let vm = PickerViewModel(category: .fruits, profileId: "p1", content: FakeContent(), audio: FakeAudio(),
                                 progress: store(), render: FakeRender(), language: .en,
                                 onSelect: { _ in }, onBack: {})
        await vm.refresh()
        #expect(vm.tiles.map(\.isCompleted) == [true, true])
        await vm.loadThumbnail(for: "apple")
        #expect(vm.thumbnails["apple"] != nil)   // blank outline (no saved thumbnail in this store)
    }
}
