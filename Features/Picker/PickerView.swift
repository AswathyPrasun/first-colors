import SwiftUI

struct PickerView: View {
    @State private var vm: PickerViewModel

    init(vm: PickerViewModel) {
        _vm = State(initialValue: vm)
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Two big columns on iPhone; as many roomy columns as fit on iPad.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: sizeClass == .regular ? 200 : 150, maximum: 280), spacing: DSMetrics.spacing)]
    }

    private var tileHeight: CGFloat { sizeClass == .regular ? 220 : 160 }

    var body: some View {
        VStack(spacing: DSMetrics.spacing) {
            KidHeader(title: String(localized: vm.category.titleResource),
                      onBack: vm.back,
                      onSpeak: vm.speakCategory)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(vm.tiles) { tile in
                        tileView(tile)
                    }
                }
                .padding(.horizontal, DSMetrics.screenPadding)
                .padding(.bottom, 24)
            }
        }
        .kidScreen(background: vm.category.screenBackground)
        .task { await vm.refresh() }
    }

    private func tileView(_ tile: PickerViewModel.Tile) -> some View {
        Button { vm.select(tile.id) } label: {
            VStack(spacing: 6) {
                // The child's coloring, or the blank outline (decoded off the main thread).
                Group {
                    if let image = vm.thumbnails[tile.id] {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: tile.hasSavedArt) { await vm.loadThumbnail(for: tile.id) }
                Text(tile.name)
                    .font(.kid(.label))
                    .foregroundStyle(DSColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: tileHeight)
            .overlay(alignment: .topTrailing) {
                if tile.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(DSColor.success))
                        .padding(10)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(ToyButtonStyle(
            shape: RoundedRectangle(cornerRadius: DSMetrics.pickerTileRadius, style: .continuous),
            fill: DSColor.card,
            shadow: DSColor.cardShadow,
            depth: 5,
            pressedScale: 0.96))
        .accessibilityLabel(Text(tile.name))
        .accessibilityValue(tile.isCompleted ? Text("Done") : Text(""))
        .accessibilityIdentifier("item.\(tile.id)")
    }
}
