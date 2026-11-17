import CoreGraphics
import SwiftUI

/// Parent area → Save art to Photos: pick finished pictures from every child, save full size.
@MainActor @Observable
final class ExportArtViewModel {
    struct Entry: Identifiable, Hashable {
        var id: String { "\(profileId)/\(itemId)" }
        let profileId: String
        let itemId: String
        let avatar: Avatar
        let name: String
    }

    private(set) var entries: [Entry] = []
    private(set) var thumbnails: [String: CGImage] = [:]
    var selection = Set<String>()
    private(set) var isSaving = false
    private(set) var isLoaded = false
    var message: String?

    @ObservationIgnored private let profiles: any ProfileProviding
    @ObservationIgnored private let content: any ContentProviding
    @ObservationIgnored private let progress: any ProgressStoring
    @ObservationIgnored private let render: any RenderServicing
    @ObservationIgnored private let photos: any PhotoExporting

    init(profiles: any ProfileProviding, content: any ContentProviding, progress: any ProgressStoring,
         render: any RenderServicing, photos: any PhotoExporting) {
        self.profiles = profiles
        self.content = content
        self.progress = progress
        self.render = render
        self.photos = photos
    }

    func load() async {
        var result: [Entry] = []
        for profile in profiles.profiles {
            let finished = await progress.summaries(profileId: profile.id)
                .filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            for summary in finished {
                guard let item = content.item(id: summary.itemId) else { continue }
                result.append(Entry(profileId: profile.id, itemId: item.id, avatar: profile.avatar, name: item.name.en))
            }
        }
        entries = result
        isLoaded = true
    }

    func loadThumbnail(_ entry: Entry) async {
        guard thumbnails[entry.id] == nil,
              let image = await progress.thumbnail(itemId: entry.itemId, profileId: entry.profileId) else { return }
        thumbnails[entry.id] = image
    }

    func toggle(_ entry: Entry) {
        if selection.contains(entry.id) { selection.remove(entry.id) } else { selection.insert(entry.id) }
    }

    func selectAll() { selection = Set(entries.map(\.id)) }

    /// Renders each picked picture at full size (never stored) and adds them to Photos.
    func saveSelected() async {
        guard !selection.isEmpty, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        guard await photos.requestAccess() else {
            message = String(localized: "First Colors can't add to Photos. You can allow it in Settings › Privacy › Photos.")
            return
        }
        var pngs: [Data] = []
        for entry in entries where selection.contains(entry.id) {
            let saved = await progress.loadColoring(itemId: entry.itemId, profileId: entry.profileId)
            if let png = await render.exportPNG(itemId: entry.itemId, fills: saved.fills, strokes: saved.strokes) {
                pngs.append(png)
            }
        }
        do {
            try await photos.save(pngs: pngs)
            message = String(localized: "Saved \(pngs.count) pictures to Photos.")
            selection.removeAll()
        } catch {
            message = String(localized: "The pictures couldn't be saved. Check that the device has free space.")
        }
    }
}

struct ExportArtView: View {
    @State private var vm: ExportArtViewModel

    init(vm: ExportArtViewModel) {
        _vm = State(initialValue: vm)
    }

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        Group {
            if vm.isLoaded && vm.entries.isEmpty {
                ContentUnavailableView("No finished art yet", systemImage: "photo.on.rectangle.angled",
                                       description: Text("Pictures appear here after a child taps Done."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.entries) { entry in
                            cell(entry)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Save to Photos")
        .background(DSColor.parentBg)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Select all", action: vm.selectAll).disabled(vm.entries.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await vm.saveSelected() }
            } label: {
                Label(vm.selection.isEmpty ? String(localized: "Select pictures to save")
                                           : String(localized: "Save \(vm.selection.count) to Photos"),
                      systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(vm.selection.isEmpty || vm.isSaving)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("exportSave")
        }
        .overlay { if vm.isSaving { ProgressView().controlSize(.large) } }
        .task { await vm.load() }
        .alert(vm.message ?? "", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func cell(_ entry: ExportArtViewModel.Entry) -> some View {
        let selected = vm.selection.contains(entry.id)
        return Button { vm.toggle(entry) } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = vm.thumbnails[entry.id] {
                        Image(decorative: image, scale: 1).resizable().scaledToFit()
                    } else {
                        Color.white
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 3 : 1))
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .background(Circle().fill(.white))
                    .padding(6)
                Text(entry.avatar.symbol)
                    .font(.title3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .task { await vm.loadThumbnail(entry) }
        .accessibilityLabel(Text("\(entry.name), \(entry.avatar.accessibilityName)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
