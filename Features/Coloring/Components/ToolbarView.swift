import SwiftUI

/// Fill · Crayon · Eraser · Hint · Magic. (Undo sits next to Done so six 60pt tools
/// never have to squeeze into a 343pt-wide row on small iPhones.)
struct ToolbarView: View {
    let activeTool: ColoringTool
    let isHintOn: Bool
    let onSelect: (ColoringTool) -> Void
    let onHint: () -> Void
    let onMagic: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ToolButton(systemImage: "drop.fill", accessibilityLabel: "Fill",
                       isActive: activeTool == .fill) { onSelect(.fill) }
                .accessibilityIdentifier("tool.fill")
            ToolButton(systemImage: "pencil.tip", accessibilityLabel: "Crayon",
                       isActive: activeTool == .crayon) { onSelect(.crayon) }
                .accessibilityIdentifier("tool.crayon")
            ToolButton(systemImage: "eraser.fill", accessibilityLabel: "Eraser",
                       isActive: activeTool == .eraser) { onSelect(.eraser) }
                .accessibilityIdentifier("tool.eraser")
            ToolButton(systemImage: "lightbulb.fill", accessibilityLabel: "Hint",
                       isActive: isHintOn, action: onHint)
                .accessibilityIdentifier("tool.hint")
            ToolButton(systemImage: "wand.and.stars", accessibilityLabel: "Magic", action: onMagic)
                .accessibilityIdentifier("tool.magic")
        }
    }
}

/// The 8 palette blobs in a 4×2 grid; suggested colors glow.
struct PaletteView: View {
    let colors: [PaletteColor]
    let selected: PaletteColor
    let suggested: Set<String>
    var columns = 4
    let onSelect: (PaletteColor) -> Void

    var body: some View {
        let grid = Array(repeating: GridItem(.fixed(DSMetrics.swatchSelectedSize), spacing: 12), count: columns)
        LazyVGrid(columns: grid, spacing: 6) {
            ForEach(colors) { color in
                ColorSwatch(paletteColor: color,
                            isSelected: color == selected,
                            isSuggested: suggested.contains(color.hex)) { onSelect(color) }
                    .accessibilityIdentifier("color.\(color.accessibilityName.lowercased())")
            }
        }
    }
}
