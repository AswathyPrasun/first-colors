import CoreGraphics
import Foundation
import ImageIO

/// All on-disk user data. Views and ViewModels never touch the file system (CLAUDE.md §10).
/// Every method is safe to call with bad or missing data: reads fall back to empty, writes
/// report failure (e.g. a full disk) by returning `false` instead of throwing.
protocol ProgressStoring: Sendable {
    /// Runs once at launch: creates folders and applies `migrateIfNeeded`.
    func prepare() async

    func loadProfiles() async -> ProfileList
    @discardableResult func saveProfiles(_ list: ProfileList) async -> Bool
    func deleteProfileData(profileId: String) async

    func loadColoring(itemId: String, profileId: String) async -> SavedColoring
    @discardableResult func saveFills(_ fills: [String: String], itemId: String, profileId: String) async -> Bool
    @discardableResult func saveStrokes(_ strokes: [Stroke], itemId: String, profileId: String) async -> Bool
    @discardableResult func saveThumbnail(_ png: Data, itemId: String, profileId: String) async -> Bool
    @discardableResult func markCompleted(itemId: String, profileId: String) async -> Bool

    func summaries(profileId: String) async -> [ProgressSummary]
    /// Decoded off the main thread, ready to draw.
    func thumbnail(itemId: String, profileId: String) async -> CGImage?
    func clearArt(profileId: String) async
    /// Removes every child's art (profiles stay).
    func clearAllArt() async
    /// Bytes used by all user data.
    func storageUsed() async -> Int64

    /// Writes a `.zip` of all profiles and art for the share sheet / Files.
    func makeBackup() async throws -> URL
    /// Replaces all data with a validated backup. Existing data is untouched if anything fails.
    func restoreBackup(from url: URL) async throws -> RestoreSummary
}

struct RestoreSummary: Equatable, Sendable {
    let profiles: Int
    let drawings: Int
}

enum BackupError: Error, Equatable {
    case notABackup
    case newerVersion
    case unsafeContent
    case noProfiles
    case writeFailed
}

/// `backup.json` at the root of every backup zip.
struct BackupManifest: Codable, Equatable {
    static let appId = "KidsColoring"
    static let currentVersion = 1

    var app: String
    var version: Int
    var storageVersion: Int
}

/// File names and safety checks shared by the store and models.
enum StoragePaths {
    static let rootFolder = "Profiles"
    static let profilesFile = "profiles.json"
    static let manifestFile = "manifest.json"

    static func progressFile(_ itemId: String) -> String { "\(itemId).json" }
    static func strokesFile(_ itemId: String) -> String { "\(itemId).strokes" }
    static func thumbnailFile(_ itemId: String) -> String { "\(itemId).thumb.png" }

    /// Ids become file and folder names, so only allow a safe character set.
    static func isSafeComponent(_ text: String) -> Bool {
        !text.isEmpty && text.count <= 64 && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

    /// `Application Support/Profiles` — backed up with the device, never Caches or tmp.
    static func defaultRoot() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(rootFolder, isDirectory: true)
    }
}

