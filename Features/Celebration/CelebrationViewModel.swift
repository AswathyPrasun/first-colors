import Foundation

@MainActor @Observable
final class CelebrationViewModel {
    let itemId: String
    let itemName: String
    /// e.g. "Apples can be red!" — falls back to the item name.
    let message: String
    let drawing: Drawing?
    /// The child's finished picture, loaded from storage.
    private(set) var fills: [String: String] = [:]
    private(set) var strokes: [Stroke] = []
    private(set) var isLoaded = false

    @ObservationIgnored private let profileId: String
    @ObservationIgnored private let audio: any AudioPlaying
    @ObservationIgnored private let progress: any ProgressStoring
    @ObservationIgnored private let onColorMore: @MainActor () -> Void
    @ObservationIgnored private let onMyArt: @MainActor () -> Void
    @ObservationIgnored private var hasAppeared = false

    init(itemId: String,
         profileId: String,
         content: any ContentProviding,
         audio: any AudioPlaying,
         progress: any ProgressStoring,
         language: VoiceLanguage,
         onColorMore: @escaping @MainActor () -> Void,
         onMyArt: @escaping @MainActor () -> Void) {
        self.itemId = itemId
        self.profileId = profileId
        let item = content.item(id: itemId)
        self.itemName = item?.name.text(for: language) ?? ""
        self.message = item?.colorSentence?.text(for: language) ?? itemName
        self.drawing = content.drawing(for: itemId)
        self.audio = audio
        self.progress = progress
        self.onColorMore = onColorMore
        self.onMyArt = onMyArt
    }

    /// Plays the cheer and voice line once, even if the view re-appears.
    func appear() {
        guard !hasAppeared else { return }
        hasAppeared = true
        audio.play(.effect(.cheer))
        audio.play(.colorSentence(itemId: itemId))
    }

    /// Loads the picture the child just finished (it was saved before this screen opened).
    func load() async {
        guard !isLoaded else { return }
        let saved = await progress.loadColoring(itemId: itemId, profileId: profileId)
        let regionIds = Set(drawing?.regions.map(\.id) ?? [])
        fills = saved.fills.filter { regionIds.contains($0.key) }
        strokes = saved.strokes.filter { regionIds.contains($0.regionId) }
        isLoaded = true
    }

    func speak() {
        audio.play(.colorSentence(itemId: itemId))
    }

    func colorMore() {
        audio.play(.effect(.tap))
        onColorMore()
    }

    func openMyArt() {
        audio.play(.effect(.tap))
        onMyArt()
    }
}
