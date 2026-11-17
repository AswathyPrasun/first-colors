import SwiftUI

/// 60pt white circle with an icon. The accessibility label is mandatory.
struct RoundIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var tint: Color = DSColor.ink
    var size: CGFloat = DSMetrics.roundIconSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
        .buttonStyle(ToyButtonStyle(shape: Circle(), fill: DSColor.card, shadow: DSColor.cardShadow))
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// Plays the voice line for the current item or category.
struct SpeakerButton: View {
    var accessibilityLabel: LocalizedStringKey = "Say it"
    let action: () -> Void

    var body: some View {
        RoundIconButton(systemImage: "speaker.wave.2.fill",
                        accessibilityLabel: accessibilityLabel,
                        action: action)
    }
}

/// Custom back button (the system navigation bar is hidden on kid screens).
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        RoundIconButton(systemImage: "chevron.backward", accessibilityLabel: "Back", action: action)
            .accessibilityIdentifier("back")
    }
}

/// Square tool button for the coloring toolbar. Active state uses the primary yellow.
struct ToolButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var isActive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DSColor.ink)
                .frame(width: DSMetrics.toolSize, height: DSMetrics.toolSize)
        }
        .buttonStyle(ToyButtonStyle(
            shape: RoundedRectangle(cornerRadius: DSMetrics.toolRadius, style: .continuous),
            fill: isActive ? DSColor.primaryButton : DSColor.card,
            shadow: isActive ? DSColor.primaryButtonShadow : DSColor.cardShadow))
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Big yellow call-to-action (e.g. "Done").
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .font(.kid(.heading))
            .padding(.horizontal, 12)
            .foregroundStyle(DSColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: DSMetrics.primaryButtonHeight)
        }
        .buttonStyle(ToyButtonStyle(
            shape: RoundedRectangle(cornerRadius: DSMetrics.primaryRadius, style: .continuous),
            fill: DSColor.primaryButton,
            shadow: DSColor.primaryButtonShadow,
            depth: 5))
    }
}

/// Large colored tile (Home categories, My Art). Scales to 0.96 and gives a haptic on press.
struct BigTile<Content: View>: View {
    let fill: Color
    let shadow: Color
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(ToyButtonStyle(
            shape: RoundedRectangle(cornerRadius: DSMetrics.tileRadius, style: .continuous),
            fill: fill,
            shadow: shadow,
            depth: DSMetrics.tileShadow,
            pressedScale: 0.96))
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
