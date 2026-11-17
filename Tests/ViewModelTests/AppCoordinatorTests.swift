import Testing
@testable import KidsColoring

@MainActor
struct AppCoordinatorTests {
    private func makeCoordinator() -> AppCoordinator {
        AppCoordinator(deps: makeTestContainer())
    }

    @Test func startsAtHomeWithNoSheet() {
        let coordinator = makeCoordinator()
        #expect(coordinator.path.isEmpty)
        #expect(coordinator.sheet == nil)
    }

    @Test func fullColoringFlowBuildsExpectedPath() {
        let coordinator = makeCoordinator()
        coordinator.showPicker(.fruits)
        coordinator.showColoring("apple")
        coordinator.showCelebration("apple")
        #expect(coordinator.path == [.picker(category: .fruits), .coloring(itemId: "apple"), .celebration(itemId: "apple")])
    }

    @Test func colorMoreReturnsToPickerTheChildCameFrom() {
        let coordinator = makeCoordinator()
        coordinator.showPicker(.fruits)
        coordinator.showColoring("apple")
        coordinator.showCelebration("apple")

        coordinator.colorMore(after: "apple")

        #expect(coordinator.path == [.picker(category: .fruits)])
    }

    @Test func colorMoreFromGalleryGoesToItemsCategoryPicker() {
        let coordinator = makeCoordinator()
        coordinator.showGallery()
        coordinator.showColoring("carrot")
        coordinator.showCelebration("carrot")

        coordinator.colorMore(after: "carrot")

        #expect(coordinator.path == [.picker(category: .vegetables)])
    }

    @Test func colorMoreWithUnknownItemGoesHome() {
        let coordinator = makeCoordinator()
        coordinator.showGallery()
        coordinator.showColoring("ghost")
        coordinator.showCelebration("ghost")

        coordinator.colorMore(after: "ghost")

        #expect(coordinator.path.isEmpty)
    }

    @Test func myArtFromCelebrationReplacesStackWithGallery() {
        let coordinator = makeCoordinator()
        coordinator.showPicker(.fruits)
        coordinator.showColoring("apple")
        coordinator.showCelebration("apple")

        coordinator.showGalleryFromCelebration()

        #expect(coordinator.path == [.gallery])
    }

    @Test func popIsSafeOnEmptyPath() {
        let coordinator = makeCoordinator()
        coordinator.pop()
        #expect(coordinator.path.isEmpty)
        coordinator.showGallery()
        coordinator.pop()
        #expect(coordinator.path.isEmpty)
    }

    @Test func parentAreaOpensAndCloses() {
        let coordinator = makeCoordinator()
        coordinator.openParentArea()
        #expect(coordinator.sheet?.id == AppSheet.parentArea(start: nil).id)
        coordinator.closeParentArea()
        #expect(coordinator.sheet == nil)
    }

    @Test func popToHomeClearsPath() {
        let coordinator = makeCoordinator()
        coordinator.showPicker(.vegetables)
        coordinator.showColoring("carrot")
        coordinator.popToHome()
        #expect(coordinator.path.isEmpty)
    }
}
