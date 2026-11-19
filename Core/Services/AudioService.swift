import AVFoundation
import Foundation

enum SoundEffect: String, Sendable, CaseIterable {
    case tap
    case pop
    case sparkle
    case cheer
    /// Looped while the crayon is drawing.
    case crayon
    /// Played with the cheer when a picture from that category is finished (`CategoryDetails.finishSound`).
    case vroom
    case woof
    case whoosh

    var fileName: String {
        switch self {
        case .crayon: "sfx_crayon_loop.m4a"
        default: "sfx_\(rawValue).m4a"
        }
    }
}

/// Everything the app can say or play. Mapped to bundled files by `AudioCatalog`.
enum AudioCue: Equatable, Sendable {
    case categoryName(Category)
    case itemName(itemId: String)
    case colorSentence(itemId: String)
    case effect(SoundEffect)
}

@MainActor
protocol AudioPlaying: AnyObject {
    func play(_ cue: AudioCue)
    /// Starts a looping effect (e.g. crayon scribble). Replaces any current loop.
    func startLoop(_ effect: SoundEffect)
    func stopLoop()
    func stopAll()
    /// Re-reads sound/music/language settings (called after the parent area changes them).
    func settingsDidChange()
}

/// What to play for a cue.
enum AudioSource: Equatable, Sendable {
    case file(String)
    /// Development fallback only: a voice recording is missing, so speak the text.
    case speech(text: String, language: VoiceLanguage)
    case none
}

/// Pure mapping from cues to bundled files (testable without audio hardware).
struct AudioCatalog: Sendable {
    static let musicFile = "music_loop.m4a"

    let content: any ContentProviding
    /// Returns true when a file with this name is in the bundle.
    let fileExists: @Sendable (String) -> Bool
    /// Speak missing voice lines with the system voice (debug builds only).
    let speechFallback: Bool

    func source(for cue: AudioCue, language: VoiceLanguage) -> AudioSource {
        switch cue {
        case .effect(let effect):
            return fileExists(effect.fileName) ? .file(effect.fileName) : .none
        case .categoryName(let category):
            let text = category.details.spokenName.text(for: language)
            return voice(content.categoryInfo(category)?.nameAudio?.text(for: language), text: text, language: language)
        case .itemName(let itemId):
            let item = content.item(id: itemId)
            return voice(item?.nameAudio?.text(for: language), text: item?.name.text(for: language), language: language)
        case .colorSentence(let itemId):
            let item = content.item(id: itemId)
            return voice(item?.colorSentenceAudio?.text(for: language),
                         text: item?.colorSentence?.text(for: language) ?? item?.name.text(for: language),
                         language: language)
        }
    }

    private func voice(_ file: String?, text: String?, language: VoiceLanguage) -> AudioSource {
        if let file, fileExists(file) { return .file(file) }
        if speechFallback, let text, !text.isEmpty { return .speech(text: text, language: language) }
        return .none
    }
}

/// Bundled voice lines, effects and music.
///
/// - The session is `.ambient`: it respects the Ring/Silent switch and mixes with other audio.
/// - A new voice line stops the previous one; effects can overlap.
/// - Missing files are silent in release builds (never an error).
/// - All `AVAudioPlayer` work happens on a background actor (creating and starting players on
///   the main thread can stall the UI); commands go through an ordered queue.
@MainActor
final class AudioService: AudioPlaying {
    private let settings: any SettingsStoring
    private let catalog: AudioCatalog
    private let lookup: BundleLookup
    private let synthesizer = AVSpeechSynthesizer()
    private let commands: AsyncStream<PlaybackEngine.Command>.Continuation
    private var isMusicPlaying = false

    init(settings: any SettingsStoring, content: any ContentProviding, bundle: Bundle = .main) {
        self.settings = settings
        let lookup = BundleLookup(bundle: bundle)
        self.lookup = lookup
        #if DEBUG
        let speechFallback = true
        #else
        let speechFallback = false
        #endif
        self.catalog = AudioCatalog(content: content, fileExists: { lookup.url(for: $0) != nil },
                                    speechFallback: speechFallback)
        // Development-only voice stand-in: its own session, so it never touches ours.
        synthesizer.usesApplicationAudioSession = false

        let (stream, continuation) = AsyncStream.makeStream(of: PlaybackEngine.Command.self)
        commands = continuation
        let engine = PlaybackEngine()
        Task.detached(priority: .userInitiated) {
            await engine.configureSession()
            for await command in stream { await engine.handle(command) }
        }
    }

