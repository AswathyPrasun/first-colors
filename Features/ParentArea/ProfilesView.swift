import SwiftUI

@MainActor @Observable
final class ProfilesViewModel {
    @ObservationIgnored private let profiles: any ProfileProviding
    /// Profile waiting for the delete confirmation.
    var pendingDelete: Profile?

    init(profiles: any ProfileProviding) {
        self.profiles = profiles
    }

    var list: [Profile] { profiles.profiles }
    var activeId: String? { profiles.activeProfile?.id }
    var availableAvatars: [Avatar] { profiles.availableAvatars }
    var canAdd: Bool { profiles.canAddProfile }
    var canDelete: Bool { profiles.profiles.count > 1 }

    func add(_ avatar: Avatar) async { await profiles.add(avatar) }
    func change(_ profile: Profile, to avatar: Avatar) async { await profiles.changeAvatar(profileId: profile.id, to: avatar) }
    func askToDelete(_ profile: Profile) { pendingDelete = profile }

    func confirmDelete() async {
        guard let profile = pendingDelete else { return }
        pendingDelete = nil
        await profiles.delete(profileId: profile.id)
    }
}

/// Parent area → Profiles: add, change avatar, delete (with confirmation). System font.
struct ProfilesView: View {
    @State private var vm: ProfilesViewModel

    init(vm: ProfilesViewModel) {
        _vm = State(initialValue: vm)
    }

    var body: some View {
        Form {
            Section {
                ForEach(vm.list) { profile in
                    HStack(spacing: 14) {
                        Text(profile.avatar.symbol).font(.largeTitle)
                        Text(profile.avatar.accessibilityName)
                        if profile.id == vm.activeId {
                            Text("Playing now").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            ForEach(vm.availableAvatars, id: \.self) { avatar in
                                Button("\(avatar.symbol) \(avatar.accessibilityName)") {
                                    Task { await vm.change(profile, to: avatar) }
                                }
                            }
                        } label: {
                            Label("Change avatar", systemImage: "arrow.triangle.2.circlepath")
                                .labelStyle(.iconOnly)
                        }
                        .disabled(vm.availableAvatars.isEmpty)
                    }
                    .swipeActions {
                        if vm.canDelete {
                            Button("Delete", role: .destructive) { vm.askToDelete(profile) }
                        }
                    }
                }
            } footer: {
                Text("Each child gets their own art. Profiles have no names or personal details.")
            }

            if vm.canAdd {
                Section {
                    Menu {
                        ForEach(vm.availableAvatars, id: \.self) { avatar in
                            Button("\(avatar.symbol) \(avatar.accessibilityName)") {
                                Task { await vm.add(avatar) }
                            }
                        }
                    } label: {
                        Label("Add a profile", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("parentAddProfile")
                }
            }
        }
        .navigationTitle("Profiles")
        .confirmationDialog(
            "Delete this profile?",
            isPresented: Binding(get: { vm.pendingDelete != nil }, set: { if !$0 { vm.pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete profile and its art", role: .destructive) {
                Task { await vm.confirmDelete() }
            }
        } message: {
            Text("All of this child's colorings will be removed from this device. This can't be undone.")
        }
    }
}
