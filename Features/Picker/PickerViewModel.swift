import CoreGraphics
import Foundation

@MainActor @Observable
final class PickerViewModel {
    struct Tile: Identifiable, Equatable {
        let id: String
        let name: String
        var isCompleted: Bool
        /// The child's saved coloring, if any (decides which thumbnail to load).
        var hasSavedArt: Bool
    }

    let category: Category
    private(set) var tiles: [Tile] = []
    /// Decoded thumbnails, filled in lazily as tiles appear.
    private(set) var thumbnails: [String: CGImage] = [:]

    @ObservationIgnored private let profileId: String
    @ObservationIgnored private let audio: any AudioPlaying
    @ObservationIgnored private let progress: any ProgressStoring
    @ObservationIgnored private let render: any RenderServicing
    @ObservationIgnored private let onSelect: @MainActor (String) -> Void
    @ObservationIgnored private let onBack: @MainActor () -> Void
    @ObservationIgnored private var loadedThumbnailState: [String: Bool] = [:]

    init(category: Category,
         profileId: String,
         content: any ContentProviding,
         audio: any AudioPlaying,
         progress: any ProgressStoring,
         render: any RenderServicing,
         language: VoiceLanguage,
         onSelect: @escaping @MainActor (String) -> Void,
         onBack: @escaping @MainActor () -> Void) {
        self.category = category
        self.profileId = profileId
        self.audio = audio
        self.progress = progress
        self.render = render
        self.onSelect = onSelect
        self.onBack = onBack
        tiles = content.items(in: category).map {
            Tile(id: $0.id, name: $0.name.text(for: language), isCompleted: false, hasSavedArt: false)
        }
    }

    /// Refreshes check badges and which tiles show the child's version. Called on appear,
    /// so coming back from Coloring shows the latest art.
    func refresh() async {
        let summaries = Dictionary(uniqueKeysWithValues:
            await progress.summaries(profileId: profileId).map { ($0.itemId, $0) })
        for index in tiles.indices {
            let summary = summaries[tiles[index].id]
            tiles[index].isCompleted = summary?.isCompleted ?? false
            let hasArt = summary?.hasThumbnail ?? false
            if tiles[index].hasSavedArt != hasArt || hasArt {
                // Saved art may have changed since last time: reload its thumbnail.
                loadedThumbnailState[tiles[index].id] = nil
            }
            tiles[index].hasSavedArt = hasArt
        }
        for tile in tiles where loadedThumbnailState[tile.id] == nil && thumbnails[tile.id] != nil {
            await loadThumbnail(for: tile.id)
        }
    }

    /// The child's saved art if there is some, otherwise the blank outline.
    func loadThumbnail(for itemId: String) async {
        guard let tile = tiles.first(where: { $0.id == itemId }),
              loadedThumbnailState[itemId] != tile.hasSavedArt else { return }
        loadedThumbnailState[itemId] = tile.hasSavedArt
        let image: CGImage?
        if tile.hasSavedArt, let saved = await progress.thumbnail(itemId: itemId, profileId: profileId) {
            image = saved
        } else {
            image = await render.blankThumbnail(itemId: itemId)
        }
        if let image { thumbnails[itemId] = image }
    }

    func select(_ itemId: String) {
        audio.play(.itemName(itemId: itemId))
        onSelect(itemId)
    }

    func speakCategory() {
        audio.play(.categoryName(category))
    }

    func back() {
        onBack()
    }
}
