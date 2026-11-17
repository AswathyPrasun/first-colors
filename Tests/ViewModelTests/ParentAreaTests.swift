import Foundation
import Testing
@testable import KidsColoring

/// A clock the test moves by hand.
@MainActor
final class ManualClock {
    var now = Date(timeIntervalSince1970: 1_000)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

@MainActor
struct ParentGateTests {
    private func makeGate(_ clock: ManualClock, passed: @escaping @MainActor () -> Void = {},
                          cancelled: @escaping @MainActor () -> Void = {}) -> ParentGateViewModel {
        // The tick never returns on its own, so only explicit `update()` calls move progress.
        ParentGateViewModel(now: { clock.now },
                            tick: { try? await Task.sleep(for: .seconds(3600)) },
                            onPassed: passed, onCancel: cancelled)
    }

    @Test func holdingThreeSecondsOpensOnce() {
        let clock = ManualClock()
        var opened = 0
        let gate = makeGate(clock, passed: { opened += 1 })
        gate.pressBegan()
        clock.advance(1.5)
        gate.update()
        #expect(abs(gate.progress - 0.5) < 0.001)
        #expect(!gate.isPassed)
        clock.advance(1.5)
        gate.update()
        #expect(gate.isPassed)
        #expect(opened == 1)
        clock.advance(5)
        gate.update()
        gate.pressBegan()
        #expect(opened == 1)
    }

    @Test func releasingEarlyResets() {
        let clock = ManualClock()
        var opened = 0
        let gate = makeGate(clock, passed: { opened += 1 })
        gate.pressBegan()
        clock.advance(2.9)
        gate.update()
        gate.pressEnded()
        #expect(gate.progress == 0)
        #expect(!gate.isHolding)
        // Starting again needs the full 3 seconds from scratch.
        gate.pressBegan()
        clock.advance(2)
        gate.update()
        #expect(!gate.isPassed)
        clock.advance(1)
        gate.update()
        #expect(opened == 1)
    }

    @Test func tapsDoNothingAndCloseCancels() {
        let clock = ManualClock()
        var cancelled = 0
        let gate = makeGate(clock, cancelled: { cancelled += 1 })
        for _ in 0..<20 {
            gate.pressBegan()
            clock.advance(0.1)
            gate.update()
            gate.pressEnded()
        }
        #expect(!gate.isPassed)
        gate.cancel()
        #expect(cancelled == 1)
    }

    @Test func parentAreaStartsLockedAndOpensWhereAsked() {
        let coordinator = ParentCoordinator(deps: makeTestContainer(), start: .profiles, onFinish: {})
        #expect(!coordinator.isUnlocked)
        #expect(coordinator.path.isEmpty)
        coordinator.unlock()
        #expect(coordinator.isUnlocked)
        #expect(coordinator.path == [.profiles])
    }
}

@MainActor
struct ParentHomeTests {
    private func makeVM(store: FakeProgressStore = FakeProgressStore(),
                        profiles: ProfileService? = nil,
                        replaced: @escaping @MainActor () -> Void = {}) -> ParentHomeViewModel {
        ParentHomeViewModel(settings: FakeSettings(), audio: FakeAudio(), progress: store,
                            profiles: profiles ?? ProfileService(store: store, settings: FakeSettings()),
                            onShowProfiles: {}, onDataReplaced: replaced, onFinish: {})
    }

    @Test func showsRealStorageSize() async {
        let vm = makeVM()
        await vm.refreshStorage()
        #expect(vm.storageText.contains("MB"))
    }

    @Test func clearAllArtAsksFirstThenClears() async {
        let store = FakeProgressStore(colorings: [FakeProgressStore.key("p1", "apple"): SavedColoring(completedAt: Date())])
        var replaced = 0
        let vm = makeVM(store: store, replaced: { replaced += 1 })
        vm.askToClearAllArt()
        #expect(vm.isConfirmingClear)
        #expect(await store.coloring("p1", "apple") != nil)
        await vm.clearAllArt()
        #expect(await store.coloring("p1", "apple") == nil)
        #expect(replaced == 1)
        #expect(vm.message != nil)
    }

    @Test func backupProducesAFileToShare() async {
        let store = FakeProgressStore()
        let vm = makeVM(store: store)
        await vm.makeBackup()
        #expect(vm.backupURL != nil)
        #expect(await store.backupsMade == 1)
    }

