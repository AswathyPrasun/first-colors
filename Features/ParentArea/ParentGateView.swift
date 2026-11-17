import SwiftUI

/// "Press and hold for 3 seconds". System font: this screen is for grown-ups.
struct ParentGateView: View {
    @State private var vm: ParentGateViewModel

    init(vm: ParentGateViewModel) {
        _vm = State(initialValue: vm)
    }

    var body: some View {
        VStack(spacing: 32) {
            // Room for the close button, which is pinned to the corner below.
            Color.clear.frame(height: 60)

            Spacer(minLength: 0)

            // Full Dynamic Type: at the largest sizes only this text scrolls; the lock below
            // stays put, so holding it never competes with scrolling.
            ScrollView {
                Text("Press and hold the button for 3 seconds to open settings.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DSColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 320)
            .fixedSize(horizontal: false, vertical: true)

            ZStack {
                Circle().fill(DSColor.card)
                Circle()
                    .stroke(DSColor.cardShadow, lineWidth: 12)
                    .padding(6)
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(DSColor.gateProgress, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(6)
                Image(systemName: vm.isPassed ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(DSColor.ink)
            }
            .frame(width: 200, height: 200)
            .scaleEffect(vm.isHolding ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: vm.isHolding)
            .contentShape(Circle())
            // Long press with an endless duration: we only want "finger down / finger up"
            // (including cancellation); the 3-second timing lives in the ViewModel.
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 80, perform: {}) { pressing in
                if pressing { vm.pressBegan() } else { vm.pressEnded() }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Grown-ups lock"))
            .accessibilityHint(Text("Press and hold for 3 seconds"))
            .accessibilityValue(Text("\(Int(vm.progress * 100)) percent"))
            .accessibilityIdentifier("gateButton")

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(DSMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: vm.cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DSColor.ink)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(DSColor.card))
            }
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("gateClose")
            .padding(DSMetrics.screenPadding)
        }
        .background(DSColor.parentBg.ignoresSafeArea())
    }
}
