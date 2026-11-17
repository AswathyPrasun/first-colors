import Foundation

/// Avatar-only profiles: no names, photos or personal data (CLAUDE.md §2, §8).
enum Avatar: String, Codable, CaseIterable, Sendable {
    case bear, bunny, cat, lion

    /// Drawn by the system emoji font, bundled with iOS (no download, no photo).
    var symbol: String {
        switch self {
        case .bear: "🐻"
        case .bunny: "🐰"
        case .cat: "🐱"
        case .lion: "🦁"
        }
    }

    /// For VoiceOver only.
    var accessibilityName: String {
        switch self {
        case .bear: "Bear"
        case .bunny: "Bunny"
        case .cat: "Cat"
        case .lion: "Lion"
        }
    }
}

struct Profile: Codable, Identifiable, Hashable, Sendable {
    /// One profile per avatar keeps siblings' choices obvious without reading.
    static let maxCount = Avatar.allCases.count

    let id: String
    var avatar: Avatar
    let createdAt: Date

    init(id: String = UUID().uuidString, avatar: Avatar, createdAt: Date = Date()) {
        self.id = id
        self.avatar = avatar
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey { case id, avatar, createdAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        // An avatar from a newer version falls back to the bear instead of losing the profile.
        avatar = (try? c.decode(Avatar.self, forKey: .avatar)) ?? .bear
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? .distantPast
    }
}

/// `Profiles/profiles.json`.
struct ProfileList: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var profiles: [Profile]

    init(profiles: [Profile] = []) {
        version = Self.currentVersion
        self.profiles = profiles
    }

    private enum CodingKeys: String, CodingKey { case version, profiles }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        let decoded = (try? c.decode(LossyArray<Profile>.self, forKey: .profiles).elements) ?? []
        var seen = Set<String>()
        profiles = decoded.filter { StoragePaths.isSafeComponent($0.id) && seen.insert($0.id).inserted }
    }
}
