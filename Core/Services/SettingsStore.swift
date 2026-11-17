import Foundation

/// App settings (parent area). Backed by `UserDefaults`, which is for settings only.
@MainActor
protocol SettingsStoring: AnyObject {
    var soundEnabled: Bool { get set }
    var musicEnabled: Bool { get set }
    var voiceLanguage: VoiceLanguage { get set }
    var activeProfileId: String? { get set }
}

@MainActor
final class UserDefaultsSettingsStore: SettingsStoring {
    private enum Key {
        static let sound = "settings.soundEnabled"
        static let music = "settings.musicEnabled"
        static let language = "settings.voiceLanguage"
        static let profile = "settings.activeProfileId"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [Key.sound: true, Key.music: true])
    }

    var soundEnabled: Bool {
        get { defaults.bool(forKey: Key.sound) }
        set { defaults.set(newValue, forKey: Key.sound) }
    }

    var musicEnabled: Bool {
        get { defaults.bool(forKey: Key.music) }
        set { defaults.set(newValue, forKey: Key.music) }
    }

    var voiceLanguage: VoiceLanguage {
        // Unknown stored values fall back to English instead of failing.
        get { defaults.string(forKey: Key.language).flatMap(VoiceLanguage.init(rawValue:)) ?? .en }
        set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    var activeProfileId: String? {
        get { defaults.string(forKey: Key.profile) }
        set { defaults.set(newValue, forKey: Key.profile) }
    }
}