    func play(_ cue: AudioCue) {
        guard settings.soundEnabled else { return }
        switch catalog.source(for: cue, language: settings.voiceLanguage) {
        case .file(let name):
            guard let url = lookup.url(for: name) else { return }
            if case .effect = cue {
                commands.yield(.effect(url))
            } else {
                synthesizer.stopSpeaking(at: .immediate)
                commands.yield(.voice(url))
            }
        case .speech(let text, let language):
            commands.yield(.stopVoice)
            synthesizer.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language == .ar ? "ar-SA" : "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            synthesizer.speak(utterance)
        case .none:
            break
        }
    }

    func startLoop(_ effect: SoundEffect) {
        guard settings.soundEnabled, let url = lookup.url(for: effect.fileName) else { return }
        commands.yield(.startLoop(url))
    }

    func stopLoop() {
        commands.yield(.stopLoop)
    }

    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        commands.yield(.stopAll)
        isMusicPlaying = false
    }

    func settingsDidChange() {
        if !settings.soundEnabled {
            commands.yield(.stopLoop)
            commands.yield(.stopVoice)
            synthesizer.stopSpeaking(at: .immediate)
        }
        updateMusic()
    }

    /// Starts or stops the background music to match the Music setting.
    func updateMusic() {
        if settings.musicEnabled, !isMusicPlaying, let url = lookup.url(for: AudioCatalog.musicFile) {
            commands.yield(.music(url))
            isMusicPlaying = true
        } else if !settings.musicEnabled, isMusicPlaying {
            commands.yield(.music(nil))
            isMusicPlaying = false
        }
    }
}

/// Owns every `AVAudioPlayer`, off the main thread.
actor PlaybackEngine {
    enum Command: Sendable {
        case effect(URL)
        case voice(URL)
        case stopVoice
        case startLoop(URL)
        case stopLoop
        /// `nil` stops the music.
        case music(URL?)
        case stopAll
    }

    private var effectPlayers: [URL: [AVAudioPlayer]] = [:]
    private var voicePlayer: AVAudioPlayer?
    private var loopPlayer: AVAudioPlayer?
    private var musicPlayer: AVAudioPlayer?

    func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Ambient: silent with the Ring/Silent switch, mixes with other apps, no alerts.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            Log.audio.error("Audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    func handle(_ command: Command) {
        switch command {
        case .effect(let url):
            // Reuse a finished player, or add one (up to 4) so quick taps overlap.
            var players = effectPlayers[url] ?? []
            if let idle = players.first(where: { !$0.isPlaying }) {
                idle.currentTime = 0
                idle.play()
            } else if players.count < 4, let player = makePlayer(url) {
                players.append(player)
                player.play()
            }
            effectPlayers[url] = players
        case .voice(let url):
            voicePlayer?.stop()
            voicePlayer = makePlayer(url)
            voicePlayer?.play()
        case .stopVoice:
            voicePlayer?.stop()
        case .startLoop(let url):
            loopPlayer?.stop()
            loopPlayer = makePlayer(url)
            loopPlayer?.numberOfLoops = -1
            loopPlayer?.volume = 0.6
            loopPlayer?.play()
        case .stopLoop:
            loopPlayer?.stop()
            loopPlayer = nil
        case .music(let url):
            musicPlayer?.stop()
            musicPlayer = nil
            if let url, let player = makePlayer(url) {
                player.numberOfLoops = -1
                player.volume = 0.25
                player.play()
                musicPlayer = player
            }
        case .stopAll:
            effectPlayers.values.flatMap { $0 }.forEach { $0.stop() }
            voicePlayer?.stop()
            loopPlayer?.stop()
            loopPlayer = nil
            musicPlayer?.stop()
            musicPlayer = nil
        }
    }

    private func makePlayer(_ url: URL) -> AVAudioPlayer? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            Log.audio.error("Can't play \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// Finds bundled resources by file name (Xcode copies them flat into the bundle).
struct BundleLookup: @unchecked Sendable {
    let bundle: Bundle

    func url(for fileName: String) -> URL? {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext.isEmpty ? nil : ext)
    }
}
