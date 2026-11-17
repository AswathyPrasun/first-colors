import Foundation
import Testing
@testable import KidsColoring

struct ZipArchiveTests {
    /// `note.txt` (47 bytes, deflate) made by the macOS `zip` tool.
    private let systemZip = Data(base64Encoded: "UEsDBBQAAAAIAPtocF1qdiy5CwAAAC8AAAAIAAAAbm90ZS50eHTLSM3JyVfIIJYEAFBLAQIeAxQAAAAIAPtocF1qdiy5CwAAAC8AAAAIAAAAAAAAAAEAAACkgQAAAABub3RlLnR4dFBLBQYAAAAAAQABADYAAAAxAAAAAAA=")!

    @Test func roundTrip() throws {
        let entries = [
            ZipArchive.Entry(path: "backup.json", data: Data(#"{"version":1}"#.utf8)),
            ZipArchive.Entry(path: "Profiles/p1/apple.strokes", data: Data((0..<5000).map { UInt8($0 % 251) })),
            ZipArchive.Entry(path: "Profiles/p1/ünïcode.json", data: Data()),
        ]
        #expect(try ZipArchive.read(ZipArchive.write(entries)) == entries)
    }

    @Test func readsDeflateZipsFromOtherTools() throws {
        let entries = try ZipArchive.read(systemZip)
        #expect(entries.map(\.path) == ["note.txt"])
        #expect(String(decoding: entries[0].data, as: UTF8.self) == String(repeating: "hello ", count: 7) + "hello")
    }

    @Test func crcMatchesTheStandard() {
        #expect(CRC32.checksum(Data("hello".utf8)) == 0x3610_A686)
        #expect(CRC32.checksum(Data()) == 0)
    }

    @Test func rejectsDamagedFiles() throws {
        #expect(throws: ZipError.notAZip) { try ZipArchive.read(Data("not a zip at all, sorry".utf8)) }
        #expect(throws: ZipError.notAZip) { try ZipArchive.read(Data()) }
        var flipped = try ZipArchive.write([ZipArchive.Entry(path: "a.txt", data: Data("abcdef".utf8))])
        flipped[36] ^= 0xFF   // content starts after the 30-byte header + "a.txt"; CRC must catch it
        #expect(throws: ZipError.self) { try ZipArchive.read(flipped) }
        let truncated = systemZip.prefix(systemZip.count - 30)
        #expect(throws: ZipError.self) { try ZipArchive.read(Data(truncated)) }
    }

    @Test func randomBytesNeverCrash() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<300 {
            var data = systemZip
            for _ in 0..<5 { data[Int.random(in: 0..<data.count, using: &rng)] = UInt8.random(in: 0...255, using: &rng) }
            _ = try? ZipArchive.read(data)
        }
    }
}

/// Real store → zip → real store, in throwaway folders.
struct BackupRestoreTests {
    private func makeStore() -> (ProgressStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Profiles", isDirectory: true)
        return (ProgressStore(root: root), root)
    }

    private let bear = Profile(avatar: .bear)
    private let stroke = Stroke(regionId: "leaf", color: "#43A047", width: 19.5, points: [StrokePoint(x: 1, y: 2)])

    private func seed(_ store: ProgressStore) async {
        await store.prepare()
        await store.saveProfiles(ProfileList(profiles: [bear]))
        await store.saveFills(["body": "#E53935"], itemId: "apple", profileId: bear.id)
        await store.saveStrokes([stroke], itemId: "apple", profileId: bear.id)
        await store.saveThumbnail(Data("png".utf8), itemId: "apple", profileId: bear.id)
        await store.markCompleted(itemId: "apple", profileId: bear.id)
    }

    private func writeZip(_ entries: [ZipArchive.Entry]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        try ZipArchive.write(entries).write(to: url)
        return url
    }

    private func manifest(version: Int = 1, storage: Int = 1, app: String = "KidsColoring") -> ZipArchive.Entry {
        ZipArchive.Entry(path: "backup.json",
                         data: Data(#"{"app":"\#(app)","version":\#(version),"storageVersion":\#(storage)}"#.utf8))
    }

    private func profilesEntry() throws -> ZipArchive.Entry {
        ZipArchive.Entry(path: "Profiles/profiles.json", data: try JSONEncoder().encode(ProfileList(profiles: [bear])))
    }

    @Test func backupRestoresEverythingOnAnotherDevice() async throws {
        let (source, _) = makeStore()
        await seed(source)
        let zipURL = try await source.makeBackup()
        #expect(zipURL.pathExtension == "zip")

        let (target, _) = makeStore()
        await target.saveProfiles(ProfileList(profiles: [Profile(avatar: .lion)]))   // replaced by the backup
        let summary = try await target.restoreBackup(from: zipURL)
        #expect(summary == RestoreSummary(profiles: 1, drawings: 1))
        #expect(await target.loadProfiles().profiles.map(\.id) == [bear.id])
        let art = await target.loadColoring(itemId: "apple", profileId: bear.id)
        #expect(art.fills == ["body": "#E53935"])
        #expect(art.strokes == [stroke])
        #expect(art.completedAt != nil)
        #expect(await target.summaries(profileId: bear.id).first?.hasThumbnail == true)
    }

    @Test func badFilesNeverTouchExistingData() async throws {
        let (store, _) = makeStore()
        await seed(store)
        let garbage = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        try Data("definitely not a zip".utf8).write(to: garbage)

        await #expect(throws: BackupError.notABackup) { try await store.restoreBackup(from: garbage) }
        await #expect(throws: BackupError.notABackup) {
            try await store.restoreBackup(from: writeZip([self.manifest(app: "SomethingElse"), self.profilesEntry()]))
        }
        await #expect(throws: BackupError.newerVersion) {
            try await store.restoreBackup(from: writeZip([self.manifest(version: 2), self.profilesEntry()]))
        }
        await #expect(throws: BackupError.noProfiles) {
            try await store.restoreBackup(from: writeZip([self.manifest()]))
        }
        await #expect(throws: BackupError.unsafeContent) {
            try await store.restoreBackup(from: writeZip([
                self.manifest(), self.profilesEntry(),
                ZipArchive.Entry(path: "Profiles/../../escape.json", data: Data("{}".utf8)),
            ]))
        }
        // Still exactly what was there before.
        #expect(await store.loadProfiles().profiles.map(\.id) == [bear.id])
        #expect(await store.loadColoring(itemId: "apple", profileId: bear.id).fills == ["body": "#E53935"])
    }

    @Test func unknownFilesInABackupAreSkipped() async throws {
        let (store, root) = makeStore()
        let url = try writeZip([
            manifest(), try profilesEntry(),
            ZipArchive.Entry(path: "Profiles/\(bear.id)/apple.json",
                             data: Data(##"{"version":1,"itemId":"apple","fills":{"body":"#E53935"}}"##.utf8)),
            ZipArchive.Entry(path: "Profiles/\(bear.id)/script.sh", data: Data("echo hi".utf8)),
            ZipArchive.Entry(path: "Other/readme.txt", data: Data("hi".utf8)),
        ])
        _ = try await store.restoreBackup(from: url)
        #expect(await store.loadColoring(itemId: "apple", profileId: bear.id).fills == ["body": "#E53935"])
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("\(bear.id)/script.sh").path))
    }

    @Test func clearAllArtKeepsProfiles() async {
        let (store, _) = makeStore()
        await seed(store)
        await store.clearAllArt()
        #expect(await store.summaries(profileId: bear.id).isEmpty)
        #expect(await store.loadProfiles().profiles.count == 1)
    }
}
