import Foundation

/// Local avatar profiles (one data folder each). Shared, observable state for every screen.
@MainActor
protocol ProfileProviding: AnyObject {
    var profiles: [Profile] { get }
    var activeProfile: Profile? { get }
    /// Avatars not used by any profile yet.
    var availableAvatars: [Avatar] { get }
    var canAddProfile: Bool { get }

    func load() async
    @discardableResult func add(_ avatar: Avatar) async -> Profile?
    func changeAvatar(profileId: String, to avatar: Avatar) async
    /// Deletes the profile and all its art. The last profile can't be deleted.
    func delete(profileId: String) async
    func activate(profileId: String)
}

@MainActor @Observable
final class ProfileService: ProfileProviding {
    private(set) var profiles: [Profile] = []
    private var activeProfileId: String?

    @ObservationIgnored private let store: any ProgressStoring
    @ObservationIgnored private let settings: any SettingsStoring

    init(store: any ProgressStoring, settings: any SettingsStoring) {
        self.store = store
        self.settings = settings
    }

    var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileId } ?? profiles.first
    }

    var availableAvatars: [Avatar] {
        let used = Set(profiles.map(\.avatar))
        return Avatar.allCases.filter { !used.contains($0) }
    }

    var canAddProfile: Bool { profiles.count < Profile.maxCount && !availableAvatars.isEmpty }

    func load() async {
        profiles = await store.loadProfiles().profiles
        let saved = settings.activeProfileId
        activeProfileId = profiles.contains { $0.id == saved } ? saved : profiles.first?.id
    }

    @discardableResult
    func add(_ avatar: Avatar) async -> Profile? {
        guard canAddProfile, availableAvatars.contains(avatar) else { return nil }
        let profile = Profile(avatar: avatar)
        profiles.append(profile)
        await persist()
        if profiles.count == 1 { activate(profileId: profile.id) }
        return profile
    }

    func changeAvatar(profileId: String, to avatar: Avatar) async {
        guard availableAvatars.contains(avatar),
              let index = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        profiles[index].avatar = avatar
        await persist()
    }

    func delete(profileId: String) async {
        guard profiles.count > 1, profiles.contains(where: { $0.id == profileId }) else { return }
        profiles.removeAll { $0.id == profileId }
        await persist()
        await store.deleteProfileData(profileId: profileId)
        if activeProfileId == profileId, let first = profiles.first {
            activate(profileId: first.id)
        }
    }

    func activate(profileId: String) {
        guard profiles.contains(where: { $0.id == profileId }) else { return }
        activeProfileId = profileId
        settings.activeProfileId = profileId
    }

    private func persist() async {
        // On failure (e.g. disk full) the in-memory list still works for this session.
        await store.saveProfiles(ProfileList(profiles: profiles))
    }
}
