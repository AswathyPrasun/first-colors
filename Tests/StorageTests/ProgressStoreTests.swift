import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import KidsColoring

/// Real `ProgressStore` against a throwaway folder per test.
struct ProgressStoreTests {
    let root: URL
    let store: ProgressStore

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProgressStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = ProgressStore(root: root)
    }

    private func file(_ profileId: String, _ name: String) -> URL {
        root.appendingPathComponent(profileId).appendingPathComponent(name)
    }

    private func writeRaw(_ text: String, profile: String = "p1", name: String) throws {
        let folder = root.appendingPathComponent(profile)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: folder.appendingPathComponent(name))
    }

    private let stroke = Stroke(regionId: "body", color: "#E53935", width: 19.5,
                                points: [StrokePoint(x: 10.5, y: 20.25), StrokePoint(x: 30, y: 40)])

    // MARK: Round trips

    @Test func fillsStrokesAndCompletionRoundTrip() async throws {
        await store.prepare()
        #expect(await store.saveFills(["body": "#E53935", "leaf": "#43A047"], itemId: "apple", profileId: "p1"))
        #expect(await store.saveStrokes([stroke], itemId: "apple", profileId: "p1"))
        #expect(await store.markCompleted(itemId: "apple", profileId: "p1"))

        let loaded = await store.loadColoring(itemId: "apple", profileId: "p1")
        #expect(loaded.fills == ["body": "#E53935", "leaf": "#43A047"])
        #expect(loaded.strokes == [stroke])
        #expect(loaded.completedAt != nil)

        // The small JSON matches CLAUDE.md §8 and points at the strokes file.
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file("p1", "apple.json"))) as? [String: Any]
        #expect(json?["version"] as? Int == 1)
        #expect(json?["itemId"] as? String == "apple")
        #expect(json?["strokesFile"] as? String == "apple.strokes")
        #expect(json?["updatedAt"] is String)
    }

    @Test func profilesAreSeparate() async {
        await store.saveFills(["body": "#E53935"], itemId: "apple", profileId: "bear")
        #expect(await store.loadColoring(itemId: "apple", profileId: "bunny") == .empty)
    }

    @Test func emptyStrokeListRemovesTheStrokesFile() async {
        await store.saveStrokes([stroke], itemId: "apple", profileId: "p1")
        await store.saveStrokes([], itemId: "apple", profileId: "p1")
        #expect(!FileManager.default.fileExists(atPath: file("p1", "apple.strokes").path))
        #expect(await store.loadColoring(itemId: "apple", profileId: "p1").strokes.isEmpty)
    }

    @Test func summariesAndThumbnails() async throws {
        await store.saveFills(["body": "#E53935"], itemId: "apple", profileId: "p1")
        try await Task.sleep(for: .milliseconds(20))
        await store.saveFills(["body": "#FB8C00"], itemId: "carrot", profileId: "p1")
        await store.markCompleted(itemId: "carrot", profileId: "p1")
        let png = try #require(DrawingImageRenderer.pngData(FakeRender.image))
        await store.saveThumbnail(png, itemId: "carrot", profileId: "p1")

        let summaries = await store.summaries(profileId: "p1")
        #expect(summaries.map(\.itemId) == ["carrot", "apple"])          // newest first
        #expect(summaries.map(\.isCompleted) == [true, false])
        #expect(summaries.map(\.hasThumbnail) == [true, false])
        #expect(await store.thumbnail(itemId: "carrot", profileId: "p1") != nil)
        #expect(await store.thumbnail(itemId: "apple", profileId: "p1") == nil)
        #expect(await store.storageUsed() > 0)
    }

    @Test func clearArtAndDeleteProfile() async {
        await store.saveFills(["body": "#E53935"], itemId: "apple", profileId: "p1")
        await store.clearArt(profileId: "p1")
        #expect(await store.summaries(profileId: "p1").isEmpty)
        await store.saveFills(["body": "#E53935"], itemId: "apple", profileId: "p2")
        await store.deleteProfileData(profileId: "p2")
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("p2").path))
    }

    @Test func profilesRoundTrip() async {
        let list = ProfileList(profiles: [Profile(avatar: .bear), Profile(avatar: .lion)])
        #expect(await store.saveProfiles(list))
        let loaded = await store.loadProfiles().profiles
        #expect(loaded.map(\.id) == list.profiles.map(\.id))
        #expect(loaded.map(\.avatar) == [.bear, .lion])
        // Dates keep millisecond precision.
        #expect(abs(loaded[0].createdAt.timeIntervalSince(list.profiles[0].createdAt)) < 0.001)
    }

    // MARK: Safety

    @Test func writesAreAtomicAndLeaveNoTempFiles() async throws {
        for index in 0..<20 {
            await store.saveFills(["body": index.isMultiple(of: 2) ? "#E53935" : "#43A047"], itemId: "apple", profileId: "p1")
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("p1").path)
        #expect(files == ["apple.json"])
        // Always a complete, valid document.
        #expect(await store.loadColoring(itemId: "apple", profileId: "p1").fills == ["body": "#43A047"])
    }

    @Test func corruptProgressJSONIsSkippedThenOverwritten() async throws {
        try writeRaw("{ this is not json", name: "apple.json")
        #expect(await store.loadColoring(itemId: "apple", profileId: "p1") == .empty)
        #expect(await store.summaries(profileId: "p1").isEmpty)
        #expect(await store.saveFills(["body": "#E53935"], itemId: "apple", profileId: "p1"))
        #expect(await store.loadColoring(itemId: "apple", profileId: "p1").fills == ["body": "#E53935"])
    }

    @Test func corruptStrokesFileKeepsTheFills() async throws {
        await store.saveFills(["body": "#E53935"], itemId: "apple", profileId: "p1")
        try writeRaw("garbage", name: "apple.strokes")
        let loaded = await store.loadColoring(itemId: "apple", profileId: "p1")
        #expect(loaded.fills == ["body": "#E53935"])
        #expect(loaded.strokes.isEmpty)
    }

    @Test func garbageThumbnailIsNil() async throws {
        try writeRaw("not a png", name: "apple.thumb.png")
        #expect(await store.thumbnail(itemId: "apple", profileId: "p1") == nil)
    }

    @Test func corruptProfilesFileStartsFresh() async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("[[[".utf8).write(to: root.appendingPathComponent("profiles.json"))
        #expect(await store.loadProfiles().profiles.isEmpty)
    }

    @Test func toleratesOldAndFutureVersions() async throws {
        // v1 file from an early build: no strokesFile/completedAt, one bad color, an extra key.
        try writeRaw("""
        { "version": 1, "itemId": "apple", "updatedAt": "2026-01-01T09:00:00Z",
          "fills": { "body": "#e53935", "leaf": "green" }, "sparkles": true }
        """, name: "apple.json")
        let old = await store.loadColoring(itemId: "apple", profileId: "p1")
        #expect(old.fills == ["body": "#E53935"])

        // A file from a newer app version: unknown fields are ignored, known ones still load.
        try writeRaw("""
        { "version": 7, "itemId": "pear", "updatedAt": "2027-01-01T09:00:00Z",
          "fills": { "body": "#43A047" }, "layers": [1, 2, 3], "completedAt": "2027-01-01T09:00:00Z" }
        """, name: "pear.json")
        let future = await store.loadColoring(itemId: "pear", profileId: "p1")
        #expect(future.fills == ["body": "#43A047"])
        #expect(future.completedAt != nil)
        // Saving rewrites it at the current version without losing the fills.
        await store.saveFills(["body": "#43A047", "leaf": "#43A047"], itemId: "pear", profileId: "p1")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file("p1", "pear.json"))) as? [String: Any]
        #expect(json?["version"] as? Int == ColoringProgress.currentVersion)
    }

    @Test func mismatchedItemIdInsideFileIsIgnored() async throws {
        try writeRaw(##"{ "version": 1, "itemId": "pear", "fills": { "body": "#43A047" } }"##, name: "apple.json")
        #expect(await store.loadColoring(itemId: "apple", profileId: "p1") == .empty)
    }

    @Test func unsafeIdsNeverTouchTheDisk() async {
        #expect(await !store.saveFills(["body": "#E53935"], itemId: "../escape", profileId: "p1"))
        #expect(await !store.saveFills(["body": "#E53935"], itemId: "apple", profileId: "../../p"))
        #expect(await store.loadColoring(itemId: "../escape", profileId: "p1") == .empty)
        #expect(!FileManager.default.fileExists(atPath: root.deletingLastPathComponent().appendingPathComponent("escape.json").path))
    }

    @Test func failedWritesReturnFalseInsteadOfCrashing() async throws {
        await store.saveFills(["body": "#E53935"], itemId: "apple", profileId: "p1")
        let folder = root.appendingPathComponent("p1")
        // Read-only folder ≈ a full disk: the write is refused.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path) }
        #expect(await !store.saveFills(["body": "#43A047"], itemId: "apple", profileId: "p1"))
        #expect(await !store.saveStrokes([stroke], itemId: "apple", profileId: "p1"))
        // What was saved before is untouched.
        #expect(await store.loadColoring(itemId: "apple", profileId: "p1").fills == ["body": "#E53935"])
    }

    @Test func prepareWritesManifestAndRunsMigrationHook() async throws {
        await store.prepare()
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("manifest.json"))) as? [String: Any]
        #expect(manifest?["version"] as? Int == ProgressStore.storageVersion)
        await store.prepare()   // idempotent
        await store.migrateIfNeeded(from: 1, to: 1)
        await store.migrateIfNeeded(from: 9, to: 1)   // newer data: read tolerantly, no crash
    }

    @Test func defaultLocationIsBackedUpApplicationSupport() {
        let path = StoragePaths.defaultRoot().path
        #expect(path.contains("Application Support"))
        #expect(!path.contains("/Caches"))
        #expect(!path.contains("/tmp"))
    }
}

