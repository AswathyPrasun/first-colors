import CoreGraphics
import Foundation

@MainActor @Observable
final class HomeViewModel {
    let categories: [Category] = Category.allCases
    /// Up to three of the active child's latest finished pictures.
    private(set) var latestArt: [CGImage] = []

    @ObservationIgnored private let audio: any AudioPlaying
    @ObservationIgnored private let profiles: any ProfileProviding
    @ObservationIgnored private let content: any ContentProviding
    @ObservationIgnored private let progress: any ProgressStoring
    @ObservationIgnored private let onSwitchProfile: @MainActor () -> Void
    @ObservationIgnored private let onSelectCategory: @MainActor (Category) -> Void
    @ObservationIgnored private let onOpenGallery: @MainActor () -> Void
    @ObservationIgnored private let onOpenParentArea: @MainActor () -> Void

    init(audio: any AudioPlaying,
         profiles: any ProfileProviding,
         content: any ContentProviding,
         progress: any ProgressStoring,
         onSelectCategory: @escaping @MainActor (Category) -> Void,
         onOpenGallery: @escaping @MainActor () -> Void,
         onOpenParentArea: @escaping @MainActor () -> Void,
         onSwitchProfile: @escaping @MainActor () -> Void) {
        self.audio = audio
        self.profiles = profiles
        self.content = content
        self.progress = progress
        self.onSwitchProfile = onSwitchProfile
        self.onSelectCategory = onSelectCategory
        self.onOpenGallery = onOpenGallery
        self.onOpenParentArea = onOpenParentArea
    }

    /// The active child's avatar (observed, so it updates after switching profiles).
    var avatar: Avatar { profiles.activeProfile?.avatar ?? .bear }

    /// Identifies the active child, so the view reloads My Art after a switch.
    var profileId: String { profiles.activeProfile?.id ?? "" }

    /// The tile picture: a category's signature drawing, colored with its suggested colors.
    func illustration(for category: Category) -> (drawing: Drawing, fills: [String: String])? {
        let itemId = category == .fruits ? "apple" : "carrot"
        guard let drawing = content.drawing(for: itemId) else { return nil }
        return (drawing, FillEngine.magicFills(for: drawing, current: [:]))
    }

    func refreshLatestArt() async {
        let id = profileId
        let finished = await progress.summaries(profileId: id)
            .filter { $0.isCompleted && $0.hasThumbnail && content.item(id: $0.itemId) != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .prefix(3)
        var images: [CGImage] = []
        for summary in finished {
            if let image = await progress.thumbnail(itemId: summary.itemId, profileId: id) { images.append(image) }
        }
        latestArt = images
    }

    /// Only offered as a button when there is another profile to switch to.
    var canSwitchProfile: Bool { profiles.profiles.count > 1 }

    func switchProfile() {
        audio.play(.effect(.tap))
        onSwitchProfile()
    }

    func selectCategory(_ category: Category) {
        audio.play(.categoryName(category))
        onSelectCategory(category)
    }

    func speak(_ category: Category) {
        audio.play(.categoryName(category))
    }

    func openGallery() {
        onOpenGallery()
    }

    func openParentArea() {
        onOpenParentArea()
    }
}
