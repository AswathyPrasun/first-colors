import SwiftUI

/// Round palette blob. Selected = white + ink rings, suggested = white + yellow rings,
/// soft glow, star badge and a gentle pulse (static when Reduce Motion is on).
struct ColorSwatch: View {
    let paletteColor: PaletteColor
    let isSelected: Bool
    let isSuggested: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var diameter: CGFloat {
        isSelected ? DSMetrics.swatchSelectedSize : DSMetrics.swatchSize
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(paletteColor.color)
                .frame(width: diameter, height: diameter)
                .overlay(rings)
                // Soft glow sits *behind* the blob so the color itself stays flat and true.
                .background {
                    if isSuggested {
                        Circle()
                            .fill(DSColor.primaryButton.opacity(0.55))
                            .padding(-10)
                            .blur(radius: 8)
                    }
                }
                .overlay(alignment: .topTrailing) { starBadge }
                .scaleEffect(isSuggested && pulse && !reduceMotion ? 1.06 : 1)
                .frame(width: DSMetrics.swatchSelectedSize, height: DSMetrics.swatchSelectedSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
        .onAppear { startPulse() }
        .onChange(of: isSuggested) { startPulse() }
        .sensoryFeedback(.selection, trigger: isSelected) { _, selected in selected }
        .accessibilityLabel(Text(paletteColor.accessibilityName))
        .accessibilityHint(isSuggested ? Text("Suggested color") : Text(""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var rings: some View {
        if isSelected {
            Circle().strokeBorder(.white, lineWidth: 4)
                .overlay(Circle().strokeBorder(DSColor.ink, lineWidth: 4).padding(-4))
        } else if isSuggested {
            Circle().strokeBorder(.white, lineWidth: 4)
                .overlay(Circle().strokeBorder(DSColor.primaryButton, lineWidth: 4).padding(-4))
        }
    }

    @ViewBuilder private var starBadge: some View {
        if isSuggested {
            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DSColor.primaryButton)
                .padding(4)
                .background(Circle().fill(.white))
                .offset(x: 4, y: -4)
                .accessibilityHidden(true)
        }
    }

    private func startPulse() {
        guard isSuggested, !reduceMotion else { pulse = false; return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
