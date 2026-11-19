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
                .frame(maxWidth: isRegular ? HomeLayout.maxContentWidth : .infinity)
            GeometryReader { geo in
                let layout = HomeLayout(width: geo.size.width, isRegular: isRegular,
                                        categoryCount: vm.categories.count)
                ScrollView {
                    VStack(spacing: DSMetrics.spacing + 4) {
                        VStack(spacing: DSMetrics.spacing) {
                            ForEach(layout.rows(of: vm.categories), id: \.self) { row in
                                HStack(spacing: DSMetrics.spacing) {
                                    ForEach(row, id: \.self) { category in
                                        categoryTile(category, layout: layout)
                                            .frame(width: layout.tileWidth, height: layout.tileHeight)
                                    }
                                }
                            }
                        }
                        myArtRow
                            .frame(width: layout.contentWidth, height: isRegular ? 130 : 112)
                    }
                    .padding(.vertical, 8)
                    // iPad: center the grid in the space under the header instead of leaving a gap.
                    .frame(maxWidth: .infinity, minHeight: geo.size.height,
                           alignment: isRegular ? .center : .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
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

    private func categoryTile(_ category: Category, layout: HomeLayout) -> some View {
        let details = category.details
        return ZStack(alignment: .topTrailing) {
            BigTile(fill: details.tileFill,
                    shadow: details.tileShadow,
                    accessibilityLabel: Text(details.title),
                    action: { vm.selectCategory(category) }) {
                VStack(spacing: 6) {
                    // Sits below the speaker button so neither covers the other.
                    illustration(category)
                        .frame(width: layout.pictureSize, height: layout.pictureSize)
                        .padding(.top, 40)
                        .accessibilityHidden(true)
                    Text(details.title)
                        .font(.kid(.title))
                        .foregroundStyle(DSColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 10)
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
            Text(category.details.symbol).font(.system(size: 84))
        }
    }

    private var myArtRow: some View {
        BigTile(fill: DSColor.card,
                shadow: DSColor.cardShadow,
                accessibilityLabel: Text("My Art"),
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

/// Home grid sizing, kept separate so it can be unit tested.
/// iPhone: 2 columns. iPad: 3 columns, or 5 in a wide (landscape) window. A shorter last row is
/// centered, and tiles never stretch, so every tile is the same size.
struct HomeLayout: Equatable {
    static let maxContentWidth: CGFloat = 1280

    let columns: Int
    let contentWidth: CGFloat
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let pictureSize: CGFloat

    init(width: CGFloat, isRegular: Bool, categoryCount: Int) {
        let spacing = DSMetrics.spacing
        let available = max(width, 200)
        let wanted = isRegular ? (available >= 1100 ? 5 : 3) : 2
        columns = max(1, min(wanted, max(categoryCount, 1)))
        // Few categories on a wide screen: don't let tiles grow huge.
        let maxTile: CGFloat = isRegular ? 340 : 260
        let natural = (min(available, Self.maxContentWidth) - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        tileWidth = min(natural, maxTile)
        contentWidth = max(tileWidth * CGFloat(columns) + spacing * CGFloat(columns - 1),
                           min(available, isRegular ? 760 : available))
        tileHeight = isRegular ? min(max(tileWidth * 1.05, 220), 340)
                               : min(max(tileWidth * 1.15, 190), 226)
        // Room for the speaker button above and the title below.
        pictureSize = max(70, min(tileWidth * 0.62, tileHeight - 40 - 60))
    }

    func rows<T>(of items: [T]) -> [[T]] {
        stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
    }
}
