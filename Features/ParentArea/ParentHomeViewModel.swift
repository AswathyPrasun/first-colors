import Foundation

@MainActor @Observable
final class ParentHomeViewModel {
    var soundEnabled: Bool {
        didSet { settings.soundEnabled = soundEnabled; audio.settingsDidChange() }
    }
    var musicEnabled: Bool {
        didSet { settings.musicEnabled = musicEnabled; audio.settingsDidChange() }
    }
    var voiceLanguage: VoiceLanguage {
        didSet { settings.voiceLanguage = voiceLanguage; audio.settingsDidChange() }
    }

    /// "1.2 MB" — real size of the app's data folder.
    private(set) var storageText = "…"
    private(set) var isWorking = false
    /// A finished backup waiting to be shared.
    var backupURL: URL?
    /// Result or problem to show in an alert.
    var message: String?
    var isConfirmingClear = false
    var isPickingBackup = false
    /// Chosen backup file, waiting for the "replace everything" confirmation.
    var pendingRestoreURL: URL?

    @ObservationIgnored private let settings: any SettingsStoring
    @ObservationIgnored private let audio: any AudioPlaying
    @ObservationIgnored private let progress: any ProgressStoring
    @ObservationIgnored private let profiles: any ProfileProviding
    @ObservationIgnored private let onShowProfiles: @MainActor () -> Void
    @ObservationIgnored private let onShowExport: @MainActor () -> Void
    @ObservationIgnored private let onDataReplaced: @MainActor () -> Void
    @ObservationIgnored private let onFinish: @MainActor () -> Void

    init(settings: any SettingsStoring,
         audio: any AudioPlaying,
         progress: any ProgressStoring,
         profiles: any ProfileProviding,
         onShowProfiles: @escaping @MainActor () -> Void,
         onShowExport: @escaping @MainActor () -> Void = {},
         onDataReplaced: @escaping @MainActor () -> Void = {},
         onFinish: @escaping @MainActor () -> Void) {
        self.settings = settings
        self.audio = audio
        self.progress = progress
        self.profiles = profiles
        self.soundEnabled = settings.soundEnabled
        self.musicEnabled = settings.musicEnabled
        self.voiceLanguage = settings.voiceLanguage
        self.onShowProfiles = onShowProfiles
        self.onShowExport = onShowExport
        self.onDataReplaced = onDataReplaced
        self.onFinish = onFinish
    }

    func showProfiles() { onShowProfiles() }
    func showExport() { onShowExport() }
    func finish() { onFinish() }

    func refreshStorage() async {
        let bytes = await progress.storageUsed()
        storageText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: Clear

    func askToClearAllArt() { isConfirmingClear = true }

    func clearAllArt() async {
        isConfirmingClear = false
        await progress.clearAllArt()
        onDataReplaced()
        await refreshStorage()
        message = String(localized: "All art was removed. Profiles were kept.")
    }

    // MARK: Backup

    func makeBackup() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            backupURL = try await progress.makeBackup()
        } catch {
            message = String(localized: "The backup couldn't be created. Check that the device has free space.")
        }
    }

    func chooseBackupToRestore() { isPickingBackup = true }

    /// Result of the file picker.
    func backupPicked(_ result: Result<URL, any Error>) {
        if case .success(let url) = result { pendingRestoreURL = url }
    }

    func restorePendingBackup() async {
        guard let url = pendingRestoreURL, !isWorking else { return }
        pendingRestoreURL = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let summary = try await progress.restoreBackup(from: url)
            await profiles.load()
            onDataReplaced()
            await refreshStorage()
            message = String(localized: "Restored \(summary.profiles) profiles and \(summary.drawings) drawings.")
        } catch let error as BackupError {
            message = Self.describe(error)
        } catch {
            message = Self.describe(.notABackup)
        }
    }

    static func describe(_ error: BackupError) -> String {
        switch error {
        case .notABackup: String(localized: "That file isn't a First Colors backup. Nothing was changed.")
        case .newerVersion: String(localized: "This backup is from a newer version of the app. Update the app, then try again. Nothing was changed.")
        case .unsafeContent: String(localized: "That backup file is damaged. Nothing was changed.")
        case .noProfiles: String(localized: "That backup has no profiles in it. Nothing was changed.")
        case .writeFailed: String(localized: "The backup couldn't be restored. Check that the device has free space. Nothing was changed.")
        }
    }
}
