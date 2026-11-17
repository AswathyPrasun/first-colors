import SwiftUI
import UniformTypeIdentifiers

/// iOS-settings style parent area (system font, Dynamic Type), shown after the gate.
struct ParentHomeView: View {
    @State private var vm: ParentHomeViewModel

    init(vm: ParentHomeViewModel) {
        _vm = State(initialValue: vm)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Sounds", isOn: $vm.soundEnabled)
                Toggle("Music", isOn: $vm.musicEnabled)
                Picker("Voice language", selection: $vm.voiceLanguage) {
                    Text("English").tag(VoiceLanguage.en)
                    Text("Arabic").tag(VoiceLanguage.ar)
                }
            } header: {
                SectionHeader("Sound")
            }

            Section {
                Button("Profiles", action: vm.showProfiles)
                    .accessibilityIdentifier("parentProfiles")
            } header: {
                SectionHeader("Children")
            }

            Section {
                Button("Save art to Photos", action: vm.showExport)
                    .accessibilityIdentifier("parentExport")
                Button { Task { await vm.makeBackup() } } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Back up art")
                        Text("One .zip file you can keep in Files or on a computer.")
                            .font(.footnote)
                            .foregroundStyle(DSColor.parentSecondary)
                    }
                }
                .disabled(vm.isWorking)
                .accessibilityIdentifier("parentBackup")
                Button("Restore from a backup", action: vm.chooseBackupToRestore)
                    .disabled(vm.isWorking)
                    .accessibilityIdentifier("parentRestore")
            } header: {
                SectionHeader("Art")
            }

            Section {
                LabeledContent("Storage used", value: vm.storageText)
                    .accessibilityIdentifier("parentStorage")
                Button("Clear all art", role: .destructive, action: vm.askToClearAllArt)
                    .foregroundStyle(DSColor.parentDestructive)
                    .accessibilityIdentifier("parentClear")
            } footer: {
                Text("Works fully offline. No data leaves this device.")
                    .foregroundStyle(DSColor.parentSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
        .tint(DSColor.parentAccent)
        .navigationTitle("Grown-ups")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(DSColor.parentBg)
        .overlay { if vm.isWorking { ProgressView().controlSize(.large) } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: vm.finish)
                    .buttonStyle(.borderedProminent)
                    .tint(DSColor.parentAccent)
                    .accessibilityIdentifier("parentDone")
            }
        }
        .task { await vm.refreshStorage() }
        .confirmationDialog("Clear all art?", isPresented: $vm.isConfirmingClear, titleVisibility: .visible) {
            Button("Clear all art", role: .destructive) { Task { await vm.clearAllArt() } }
        } message: {
            Text("Every child's colorings on this device will be removed. Profiles stay. This can't be undone.")
        }
        .fileImporter(isPresented: $vm.isPickingBackup, allowedContentTypes: [.zip]) { result in
            vm.backupPicked(result)
        }
        .confirmationDialog(
            "Replace everything with this backup?",
            isPresented: Binding(get: { vm.pendingRestoreURL != nil }, set: { if !$0 { vm.pendingRestoreURL = nil } }),
            titleVisibility: .visible
        ) {
            Button("Replace with backup", role: .destructive) { Task { await vm.restorePendingBackup() } }
        } message: {
            Text("All profiles and art on this device will be replaced by the backup.")
        }
        .sheet(isPresented: Binding(get: { vm.backupURL != nil }, set: { if !$0 { vm.backupURL = nil } })) {
            if let url = vm.backupURL { ActivityView(items: [url]) }
        }
        .alert(vm.message ?? "", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}

/// Parent-area section header with readable contrast (system gray is just under 4.5:1 here).
struct SectionHeader: View {
    let title: LocalizedStringKey
    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DSColor.parentSecondary)
    }
}

/// System share sheet (Save to Files, AirDrop to the parent's own Mac, …). Parent area only.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
