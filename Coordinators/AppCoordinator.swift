import SwiftUI

/// Root coordinator: owns navigation state, builds every screen and injects its dependencies.
/// ViewModels never navigate; they call the closures created here.
@MainActor @Observable
final class AppCoordinator {
    var root: AppRoot = .loading
    var path: [AppRoute] = []
    var sheet: AppSheet?

    @ObservationIgnored let deps: DependencyContainer
    @ObservationIgnored private var parentCoordinator: ParentCoordinator?
    @ObservationIgnored private var profileIdWhenParentOpened: String?
    /// Set when the parent area restored a backup or cleared art: start fresh on return.
    @ObservationIgnored private var dataWasReplaced = false

    init(deps: DependencyContainer) {
        self.deps = deps
    }

    /// Loads profiles and picks the first screen: the picker on first launch or when
    /// siblings share the device, otherwise straight to Home.
    func start() async {
        guard root == .loading else { return }
        await deps.progress.prepare()
        await deps.profiles.load()
        root = deps.profiles.profiles.count == 1 ? .home : .profilePicker
        deps.audio.settingsDidChange()   // starts background music if it is on
    }

    private var profileId: String {
        deps.profiles.activeProfile?.id ?? "default"
    }

    // MARK: - Navigation

    func showPicker(_ category: Category) { path.append(.picker(category: category)) }
    func showColoring(_ itemId: String) { path.append(.coloring(itemId: itemId)) }
    func showCelebration(_ itemId: String) { path.append(.celebration(itemId: itemId)) }
    func showGallery() { path.append(.gallery) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToHome() { path.removeAll() }

    /// "Color more" on the celebration screen: back to the picker the child came from,
    /// or to the item's category picker if they came from My Art.
    func colorMore(after itemId: String) {
        if let index = path.lastIndex(where: \.isPicker) {
            path.removeSubrange(path.index(after: index)...)
        } else if let category = deps.content.item(id: itemId)?.category {
            path = [.picker(category: category)]
        } else {
            path.removeAll()
        }
    }

    /// "My Art" on the celebration screen: Home → My Art, so Back returns Home.
    func showGalleryFromCelebration() { path = [.gallery] }

    func profileChosen() {
        path.removeAll()
        root = .home
    }

    /// Tapping the avatar on Home: only meaningful when there is someone to switch to.
    func switchProfile() {
        guard deps.profiles.profiles.count > 1 else { return }
        path.removeAll()
        root = .profilePicker
    }

    /// The parent area always opens behind the parental gate (see `ParentCoordinator`).
    func openParentArea(start: ParentRoute? = nil) {
        profileIdWhenParentOpened = deps.profiles.activeProfile?.id
        dataWasReplaced = false
        sheet = .parentArea(start: start)
    }

    func closeParentArea() { sheet = nil }

    /// A backup was restored or all art was cleared inside the parent area.
    func parentDataReplaced() { dataWasReplaced = true }

    func parentAreaDismissed() {
        parentCoordinator = nil
        if dataWasReplaced {
            // A restore or "clear all art" changed everything under us: start over.
            dataWasReplaced = false
            path.removeAll()
            root = deps.profiles.profiles.count == 1 ? .home : .profilePicker
            return
        }
        // The active profile was deleted or changed: start over from Home with the new one.
        if deps.profiles.activeProfile?.id != profileIdWhenParentOpened {
            path.removeAll()
        }
        if root == .profilePicker, deps.profiles.profiles.count == 1 {
            root = .home
        }
    }

    // MARK: - Screen factory

    func makeHomeView() -> some View {
        HomeView(vm: HomeViewModel(
            audio: deps.audio,
            profiles: deps.profiles,
            content: deps.content,
            progress: deps.progress,
            onSelectCategory: { [weak self] in self?.showPicker($0) },
            onOpenGallery: { [weak self] in self?.showGallery() },
            onOpenParentArea: { [weak self] in self?.openParentArea() },
            onSwitchProfile: { [weak self] in self?.switchProfile() }))
    }

    func makeProfilePickerView() -> some View {
        ProfilePickerView(vm: ProfilePickerViewModel(
            profiles: deps.profiles,
            audio: deps.audio,
            onChosen: { [weak self] in self?.profileChosen() },
            onAddProfile: { [weak self] in self?.openParentArea(start: .profiles) }))
    }

    @ViewBuilder
    func view(for route: AppRoute) -> some View {
        switch route {
        case .picker(let category):
            PickerView(vm: PickerViewModel(
                category: category,
                profileId: profileId,
                content: deps.content,
                audio: deps.audio,
                progress: deps.progress,
                render: deps.render,
                language: deps.settings.voiceLanguage,
                onSelect: { [weak self] in self?.showColoring($0) },
                onBack: { [weak self] in self?.pop() }))
        case .coloring(let itemId):
            ColoringView(vm: ColoringViewModel(
                itemId: itemId,
                profileId: profileId,
                content: deps.content,
                audio: deps.audio,
                progress: deps.progress,
                render: deps.render,
                language: deps.settings.voiceLanguage,
                onDone: { [weak self] in self?.showCelebration(itemId) },
                onBack: { [weak self] in self?.pop() }))
        case .celebration(let itemId):
            CelebrationView(vm: CelebrationViewModel(
                itemId: itemId,
                profileId: profileId,
                content: deps.content,
                audio: deps.audio,
                progress: deps.progress,
                language: deps.settings.voiceLanguage,
                onColorMore: { [weak self] in self?.colorMore(after: itemId) },
                onMyArt: { [weak self] in self?.showGalleryFromCelebration() }))
        case .gallery:
            GalleryView(vm: GalleryViewModel(
                profileId: profileId,
                content: deps.content,
                progress: deps.progress,
                onOpen: { [weak self] in self?.showColoring($0) },
                onBack: { [weak self] in self?.pop() }))
        }
    }

    @ViewBuilder
    func view(for sheet: AppSheet) -> some View {
        switch sheet {
        case .parentArea(let start):
            ParentRootView(coordinator: currentParentCoordinator(start: start))
        }
    }

    private func currentParentCoordinator(start: ParentRoute?) -> ParentCoordinator {
        if let parentCoordinator { return parentCoordinator }
        let coordinator = ParentCoordinator(
            deps: deps,
            start: start,
            onFinish: { [weak self] in self?.closeParentArea() },
            onDataReplaced: { [weak self] in self?.parentDataReplaced() })
        parentCoordinator = coordinator
        return coordinator
    }
}

private extension AppRoute {
    var isPicker: Bool {
        if case .picker = self { return true }
        return false
    }
}
