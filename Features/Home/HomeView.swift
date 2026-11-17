import SwiftUI

struct HomeView: View {
    @State private var vm: HomeViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// iPad gets bigger tiles and drawings; content stays centered at a comfortable width.
    private var isRegular: Bool { sizeClass == .regular }

    init(vm: HomeViewModel) {
        _vm = State(initialValue: vm)
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            // iPad: sit the tiles in the middle of the screen rather than under the header.
            if isRegular { Spacer(minLength: 0) }
            HStack(spacing: DSMetrics.spacing) {
                ForEach(vm.categories, id: \.self) { category in
                    categoryTile(category)
                }
            }
            .frame(height: isRegular ? 320 : 226)
            myArtRow
                .frame(height: isRegular ? 130 : 112)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 760)
        .padding(.horizontal, DSMetrics.screenPadding)
        .padding(.top, isRegular ? 24 : 8)
        .frame(maxWidth: .infinity)
        .kidScreen(background: DSColor.bgHome)
        .task(id: vm.profileId) { await vm.refreshLatestArt() }
    }

    private var header: some View {
        HStack(spacing: DSMetrics.smallSpacing) {
            AvatarButton(avatar: vm.avatar, size: DSMetrics.roundIconSize, action: vm.switchProfile)
                .disabled(!vm.canSwitchProfile)
                .accessibilityLabel(Text(vm.canSwitchProfile ? "Change player" : vm.avatar.accessibilityName))
                .accessibilityIdentifier("homeAvatar")
            Text("Let's color!")
                .font(.kid(.title))
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            RoundIconButton(systemImage: "lock.fill", accessibilityLabel: "Grown-ups") {
                vm.openParentArea()
            }
            .accessibilityIdentifier("parentLock")
        }
    }

    private func categoryTile(_ category: Category) -> some View {
        ZStack(alignment: .topTrailing) {
            BigTile(fill: category.tileFill,
                    shadow: category.tileShadow,
                    accessibilityLabel: category.title,
                    action: { vm.selectCategory(category) }) {
                VStack(spacing: 6) {
                    // Sits below the speaker button so neither covers the other.
                    illustration(category)
                        .frame(width: isRegular ? 170 : 100, height: isRegular ? 170 : 100)
                        .padding(.top, 40)
                        .accessibilityHidden(true)
                    Text(category.title)
                        .font(.kid(.title))
                        .foregroundStyle(DSColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .accessibilityIdentifier("category.\(category.rawValue)")

            SpeakerButton { vm.speak(category) }
                .padding(10)
        }
    }

    @ViewBuilder
    private func illustration(_ category: Category) -> some View {
        if let art = vm.illustration(for: category) {
            DrawingPicture(drawing: art.drawing,
                           fills: art.fills.compactMapValues { Color(hexString: $0) })
        } else {
            Text(category.symbol).font(.system(size: 84))
        }
    }

    private var myArtRow: some View {
        BigTile(fill: DSColor.card,
                shadow: DSColor.cardShadow,
                accessibilityLabel: "My Art",
                action: vm.openGallery) {
            HStack(spacing: DSMetrics.spacing) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(DSColor.tileMyArtIcon)
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DSColor.tileMyArt))
                Text("My Art")
                    .font(.kid(.heading))
                    .foregroundStyle(DSColor.ink)
                Spacer(minLength: 0)
                HStack(spacing: -14) {
                    ForEach(Array(vm.latestArt.enumerated()), id: \.offset) { index, image in
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 62, height: 62)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(DSColor.cardShadow, lineWidth: 3))
                            .rotationEffect(.degrees(Double(index - 1) * 6))
                            .zIndex(Double(3 - index))
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("myArt")
    }
}