struct StrokeCodecTests {
    private func sample(_ count: Int) -> [Stroke] {
        (0..<count).map { index in
            Stroke(regionId: index.isMultiple(of: 2) ? "body" : "leaf-ünïcode",
                   color: KidPalette.colors[index % 8].hex, width: 19.5,
                   points: (0..<(index % 50 + 1)).map { StrokePoint(x: Float($0) * 1.5, y: Float(index) + 0.25) })
        }
    }

    @Test func roundTripIsExact() throws {
        let strokes = sample(300)
        #expect(try StrokeCodec.decodeCompressed(StrokeCodec.encodeCompressed(strokes)) == strokes)
        #expect(try StrokeCodec.decode(StrokeCodec.encode([])) == [])
    }

    @Test func compressedIsSmallerThanJSON() throws {
        let strokes = sample(300)
        let compressed = try StrokeCodec.encodeCompressed(strokes)
        let json = try JSONEncoder().encode(strokes)
        #expect(compressed.count < json.count / 3)
    }

    @Test func rejectsCorruptData() {
        let good = StrokeCodec.encode(sample(5))
        #expect(throws: StrokeCodecError.badMagic) { try StrokeCodec.decode(Data("NOPE".utf8) + good.dropFirst(4)) }
        #expect(throws: StrokeCodecError.truncated) { try StrokeCodec.decode(good.prefix(good.count - 3)) }
        #expect(throws: StrokeCodecError.decompressionFailed) { try StrokeCodec.decodeCompressed(Data("xyz".utf8)) }
        var futureVersion = good
        futureVersion[4] = 9
        #expect(throws: StrokeCodecError.unsupportedVersion(9)) { try StrokeCodec.decode(futureVersion) }
    }