    @Test func restoreNeedsConfirmationThenReloadsProfiles() async {
        let store = FakeProgressStore()
        let profiles = ProfileService(store: store, settings: FakeSettings())
        var replaced = 0
        let vm = makeVM(store: store, profiles: profiles, replaced: { replaced += 1 })
        vm.backupPicked(.success(URL(fileURLWithPath: "/backup.zip")))
        #expect(vm.pendingRestoreURL != nil)
        await vm.restorePendingBackup()
        #expect(replaced == 1)
        #expect(vm.message?.contains("2") == true)
        #expect(vm.pendingRestoreURL == nil)
    }

    @Test func failedRestoreExplainsAndChangesNothing() async {
        let store = FakeProgressStore()
        await store.setRestoreResult(.failure(.newerVersion))
        var replaced = 0
        let vm = makeVM(store: store, replaced: { replaced += 1 })
        vm.backupPicked(.success(URL(fileURLWithPath: "/backup.zip")))
        await vm.restorePendingBackup()
        #expect(replaced == 0)
        #expect(vm.message == ParentHomeViewModel.describe(.newerVersion))
    }

    @Test func restoreOrClearResetsTheAppOnReturn() async {
        let store = FakeProgressStore(profiles: [Profile(avatar: .bear), Profile(avatar: .cat)])
        let coordinator = AppCoordinator(deps: makeTestContainer(store: store))
        await coordinator.start()
        coordinator.profileChosen()
        coordinator.showPicker(.fruits)

        // Nothing replaced: the child returns to where they were.
        coordinator.openParentArea()
        coordinator.closeParentArea()
        coordinator.parentAreaDismissed()
        #expect(coordinator.path == [.picker(category: .fruits)])
        #expect(coordinator.root == .home)

        // After a restore: start over (two children → "Who's coloring?").
        coordinator.openParentArea()
        coordinator.parentDataReplaced()
        coordinator.closeParentArea()
        coordinator.parentAreaDismissed()
        #expect(coordinator.path.isEmpty)
        #expect(coordinator.root == .profilePicker)
    }
}

@MainActor
struct ExportArtTests {
    private func setup(photos: FakePhotoExporter) async -> (ExportArtViewModel, FakeProgressStore) {
        let bear = Profile(avatar: .bear), cat = Profile(avatar: .cat)
        let store = FakeProgressStore(profiles: [bear, cat], colorings: [
            FakeProgressStore.key(bear.id, "apple"): SavedColoring(fills: ["body": "#E53935"], completedAt: Date()),
            FakeProgressStore.key(cat.id, "carrot"): SavedColoring(completedAt: Date()),
            FakeProgressStore.key(cat.id, "banana"): SavedColoring(),            // not finished
        ])
        let profiles = ProfileService(store: store, settings: FakeSettings())
        await profiles.load()
        let vm = ExportArtViewModel(profiles: profiles, content: FakeContent(), progress: store,
                                    render: FakeRender(), photos: photos)
        await vm.load()
        return (vm, store)
    }

    @Test func listsFinishedArtFromEveryChild() async {
        let (vm, _) = await setup(photos: FakePhotoExporter())
        #expect(Set(vm.entries.map(\.itemId)) == ["apple", "carrot"])
        #expect(Set(vm.entries.map(\.avatar)) == [.bear, .cat])
    }

    @Test func savesSelectedPicturesAtFullSize() async {
        let photos = FakePhotoExporter()
        let (vm, _) = await setup(photos: photos)
        vm.selectAll()
        await vm.saveSelected()
        #expect(await photos.saved.count == 2)
        #expect(vm.selection.isEmpty)
        #expect(vm.message != nil)
    }

    @Test func deniedPermissionExplainsAndSavesNothing() async {
        let photos = FakePhotoExporter(allowed: false)
        let (vm, _) = await setup(photos: photos)
        vm.selectAll()
        await vm.saveSelected()
        #expect(await photos.saved.isEmpty)
        #expect(vm.message?.contains("Settings") == true)
    }

    @Test func failedSaveIsReportedGently() async {
        let (vm, _) = await setup(photos: FakePhotoExporter(fails: true))
        vm.selectAll()
        await vm.saveSelected()
        #expect(vm.message?.contains("free space") == true)
        #expect(!vm.selection.isEmpty)   // nothing lost; they can try again
    }
}
