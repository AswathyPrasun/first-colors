import Foundation

/// A content category. Unknown raw values in content JSON make the item be skipped.
enum Category: String, Codable, CaseIterable, Hashable, Sendable {
    case fruits
    case vegetables
}

/// Language used for voice lines. Kids never see this; it is chosen in the parent area.
enum VoiceLanguage: String, Codable, CaseIterable, Sendable {
    case en
    case ar
}
