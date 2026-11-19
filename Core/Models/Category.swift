import Foundation

/// A content category. Unknown raw values in content JSON make the item be skipped.
/// Raw values are stored in content and must never change. `allCases` order is the Home order.
enum Category: String, Codable, CaseIterable, Hashable, Sendable {
    case fruits
    case vegetables
    case vehicles
    case rescuePups = "rescue_pups"
    case superKids = "super_kids"
}

/// Language used for voice lines. Kids never see this; it is chosen in the parent area.
enum VoiceLanguage: String, Codable, CaseIterable, Sendable {
    case en
    case ar
}
