import SwiftUI

/// Round avatar used on Home and the profile picker.
struct AvatarButton: View {
    let avatar: Avatar
    var size: CGFloat = 120
    var isNew = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(avatar.symbol)
                .font(.system(size: size * 0.55))
                .frame(width: size, height: size)
                .overlay(alignment: .bottomTrailing) {
                    if isNew {
                        Image(systemName: "plus")
                            .font(.system(size: size * 0.14, weight: .heavy))
                            .foregroundStyle(DSColor.ink)
                            .frame(width: size * 0.3, height: size * 0.3)
                            .background(Circle().fill(DSColor.primaryButton))
                            .accessibilityHidden(true)
                    }
                }
        }
        .buttonStyle(ToyButtonStyle(shape: Circle(), fill: DSColor.card, shadow: DSColor.cardShadow,
                                    depth: size > 80 ? 6 : DSMetrics.buttonShadow, pressedScale: 0.96))
        .accessibilityLabel(Text(avatar.accessibilityName))
    }
}
