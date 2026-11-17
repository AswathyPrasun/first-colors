import Foundation
import Testing
@testable import KidsColoring

@MainActor
struct SettingsStoreTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "KidsColoringTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsAreSoundOnMusicOnEnglish() {
        let store = UserDefaultsSettingsStore(defaults: freshDefaults())
        #expect(store.soundEnabled)
        #expect(store.musicEnabled)
        #expect(store.voiceLanguage == .en)
        #expect(store.activeProfileId == nil)
    }

    @Test func roundTrips() {
        let defaults = freshDefaults()
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.soundEnabled = false
        store.voiceLanguage = .ar
        store.activeProfileId = "bear"

        let reloaded = UserDefaultsSettingsStore(defaults: defaults)
        #expect(reloaded.soundEnabled == false)
        #expect(reloaded.voiceLanguage == .ar)
        #expect(reloaded.activeProfileId == "bear")
    }

    @Test func unknownLanguageFallsBackToEnglish() {
        let defaults = freshDefaults()
        defaults.set("klingon", forKey: "settings.voiceLanguage")
        #expect(UserDefaultsSettingsStore(defaults: defaults).voiceLanguage == .en)
    }
}
