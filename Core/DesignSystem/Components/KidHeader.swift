import SwiftUI

/// Standard kid-screen header: back · title · speaker.
struct KidHeader: View {
    let title: String
    let onBack: () -> Void
    var onSpeak: (() -> Void)?

    var body: some View {
        HStack(spacing: DSMetrics.smallSpacing) {
            BackButton(action: onBack)
            Text(title)
                .font(.kid(.title))
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            if let onSpeak {
                SpeakerButton(action: onSpeak)
            } else {
                Color.clear.frame(width: DSMetrics.roundIconSize, height: DSMetrics.roundIconSize)
            }
        }
        .padding(.horizontal, DSMetrics.screenPadding)
        .padding(.top, 8)
    }
}

extension View {
    /// Hides the system navigation bar; kid screens use `KidHeader` instead.
    func kidScreen(background: Color) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
    }
}
