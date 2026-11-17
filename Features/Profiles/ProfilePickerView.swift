import SwiftUI

struct ProfilePickerView: View {
    @State private var vm: ProfilePickerViewModel

    init(vm: ProfilePickerViewModel) {
        _vm = State(initialValue: vm)
    }

    private let columns = [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)]

    var body: some View {
        VStack(spacing: 28) {
            Text("Who's coloring?")
                .font(.kid(.title))
                .foregroundStyle(DSColor.ink)
                .padding(.top, 32)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(vm.choices) { choice in
                    AvatarButton(avatar: choice.avatar, size: 136) {
                        Task { await vm.choose(choice) }
                    }
                    .accessibilityIdentifier("avatar.\(choice.avatar.rawValue)")
                }
                if vm.canAddProfile {
                    Button(action: vm.addProfile) {
                        Image(systemName: "plus")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(DSColor.ink)
                            .frame(width: 136, height: 136)
                    }
                    .buttonStyle(ToyButtonStyle(shape: Circle(), fill: DSColor.tileMyArt,
                                                shadow: DSColor.cardShadow, depth: 6, pressedScale: 0.96))
                    .accessibilityLabel(Text("Add a player"))
                    .accessibilityIdentifier("addProfile")
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.bgHome.ignoresSafeArea())
    }
}
