import SwiftUI

extension Color {
    /// Creates a color from a 24-bit RGB literal, e.g. `Color(hex: 0x1E2A3A)`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Parses a `#RRGGBB` string from content or saved data.
    /// Returns `nil` for anything malformed so bad data never crashes the app.
    init?(hexString: String) {
        guard let value = HexColor.parse(hexString) else { return nil }
        self.init(hex: value)
    }
}

enum HexColor {
    /// Parses `#RRGGBB` or `RRGGBB` (case-insensitive) into a 24-bit value.
    static func parse(_ string: String) -> UInt32? {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, text.allSatisfy(\.isHexDigit) else { return nil }
        return UInt32(text, radix: 16)
    }

    /// Normalises a hex string to upper-case `#RRGGBB`, or `nil` if invalid.
    static func normalized(_ string: String) -> String? {
        guard let value = parse(string) else { return nil }
        return String(format: "#%06X", value)
    }
}

/// Design-system color tokens. Values match the sample UI spec.
enum DSColor {
    static let ink = Color(hex: 0x1E2A3A)
    static let outline = Color(hex: 0x1F1F1F)
    static let bgHome = Color(hex: 0xF1F7FF)
    static let bgColoring = Color(hex: 0xF1F7FF)
    static let bgCelebration = Color(hex: 0xEAF5FF)
    static let bgFruits = Color(hex: 0xFFF1EE)
    static let tileFruits = Color(hex: 0xFFE1DC)
    static let tileFruitsShadow = Color(hex: 0xF4B8AE)
    static let tileVeggies = Color(hex: 0xDDF3D3)
    static let tileVeggiesShadow = Color(hex: 0xAEDB9C)
    static let tileVehicles = Color(hex: 0xDCEFFC)
    static let tileVehiclesShadow = Color(hex: 0xA9D3F2)
    static let bgVehicles = Color(hex: 0xEEF7FD)
    static let tilePups = Color(hex: 0xFFF0C7)
    static let tilePupsShadow = Color(hex: 0xEFCF78)
    static let bgPups = Color(hex: 0xFFF9EA)
    static let tileSuper = Color(hex: 0xECE2FF)
    static let tileSuperShadow = Color(hex: 0xC7B2F0)
    static let bgSuper = Color(hex: 0xF6F1FF)
    static let tileMyArt = Color(hex: 0xE7E4FF)
    static let tileMyArtIcon = Color(hex: 0x5E35B1)
    static let card = Color.white
    static let cardShadow = Color(hex: 0xD5E2F2)
    static let primaryButton = Color(hex: 0xFFC233)
    static let primaryButtonShadow = Color(hex: 0xE0A100)
    static let success = Color(hex: 0x2E7D32)
    static let parentBg = Color(hex: 0xF5F6F8)
    /// Section headers/footers in the parent area (≥ 4.5:1 on `parentBg`).
    static let parentSecondary = Color(hex: 0x4A5565)
    /// Links and buttons in the parent area (≥ 4.5:1 on white).
    static let parentAccent = Color(hex: 0x1565C0)
    /// Destructive actions in the parent area (≥ 4.5:1 on white; system red is ~3.6:1).
    static let parentDestructive = Color(hex: 0xC62828)
    static let gateProgress = Color(hex: 0x1E88E5)
}

/// One color in the kid palette.
struct PaletteColor: Identifiable, Hashable, Sendable {
    /// Upper-case `#RRGGBB`; also the value stored in saved progress.
    let hex: String
    /// Spoken by VoiceOver; never shown as text to kids.
    let accessibilityName: String

    var id: String { hex }
    var color: Color { Color(hexString: hex) ?? .gray }
}

/// Kid palettes: no free color picker, at most 8 colors on screen (CLAUDE.md §2.5).
/// Every category shows 8 colors chosen from the base set (see `CategoryDetails.palette`).
enum KidPalette {
    static let red = PaletteColor(hex: "#E53935", accessibilityName: "Red")
    static let orange = PaletteColor(hex: "#FB8C00", accessibilityName: "Orange")
    static let yellow = PaletteColor(hex: "#FDD835", accessibilityName: "Yellow")
    static let green = PaletteColor(hex: "#43A047", accessibilityName: "Green")
    static let blue = PaletteColor(hex: "#1E88E5", accessibilityName: "Blue")
    /// Windows, sky and water. Added for vehicles.
    static let sky = PaletteColor(hex: "#81D4FA", accessibilityName: "Light blue")
    static let purple = PaletteColor(hex: "#8E24AA", accessibilityName: "Purple")
    static let pink = PaletteColor(hex: "#F06292", accessibilityName: "Pink")
    /// Tires and metal. No pure black: black fills would hide the black outlines.
    static let gray = PaletteColor(hex: "#78909C", accessibilityName: "Gray")
    static let brown = PaletteColor(hex: "#6D4C41", accessibilityName: "Brown")

    /// Every color any category may offer (and any saved art may contain), in swatch order.
    static let base: [PaletteColor] = [red, orange, yellow, green, blue, sky, purple, pink, gray, brown]

    /// The original 1.0 palette (Fruits and Vegetables).
    static let colors: [PaletteColor] = [red, orange, yellow, green, blue, purple, pink, brown]

    static var defaultColor: PaletteColor { red }

    static func color(forHex hex: String) -> PaletteColor? {
        guard let normalized = HexColor.normalized(hex) else { return nil }
        return base.first { $0.hex == normalized }
    }
}
