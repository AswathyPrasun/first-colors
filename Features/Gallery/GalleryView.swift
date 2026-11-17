import SwiftUI

struct GalleryView: View {
    @State private var vm: GalleryViewModel

    init(vm: GalleryViewModel) {
        _vm = State(initialValue: vm)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: DSMetrics.spacing),
    ]

    var body: some View {
        VStack(spacing: DSMetrics.spacing) {
            KidHeader(title: String(localized: "My Art"), onBack: vm.back)
            if vm.isEmpty {
                // No text needed: an empty frame says "nothing here yet, go color".
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 96))
                    .foregroundStyle(DSColor.tileMyArtIcon.opacity(0.35))
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel(Text("No art yet"))
                    .accessibilityIdentifier("galleryEmpty")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(vm.entries) { entry in
                            cell(entry)
                        }
                    }
                    .padding(.horizontal, DSMetrics.screenPadding)
                    .padding(.bottom, 24)
                }
            }
        }
        .kidScreen(background: DSColor.bgHome)
        .task { await vm.load() }
    }

    private func cell(_ entry: GalleryViewModel.Entry) -> some View {
        Button { vm.open(entry.id) } label: {
            Group {
                if let image = vm.thumbnails[entry.id] {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(ToyButtonStyle(
            shape: RoundedRectangle(cornerRadius: DSMetrics.pickerTileRadius, style: .continuous),
            fill: DSColor.card, shadow: DSColor.cardShadow, depth: 5, pressedScale: 0.96))
        .task { await vm.loadThumbnail(for: entry.id) }
        .accessibilityLabel(Text(entry.name))
        .accessibilityIdentifier("art.\(entry.id)")
    }
}
