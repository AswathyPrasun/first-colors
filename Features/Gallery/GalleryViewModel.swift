import CoreGraphics
import Foundation

/// My Art: the active child's finished drawings, newest first.
@MainActor @Observable
final class GalleryViewModel {
    struct Entry: Identifiable, Equatable {
        let id: String   // item id
        let name: String
        let completedAt: Date
    }

    private(set) var entries: [Entry] = []
    private(set) var thumbnails: [String: CGImage] = [:]
    private(set) var isLoaded = false

    @ObservationIgnored private let profileId: String
    @ObservationIgnored private let content: any ContentProviding
    @ObservationIgnored private let progress: any ProgressStoring
    @ObservationIgnored private let onOpen: @MainActor (String) -> Void
    @ObservationIgnored private let onBack: @MainActor () -> Void

    init(profileId: String,
         content: any ContentProviding,
         progress: any ProgressStoring,
         onOpen: @escaping @MainActor (String) -> Void,
         onBack: @escaping @MainActor () -> Void) {
        self.profileId = profileId
        self.content = content
        self.progress = progress
        self.onOpen = onOpen
        self.onBack = onBack
    }

    var isEmpty: Bool { isLoaded && entries.isEmpty }

    /// Saved art for items that are no longer in the app (removed content) is skipped.
    func load() async {
        let summaries = await progress.summaries(profileId: profileId)
        entries = summaries.compactMap { summary in
            guard let completedAt = summary.completedAt, let item = content.item(id: summary.itemId) else { return nil }
            return Entry(id: item.id, name: item.name.en, completedAt: completedAt)
        }
        .sorted { $0.completedAt > $1.completedAt }
        thumbnails = thumbnails.filter { key, _ in entries.contains { $0.id == key } }
        isLoaded = true
    }

    /// Called per cell as it scrolls into view; decoding happens in the store, off the main thread.
    func loadThumbnail(for itemId: String) async {
        guard thumbnails[itemId] == nil,
              let image = await progress.thumbnail(itemId: itemId, profileId: profileId) else { return }
        thumbnails[itemId] = image
    }

    func open(_ itemId: String) {
        onOpen(itemId)
    }

    func back() {
        onBack()
    }
}