    @Test func randomBytesNeverCrash() {
        var generator = SystemRandomNumberGenerator()
        let header = Data("KCS1".utf8) + Data([1, 0])
        for _ in 0..<500 {
            let length = Int.random(in: 0..<200, using: &generator)
            let noise = Data((0..<length).map { _ in UInt8.random(in: 0...255, using: &generator) })
            _ = try? StrokeCodec.decode(header + noise)
            _ = try? StrokeCodec.decodeCompressed(noise)
        }
    }
}

struct RenderServiceTests {
    @Test func thumbnailShowsFillsAndIsAValidPNG() async throws {
        let content = TestDrawings.content()
        let service = RenderService(content: content)
        let png = try #require(await service.thumbnailPNG(itemId: "squares", fills: ["leaf": "#1E88E5"], strokes: []))
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == RenderService.thumbnailSide)

        // Sample the middle of the leaf square (drawing 220,80 → 300px thumbnail 1:1).
        var pixel: [UInt8] = [0, 0, 0, 0]
        let ctx = try #require(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(image, in: CGRect(x: -220, y: -(300 - 80 - 1), width: 300, height: 300))
        #expect(abs(Int(pixel[0]) - 0x1E) < 12 && abs(Int(pixel[2]) - 0xE5) < 12)

        #expect(await service.blankThumbnail(itemId: "squares") != nil)
        #expect(await service.thumbnailPNG(itemId: "ghost", fills: [:], strokes: []) == nil)
    }
}
