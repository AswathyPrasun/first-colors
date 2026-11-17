import SwiftUI

struct ColoringView: View {
    @State private var vm: ColoringViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(vm: ColoringViewModel) {
        _vm = State(initialValue: vm)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // iPad landscape: tools and palette beside the drawing. Everything else: stacked.
            if size.width >= 700, size.width > size.height * 1.05 {
                sideBySide
            } else {
                stacked(paletteColumns: size.width >= 600 ? 8 : 4)
            }
        }
        .kidScreen(background: DSColor.bgColoring)
        .sensoryFeedback(.impact(weight: .light), trigger: vm.fillFeedbackCount)
        .task { await vm.load() }
        // Kids pause to think; don't let the screen lock mid-drawing. Only on this screen.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app: make sure everything is on disk and the thumbnail is current.
            if phase == .background { Task { await vm.finishSaving(markCompleted: false) } }
        }
    }

    // MARK: Layouts

    private func stacked(paletteColumns: Int) -> some View {
        VStack(spacing: 12) {
            KidHeader(title: vm.title, onBack: vm.back, onSpeak: vm.speak)
            drawingCard
            toolbar
            palette(columns: paletteColumns)
            undoAndDone
                .padding(.horizontal, DSMetrics.screenPadding)
                .padding(.bottom, 8)
        }
    }

    private var sideBySide: some View {
        VStack(spacing: 12) {
            KidHeader(title: vm.title, onBack: vm.back, onSpeak: vm.speak)
            HStack(spacing: 8) {
                drawingCard
                VStack(spacing: 24) {
                    Spacer(minLength: 0)
                    toolbar
                    palette(columns: 4)
                    undoAndDone
                    Spacer(minLength: 0)
                }
                .frame(width: 350)
                .padding(.trailing, DSMetrics.screenPadding)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: Pieces

    private var toolbar: some View {
        ToolbarView(activeTool: vm.activeTool,
                    isHintOn: vm.isHintOn,
                    onSelect: vm.select,
                    onHint: vm.toggleHint,
                    onMagic: vm.magic)
    }

    private func palette(columns: Int) -> some View {
        PaletteView(colors: vm.palette,
                    selected: vm.selectedColor,
                    suggested: vm.suggestedHexes,
                    columns: columns,
                    onSelect: vm.select)
    }

    private var undoAndDone: some View {
        HStack(spacing: DSMetrics.spacing) {
            ToolButton(systemImage: "arrow.uturn.backward", accessibilityLabel: "Undo",
                       isEnabled: vm.canUndo, action: vm.undo)
                .scaleEffect(1.1)
                .accessibilityIdentifier("undo")
            PrimaryButton(title: "Done", systemImage: "star.fill", action: vm.done)
                .accessibilityIdentifier("done")
        }
    }

    private var drawingCard: some View {
        RoundedRectangle(cornerRadius: DSMetrics.cardRadius, style: .continuous)
            .fill(DSColor.card)
            .shadow(color: DSColor.cardShadow, radius: 0, y: DSMetrics.tileShadow)
            .overlay {
                if let drawing = vm.drawing {
                    DrawingCanvas(vm: vm, drawing: drawing)
                        .padding(14)
                } else {
                    // Missing or broken art: still a calm, usable screen (never an error).
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(vm.selectedColor.color)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if vm.isAtPointLimit { pointLimitCard }
            }
            .aspectRatio(1, contentMode: .fit)
            // A tiny happy bounce on every fill / Magic (skipped with Reduce Motion).
            .phaseAnimator([1.0, 1.018, 1.0], trigger: reduceMotion ? 0 : vm.fillFeedbackCount) { content, scale in
                content.scaleEffect(scale)
            } animation: { _ in .spring(response: 0.18, dampingFraction: 0.55) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, DSMetrics.screenPadding)
    }

    /// Shown when the drawing reaches the point cap: celebrate, never an error.
    private var pointLimitCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "star.fill")
                .font(.system(size: 64))
                .foregroundStyle(DSColor.primaryButton)
                .accessibilityHidden(true)
            Text("Great drawing! Let's start a new one")
                .font(.kid(.heading))
                .foregroundStyle(DSColor.ink)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Done", systemImage: "star.fill", action: vm.done)
                .frame(maxWidth: 220)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: DSMetrics.cardRadius, style: .continuous)
            .fill(.white.opacity(0.94)))
        .padding(20)
    }
}