actor ProgressStore: ProgressStoring {
    static let storageVersion = 1
    private static let preciseDate = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private struct Manifest: Codable { var version: Int }

    private let root: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(root: URL = StoragePaths.defaultRoot()) {
        self.root = root
        let encoder = JSONEncoder()
        // ISO 8601 with milliseconds, so "newest first" never ties within a second.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(Self.preciseDate))
        }
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        // Accept both precise and whole-second dates (older files).
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Self.preciseDate.parse(text) { return date }
            return try Date.ISO8601FormatStyle().parse(text)
        }
        self.decoder = decoder
    }

    // MARK: - Launch and migration

    func prepare() async {
        ensureDirectory(root)
        let url = root.appendingPathComponent(StoragePaths.manifestFile)
        let stored = (try? Data(contentsOf: url)).flatMap { try? decoder.decode(Manifest.self, from: $0) }?.version
        // No manifest yet means either a fresh install or data from before manifests existed (v1).
        let from = stored ?? 1
        if from != Self.storageVersion {
            migrateIfNeeded(from: from, to: Self.storageVersion)
        }
        if stored != Self.storageVersion {
            write(try? encoder.encode(Manifest(version: Self.storageVersion)), to: url)
        }
    }

    /// Upgrades on-disk data between storage versions. v1 is the first version: nothing to do.
    /// Future versions add steps here (e.g. `if from < 2 { … }`) and must keep every older
    /// version readable so updates never lose art (CLAUDE.md §8).
    func migrateIfNeeded(from: Int, to: Int) {
        guard from < to else {
            if from > to { Log.storage.notice("Data from newer version \(from); reading tolerantly") }
            return
        }
        Log.storage.info("Migrating storage \(from) → \(to)")
    }

    // MARK: - Profiles

    func loadProfiles() async -> ProfileList {
        let url = root.appendingPathComponent(StoragePaths.profilesFile)
        guard let data = try? Data(contentsOf: url) else { return ProfileList() }
        do {
            return try decoder.decode(ProfileList.self, from: data)
        } catch {
            Log.storage.error("Corrupt profiles.json, starting fresh: \(error.localizedDescription, privacy: .public)")
            return ProfileList()
        }
    }

    @discardableResult
    func saveProfiles(_ list: ProfileList) async -> Bool {
        ensureDirectory(root)
        return write(try? encoder.encode(list), to: root.appendingPathComponent(StoragePaths.profilesFile))
    }

    func deleteProfileData(profileId: String) async {
        guard let folder = profileFolder(profileId, create: false) else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - Coloring

    func loadColoring(itemId: String, profileId: String) async -> SavedColoring {
        guard let folder = profileFolder(profileId, create: false), StoragePaths.isSafeComponent(itemId) else {
            return .empty
        }
        var result = SavedColoring()
        if let progress = readProgress(itemId: itemId, in: folder) {
            result.fills = progress.fills
            result.completedAt = progress.completedAt
        }
        let strokesURL = folder.appendingPathComponent(StoragePaths.strokesFile(itemId))
        if let data = try? Data(contentsOf: strokesURL) {
            do {
                result.strokes = try StrokeCodec.decodeCompressed(data)
            } catch {
                Log.storage.error("Corrupt strokes for \(itemId, privacy: .public); ignoring: \(String(describing: error), privacy: .public)")
            }
        }
        return result
    }

    @discardableResult
    func saveFills(_ fills: [String: String], itemId: String, profileId: String) async -> Bool {
        guard let folder = profileFolder(profileId, create: true), StoragePaths.isSafeComponent(itemId) else { return false }
        var progress = readProgress(itemId: itemId, in: folder) ?? ColoringProgress(itemId: itemId)
        progress.version = ColoringProgress.currentVersion
        progress.fills = fills
        progress.updatedAt = Date()
        return writeProgress(progress, in: folder)
    }

    @discardableResult
    func saveStrokes(_ strokes: [Stroke], itemId: String, profileId: String) async -> Bool {
        guard let folder = profileFolder(profileId, create: true), StoragePaths.isSafeComponent(itemId) else { return false }
        let url = folder.appendingPathComponent(StoragePaths.strokesFile(itemId))
        let saved: Bool
        if strokes.isEmpty {
            try? FileManager.default.removeItem(at: url)
            saved = true
        } else {
            saved = write(try? StrokeCodec.encodeCompressed(strokes), to: url)
        }
        // Keep the small JSON pointing at the strokes file and its timestamp fresh.
        var progress = readProgress(itemId: itemId, in: folder) ?? ColoringProgress(itemId: itemId)
        progress.strokesFile = strokes.isEmpty ? nil : StoragePaths.strokesFile(itemId)
        progress.updatedAt = Date()
        return writeProgress(progress, in: folder) && saved
    }

    @discardableResult
    func saveThumbnail(_ png: Data, itemId: String, profileId: String) async -> Bool {
        guard let folder = profileFolder(profileId, create: true), StoragePaths.isSafeComponent(itemId) else { return false }
        return write(png, to: folder.appendingPathComponent(StoragePaths.thumbnailFile(itemId)))
    }

    @discardableResult
    func markCompleted(itemId: String, profileId: String) async -> Bool {
        guard let folder = profileFolder(profileId, create: true), StoragePaths.isSafeComponent(itemId) else { return false }
        var progress = readProgress(itemId: itemId, in: folder) ?? ColoringProgress(itemId: itemId)
        let now = Date()
        progress.completedAt = now
        progress.updatedAt = now
        return writeProgress(progress, in: folder)
    }

    // MARK: - Listing

    func summaries(profileId: String) async -> [ProgressSummary] {
        guard let folder = profileFolder(profileId, create: false),
              let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        let names = Set(files)
        return files.compactMap { name -> ProgressSummary? in
            guard name.hasSuffix(".json") else { return nil }
            let itemId = String(name.dropLast(5))
            guard StoragePaths.isSafeComponent(itemId),
                  let progress = readProgress(itemId: itemId, in: folder) else { return nil }
            return ProgressSummary(itemId: itemId, updatedAt: progress.updatedAt,
                                   completedAt: progress.completedAt,
                                   hasThumbnail: names.contains(StoragePaths.thumbnailFile(itemId)))
        }
        .sorted { $0.updatedAt == $1.updatedAt ? $0.itemId < $1.itemId : $0.updatedAt > $1.updatedAt }
    }

    func thumbnail(itemId: String, profileId: String) async -> CGImage? {
        guard let folder = profileFolder(profileId, create: false), StoragePaths.isSafeComponent(itemId) else { return nil }
        let url = folder.appendingPathComponent(StoragePaths.thumbnailFile(itemId))
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        // Decode now, here, so the main thread only has to draw it.
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }

    func clearArt(profileId: String) async {
        guard let folder = profileFolder(profileId, create: false),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return }
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    func clearAllArt() async {
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for folder in folders where (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            await clearArt(profileId: folder.lastPathComponent)
        }
    }

    // MARK: - Backup and restore

    func makeBackup() async throws -> URL {
        var entries: [ZipArchive.Entry] = []
        let manifest = BackupManifest(app: BackupManifest.appId, version: BackupManifest.currentVersion,
                                      storageVersion: Self.storageVersion)
        entries.append(ZipArchive.Entry(path: "backup.json", data: try encoder.encode(manifest)))
        for (relative, url) in Self.files(under: root) {
            guard let data = try? Data(contentsOf: url) else { continue }
            entries.append(ZipArchive.Entry(path: "\(StoragePaths.rootFolder)/\(relative)", data: data))
        }
        let zip = try ZipArchive.write(entries)
        // A temporary copy just for the share sheet; the real data stays in Application Support.
        let day = Date().formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("First Colors Backup \(day).zip")
        try? FileManager.default.removeItem(at: url)
        do {
            try zip.write(to: url, options: [.atomic])
        } catch {
            throw BackupError.writeFailed
        }
        return url
    }

    func restoreBackup(from url: URL) async throws -> RestoreSummary {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= ZipArchive.maxTotalBytes, let data = try? Data(contentsOf: url) else { throw BackupError.notABackup }
        let entries: [ZipArchive.Entry]
        do {
            entries = try ZipArchive.read(data)
        } catch {
            throw BackupError.notABackup
        }
        let files = try Self.validatedBackupFiles(entries, decoder: decoder)

        // Write everything to a staging folder first, then swap it in.
        let parent = root.deletingLastPathComponent()
        let staging = parent.appendingPathComponent("ProfilesRestore-\(UUID().uuidString)", isDirectory: true)
        do {
            for (relative, content) in files {
                let target = staging.appendingPathComponent(relative)
                ensureDirectory(target.deletingLastPathComponent())
                try content.write(to: target, options: [.atomic])
            }
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw BackupError.writeFailed
        }

        let old = parent.appendingPathComponent("ProfilesOld-\(UUID().uuidString)", isDirectory: true)
        let hadData = FileManager.default.fileExists(atPath: root.path)
        do {
            if hadData { try FileManager.default.moveItem(at: root, to: old) }
            try FileManager.default.moveItem(at: staging, to: root)
        } catch {
            // Put the original back exactly as it was.
            if hadData, !FileManager.default.fileExists(atPath: root.path) {
                try? FileManager.default.moveItem(at: old, to: root)
            }
            try? FileManager.default.removeItem(at: staging)
            throw BackupError.writeFailed
        }
        try? FileManager.default.removeItem(at: old)
        await prepare()

        let profiles = await loadProfiles().profiles.count
        let drawings = files.keys.filter { $0.split(separator: "/").count == 2 && $0.hasSuffix(".json") }.count
        return RestoreSummary(profiles: profiles, drawings: drawings)
    }

    /// Checks a backup and returns the files to restore (paths relative to the data folder).
    /// Anything trying to escape the folder rejects the whole backup; unknown files are skipped.
    static func validatedBackupFiles(_ entries: [ZipArchive.Entry], decoder: JSONDecoder) throws -> [String: Data] {
        guard let manifestData = entries.first(where: { $0.path == "backup.json" })?.data,
              let manifest = try? decoder.decode(BackupManifest.self, from: manifestData),
              manifest.app == BackupManifest.appId else { throw BackupError.notABackup }
        guard manifest.version <= BackupManifest.currentVersion,
              manifest.storageVersion <= storageVersion else { throw BackupError.newerVersion }

        var files: [String: Data] = [:]
        for entry in entries where entry.path != "backup.json" {
            let parts = entry.path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            if entry.path.hasPrefix("/") || entry.path.contains("\\")
                || parts.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) {
                throw BackupError.unsafeContent
            }
            guard parts.first == StoragePaths.rootFolder else { continue }
            let inner = Array(parts.dropFirst())
            if inner == [StoragePaths.profilesFile] || inner == [StoragePaths.manifestFile] {
                files[inner.joined(separator: "/")] = entry.data
            } else if inner.count == 2, StoragePaths.isSafeComponent(inner[0]), isArtFile(inner[1]) {
                files[inner.joined(separator: "/")] = entry.data
            }
        }
        guard let profilesData = files[StoragePaths.profilesFile],
              let list = try? decoder.decode(ProfileList.self, from: profilesData),
              !list.profiles.isEmpty else { throw BackupError.noProfiles }
        return files
    }

    private static func isArtFile(_ name: String) -> Bool {
        for suffix in [".thumb.png", ".strokes", ".json"] where name.hasSuffix(suffix) {
            return StoragePaths.isSafeComponent(String(name.dropLast(suffix.count)))
        }
        return false
    }

    /// Every regular file under `root`, with its path relative to `root`.
    private static func files(under root: URL) -> [(String, URL)] {
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        let base = root.standardizedFileURL.path
        var result: [(String, URL)] = []
        for case let url as URL in enumerator
        where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(base + "/") else { continue }
            result.append((String(path.dropFirst(base.count + 1)), url))
        }
        return result.sorted { $0.0 < $1.0 }
    }

    func storageUsed() async -> Int64 {
        Self.folderSize(root)
    }

    private static func folderSize(_ root: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        }
        return total
    }

    // MARK: - Private

    private func profileFolder(_ profileId: String, create: Bool) -> URL? {
        guard StoragePaths.isSafeComponent(profileId) else { return nil }
        let folder = root.appendingPathComponent(profileId, isDirectory: true)
        if create { ensureDirectory(folder) }
        return folder
    }

    private func readProgress(itemId: String, in folder: URL) -> ColoringProgress? {
        let url = folder.appendingPathComponent(StoragePaths.progressFile(itemId))
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let progress = try decoder.decode(ColoringProgress.self, from: data)
            return progress.itemId == itemId ? progress : nil
        } catch {
            // Skip and let the next save overwrite it; never crash on bad data.
            Log.storage.error("Corrupt progress for \(itemId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func writeProgress(_ progress: ColoringProgress, in folder: URL) -> Bool {
        write(try? encoder.encode(progress), to: folder.appendingPathComponent(StoragePaths.progressFile(progress.itemId)))
    }

    /// Atomic write (temp file + rename), so a crash or battery death never leaves half a file.
    @discardableResult
    private func write(_ data: Data?, to url: URL) -> Bool {
        guard let data else { return false }
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            // Most likely a full disk. The child keeps coloring; we simply try again next save.
            Log.storage.error("Save failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
