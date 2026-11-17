import SwiftUI

@main
struct KidsColoringApp: App {
    @State private var coordinator: AppCoordinator

    init() {
        let deps = DependencyContainer.live()
        _coordinator = State(initialValue: AppCoordinator(deps: deps))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
    }
}

/// Launch backdrop → profile picker or the Home `NavigationStack`, plus the parent sheet.
struct AppRootView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.root {
            case .loading:
                // Same color as the launch screen; profiles load in a few milliseconds.
                DSColor.bgHome.ignoresSafeArea()
            case .profilePicker:
                coordinator.makeProfilePickerView()
                    .transition(.opacity)
            case .home:
                NavigationStack(path: $coordinator.path) {
                    coordinator.makeHomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            coordinator.view(for: route)
                        }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.root)
        .tint(DSColor.ink)
        .sheet(item: $coordinator.sheet, onDismiss: coordinator.parentAreaDismissed) { sheet in
            coordinator.view(for: sheet)
        }
        .task { await coordinator.start() }
    }
}
