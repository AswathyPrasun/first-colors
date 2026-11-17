import SwiftUI

enum ParentRoute: Hashable {
    case profiles
    case exportArt
}

/// Child coordinator for the parent area. Shows the parental gate first, then owns its own
/// `NavigationStack`, and hands control back to `AppCoordinator` through `onFinish`.
@MainActor @Observable
final class ParentCoordinator {
    var path: [ParentRoute] = []
    private(set) var isUnlocked = false

    @ObservationIgnored let deps: DependencyContainer
    @ObservationIgnored private let start: ParentRoute?
    @ObservationIgnored private let onFinish: @MainActor () -> Void
    @ObservationIgnored private let onDataReplaced: @MainActor () -> Void

    init(deps: DependencyContainer,
         start: ParentRoute? = nil,
         onFinish: @escaping @MainActor () -> Void,
         onDataReplaced: @escaping @MainActor () -> Void = {}) {
        self.deps = deps
        self.start = start
        self.onFinish = onFinish
        self.onDataReplaced = onDataReplaced
    }

    func unlock() {
        isUnlocked = true
        if let start { path = [start] }
    }

    func showProfiles() { path.append(.profiles) }
    func showExportArt() { path.append(.exportArt) }
    func finish() { onFinish() }

    func makeGateView() -> some View {
        ParentGateView(vm: ParentGateViewModel(
            onPassed: { [weak self] in self?.unlock() },
            onCancel: { [weak self] in self?.finish() }))
    }

    func makeHomeView() -> some View {
        ParentHomeView(vm: ParentHomeViewModel(
            settings: deps.settings,
            audio: deps.audio,
            progress: deps.progress,
            profiles: deps.profiles,
            onShowProfiles: { [weak self] in self?.showProfiles() },
            onShowExport: { [weak self] in self?.showExportArt() },
            onDataReplaced: { [weak self] in self?.onDataReplaced() },
            onFinish: { [weak self] in self?.finish() }))
    }

    @ViewBuilder
    func view(for route: ParentRoute) -> some View {
        switch route {
        case .profiles:
            ProfilesView(vm: ProfilesViewModel(profiles: deps.profiles))
        case .exportArt:
            ExportArtView(vm: ExportArtViewModel(
                profiles: deps.profiles,
                content: deps.content,
                progress: deps.progress,
                render: deps.render,
                photos: deps.photos))
        }
    }
}

struct ParentRootView: View {
    @Bindable var coordinator: ParentCoordinator

    var body: some View {
        if coordinator.isUnlocked {
            NavigationStack(path: $coordinator.path) {
                coordinator.makeHomeView()
                    .navigationDestination(for: ParentRoute.self) { route in
                        coordinator.view(for: route)
                    }
            }
            .tint(DSColor.parentAccent)
            .transition(.opacity)
        } else {
            coordinator.makeGateView()
        }
    }
}
