import Foundation

/// Every service the app uses, created once in `KidsColoringApp` and handed to `AppCoordinator`.
/// No singletons: tests build their own container from fakes.
@MainActor
final class DependencyContainer {
    let content: any ContentProviding
    let settings: any SettingsStoring
    let audio: any AudioPlaying
    let progress: any ProgressStoring
    let render: any RenderServicing
    let profiles: any ProfileProviding
    let photos: any PhotoExporting

    init(content: any ContentProviding,
         settings: any SettingsStoring,
         audio: any AudioPlaying,
         progress: any ProgressStoring,
         render: any RenderServicing,
         profiles: any ProfileProviding,
         photos: any PhotoExporting) {
        self.content = content
        self.settings = settings
        self.audio = audio
        self.progress = progress
        self.render = render
        self.profiles = profiles
        self.photos = photos
    }

    /// Debug builds only: `-uiTesting` (UI tests) starts from a clean, throwaway data folder
    /// and settings, so every UI test run sees a first launch and never touches real art.
    /// Release builds always use the real data folder.
    static func live(bundle: Bundle = .main, arguments: [String] = ProcessInfo.processInfo.arguments) -> DependencyContainer {
        var defaults = UserDefaults.standard
        var root = StoragePaths.defaultRoot()
        #if DEBUG
        if arguments.contains("-uiTesting"), let testDefaults = UserDefaults(suiteName: "KidsColoringUITests") {
            testDefaults.removePersistentDomain(forName: "KidsColoringUITests")
            defaults = testDefaults
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("UITest-\(UUID().uuidString)", isDirectory: true)
        }
        #endif

        let settings = UserDefaultsSettingsStore(defaults: defaults)
        let content = ContentRepository(bundle: bundle)
        let progress = ProgressStore(root: root)
        return DependencyContainer(
            content: content,
            settings: settings,
            audio: AudioService(settings: settings, content: content),
            progress: progress,
            render: RenderService(content: content),
            profiles: ProfileService(store: progress, settings: settings),
            photos: PhotoExporter()
        )
    }
}
