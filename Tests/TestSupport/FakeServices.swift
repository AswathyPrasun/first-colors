import CoreGraphics
import Foundation
@testable import KidsColoring

final class FakeContent: ContentProviding {
    let all: [ContentItem]
    let drawings: [String: Drawing]

    init(_ items: [ContentItem] = FakeContent.sample, drawings: [String: Drawing] = [:]) {
        all = items
        self.drawings = drawings
    }

    func items(in category: KidsColoring.Category) -> [ContentItem] {
        all.filter { $0.category == category }
    }

    func item(id: String) -> ContentItem? {
        all.first { $0.id == id }
    }

    func categoryInfo(_ category: KidsColoring.Category) -> CategoryInfo? { nil }

    func drawing(for itemId: String) -> Drawing? { drawings[itemId] }

    static let sample: [ContentItem] = [
        ContentItem(id: "apple", category: .fruits, name: LocalizedText(en: "Apple", ar: "تفاحة"),
                    colorSentence: LocalizedText(en: "Apples can be red!")),
        ContentItem(id: "banana", category: .fruits, name: LocalizedText(en: "Banana")),
        ContentItem(id: "carrot", category: .vegetables, name: LocalizedText(en: "Carrot", ar: "جزرة")),
    ]
}

@MainActor
final class FakeAudio: AudioPlaying {
    private(set) var played: [AudioCue] = []
    private(set) var stopCount = 0
    private(set) var loops: [SoundEffect] = []
    private(set) var stopLoopCount = 0

    func play(_ cue: AudioCue) { played.append(cue) }
    func startLoop(_ effect: SoundEffect) { loops.append(effect) }
    func stopLoop() { stopLoopCount += 1 }
    private(set) var settingsChanges = 0
    func settingsDidChange() { settingsChanges += 1 }
    func stopAll() { stopCount += 1 }
}

@MainActor
final class FakeSettings: SettingsStoring {
    var soundEnabled = true
    var musicEnabled = true
    var voiceLanguage: VoiceLanguage = .en
    var activeProfileId: String?
}

/// Records navigation callbacks so ViewModel tests can assert on them.
@MainActor
final class CallbackRecorder<Value> {
    private(set) var values: [Value] = []
    var count: Int { values.count }
    func record(_ value: Value) { values.append(value) }
}

@MainActor
func makeTestContainer(content: any ContentProviding = FakeContent(),
                       settings: FakeSettings = FakeSettings(),
                       audio: FakeAudio = FakeAudio(),
                       store: FakeProgressStore = FakeProgressStore()) -> DependencyContainer {
    DependencyContainer(content: content, settings: settings, audio: audio, progress: store,
                        render: FakeRender(), profiles: ProfileService(store: store, settings: settings),
                        photos: FakePhotoExporter())
}

