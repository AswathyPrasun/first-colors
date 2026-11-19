import SwiftUI

struct CelebrationView: View {
    @State private var vm: CelebrationViewModel
    @State private var showStars = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(vm: CelebrationViewModel) {
        _vm = State(initialValue: vm)
    }

    var body: some View {
        VStack(spacing: 14) {
            stars
                .padding(.top, 20)

            pictureCard
                .frame(maxHeight: .infinity)

            Text(vm.cheer)
                .font(.kid(.display))
                .foregroundStyle(DSColor.ink)
                .accessibilityIdentifier("celebrationTitle")

            HStack(spacing: DSMetrics.smallSpacing) {
                Text(vm.message)
                    .font(.kid(.body))
                    .foregroundStyle(DSColor.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                SpeakerButton(action: vm.speak)
            }

            HStack(spacing: DSMetrics.spacing) {
                PrimaryButton(title: "Color more", systemImage: "paintbrush.pointed.fill",
                              action: vm.colorMore)
                    .accessibilityIdentifier("colorMore")
                PrimaryButton(title: "My Art", systemImage: "square.grid.2x2.fill",
                              action: vm.openMyArt)
                    .accessibilityIdentifier("celebrationMyArt")
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, DSMetrics.screenPadding)
        .frame(maxWidth: .infinity)
        .kidScreen(background: DSColor.bgCelebration)
        .overlay { ConfettiView().ignoresSafeArea() }
        .task { await vm.load() }
        .onAppear {
            vm.appear()
            if reduceMotion {
                showStars = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5).delay(0.15)) { showStars = true }
            }
        }
    }

    private var stars: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: index == 1 ? 58 : 44))
                    .foregroundStyle(DSColor.primaryButton)
                    .shadow(color: DSColor.primaryButtonShadow, radius: 0, y: 3)
                    .scaleEffect(showStars ? 1 : 0.2)
                    .opacity(showStars ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.5)
                        .delay(0.15 + Double(index) * 0.12), value: showStars)
            }
        }
        .accessibilityHidden(true)
    }

    private var pictureCard: some View {
        RoundedRectangle(cornerRadius: DSMetrics.cardRadius, style: .continuous)
            .fill(DSColor.card)
            .shadow(color: DSColor.cardShadow, radius: 0, y: DSMetrics.tileShadow)
            .overlay {
                if let drawing = vm.drawing, vm.isLoaded {
                    ColoredDrawingView(drawing: drawing, fills: vm.fills, strokes: vm.strokes)
                        .padding(16)
                        .transition(.opacity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement()
            .accessibilityLabel(Text(vm.itemName))
            .accessibilityIdentifier("celebrationPicture")
    }
}
