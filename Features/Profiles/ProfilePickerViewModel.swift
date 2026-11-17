import Foundation

/// "Who's coloring?" — first launch (pick an avatar to create the first profile)
/// or when siblings share the device (pick yours).
@MainActor @Observable
final class ProfilePickerViewModel {
    enum Choice: Identifiable, Equatable {
        case existing(Profile)
        case new(Avatar)

        var id: String {
            switch self {
            case .existing(let profile): "profile.\(profile.avatar.rawValue)"
            case .new(let avatar): "new.\(avatar.rawValue)"
            }
        }

        var avatar: Avatar {
            switch self {
            case .existing(let profile): profile.avatar
            case .new(let avatar): avatar
            }
        }
    }

    @ObservationIgnored private let profiles: any ProfileProviding
    @ObservationIgnored private let audio: any AudioPlaying
    @ObservationIgnored private let onChosen: @MainActor () -> Void
    @ObservationIgnored private let onAddProfile: @MainActor () -> Void
    @ObservationIgnored private var isBusy = false
    /// Fixed when the screen opens, so it doesn't flip to the "existing profiles" layout
    /// in the moment between creating the first profile and leaving the screen.
    let isFirstLaunch: Bool

    init(profiles: any ProfileProviding,
         audio: any AudioPlaying,
         onChosen: @escaping @MainActor () -> Void,
         onAddProfile: @escaping @MainActor () -> Void) {
        self.profiles = profiles
        self.audio = audio
        self.onChosen = onChosen
        self.onAddProfile = onAddProfile
        self.isFirstLaunch = profiles.profiles.isEmpty
    }

    var choices: [Choice] {
        isFirstLaunch ? Avatar.allCases.map(Choice.new) : profiles.profiles.map(Choice.existing)
    }

    /// Adding a sibling goes through the parent area (behind the parental gate).
    var canAddProfile: Bool { !isFirstLaunch && profiles.canAddProfile }

    func choose(_ choice: Choice) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        audio.play(.effect(.pop))
        switch choice {
        case .existing(let profile):
            profiles.activate(profileId: profile.id)
        case .new(let avatar):
            guard let profile = await profiles.add(avatar) else { return }
            profiles.activate(profileId: profile.id)
        }
        onChosen()
    }

    func addProfile() {
        audio.play(.effect(.tap))
        onAddProfile()
    }
}