/// In-memory `ProgressStoring` that records calls.
actor FakeProgressStore: ProgressStoring {
    private(set) var profileList = ProfileList()
    private(set) var colorings: [String: SavedColoring] = [:]
    private(set) var updated: [String: Date] = [:]
    private(set) var thumbnailsData: [String: Data] = [:]
    private(set) var fillSaves = 0
    private(set) var strokeSaves = 0
    private(set) var thumbnailSaves = 0
    private(set) var completedMarks = 0
    private(set) var deletedProfiles: [String] = []
    private(set) var prepared = 0
    var failWrites = false

    init(profiles: [Profile] = [], colorings: [String: SavedColoring] = [:]) {
        profileList = ProfileList(profiles: profiles)
        self.colorings = colorings
    }

    static func key(_ profileId: String, _ itemId: String) -> String { "\(profileId)/\(itemId)" }

    func setFailWrites(_ value: Bool) { failWrites = value }
    func coloring(_ profileId: String, _ itemId: String) -> SavedColoring? { colorings[Self.key(profileId, itemId)] }

    func prepare() async { prepared += 1 }
    func loadProfiles() async -> ProfileList { profileList }

    @discardableResult
    func saveProfiles(_ list: ProfileList) async -> Bool {
        guard !failWrites else { return false }
        profileList = list
        return true
    }

    func deleteProfileData(profileId: String) async {
        deletedProfiles.append(profileId)
        colorings = colorings.filter { !$0.key.hasPrefix(profileId + "/") }
    }

    func loadColoring(itemId: String, profileId: String) async -> SavedColoring {
        colorings[Self.key(profileId, itemId)] ?? .empty
    }

    @discardableResult
    func saveFills(_ fills: [String: String], itemId: String, profileId: String) async -> Bool {
        guard !failWrites else { return false }
        fillSaves += 1
        colorings[Self.key(profileId, itemId), default: .empty].fills = fills
        updated[Self.key(profileId, itemId)] = Date()
        return true
    }

    @discardableResult
    func saveStrokes(_ strokes: [Stroke], itemId: String, profileId: String) async -> Bool {
        guard !failWrites else { return false }
        strokeSaves += 1
        colorings[Self.key(profileId, itemId), default: .empty].strokes = strokes
        updated[Self.key(profileId, itemId)] = Date()
        return true
    }

    @discardableResult
    func saveThumbnail(_ png: Data, itemId: String, profileId: String) async -> Bool {
        guard !failWrites else { return false }
        thumbnailSaves += 1
        thumbnailsData[Self.key(profileId, itemId)] = png
        return true
    }

    @discardableResult
    func markCompleted(itemId: String, profileId: String) async -> Bool {
        guard !failWrites else { return false }
        completedMarks += 1
        colorings[Self.key(profileId, itemId), default: .empty].completedAt = Date()
        updated[Self.key(profileId, itemId)] = Date()
        return true
    }

    func summaries(profileId: String) async -> [ProgressSummary] {
        colorings.compactMap { key, saved in
            guard key.hasPrefix(profileId + "/") else { return nil }
            let itemId = String(key.dropFirst(profileId.count + 1))
            return ProgressSummary(itemId: itemId, updatedAt: updated[key] ?? .distantPast,
                                   completedAt: saved.completedAt, hasThumbnail: thumbnailsData[key] != nil)
        }
    }

    func thumbnail(itemId: String, profileId: String) async -> CGImage? {
        thumbnailsData[Self.key(profileId, itemId)] == nil ? nil : FakeRender.image
    }

    func clearArt(profileId: String) async {
        colorings = colorings.filter { !$0.key.hasPrefix(profileId + "/") }
    }

    func clearAllArt() async { colorings = [:]; thumbnailsData = [:] }

    func storageUsed() async -> Int64 { 1_234_567 }

    private(set) var backupsMade = 0
    var restoreResult: Result<RestoreSummary, BackupError> = .success(RestoreSummary(profiles: 2, drawings: 5))
    func setRestoreResult(_ result: Result<RestoreSummary, BackupError>) { restoreResult = result }

    func makeBackup() async throws -> URL {
        backupsMade += 1
        return FileManager.default.temporaryDirectory.appendingPathComponent("fake-backup.zip")
    }

    func restoreBackup(from url: URL) async throws -> RestoreSummary {
        try restoreResult.get()
    }
}

struct FakeRender: RenderServicing {
    /// A 1×1 image for anything that needs a CGImage.
    static let image: CGImage = {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }()

    func thumbnailPNG(itemId: String, fills: [String: String], strokes: [Stroke]) async -> Data? {
        Data("png:\(itemId):\(fills.count):\(strokes.count)".utf8)
    }

    func blankThumbnail(itemId: String) async -> CGImage? { Self.image }

    func exportPNG(itemId: String, fills: [String: String], strokes: [Stroke]) async -> Data? {
        itemId == "ghost" ? nil : Data("export:\(itemId)".utf8)
    }
}

/// Records saves; can pretend permission is denied or saving fails.
actor FakePhotoExporter: PhotoExporting {
    private(set) var saved: [Data] = []
    private let allowed: Bool
    private let fails: Bool

    init(allowed: Bool = true, fails: Bool = false) {
        self.allowed = allowed
        self.fails = fails
    }

    func requestAccess() async -> Bool { allowed }

    func save(pngs: [Data]) async throws {
        if fails { throw CocoaError(.fileWriteOutOfSpace) }
        saved += pngs
    }
}

/// Polls a main-actor condition (for work the code under test starts in its own Task).
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: @MainActor () async -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !(await condition()), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
}
