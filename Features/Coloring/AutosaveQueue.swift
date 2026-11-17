import Foundation

/// Serial, coalescing autosave for the coloring screen.
///
/// - Fills are saved after every fill; strokes after every finger lift (CLAUDE.md §8).
/// - Writes happen in order, off the main thread (the store is an actor).
/// - If several saves of the same kind queue up while one is writing, only the newest is
///   written, so fast scribbling never builds a backlog.
@MainActor
final class AutosaveQueue {
    private let store: any ProgressStoring
    private let itemId: String
    private let profileId: String
    private var pendingFills: [String: String]?
    private var pendingStrokes: [Stroke]?
    private var worker: Task<Void, Never>?

    /// Number of writes actually sent to the store (exposed for tests).
    private(set) var writeCount = 0

    init(store: any ProgressStoring, itemId: String, profileId: String) {
        self.store = store
        self.itemId = itemId
        self.profileId = profileId
    }

    func save(fills: [String: String]) {
        pendingFills = fills
        startIfNeeded()
    }

    func save(strokes: [Stroke]) {
        pendingStrokes = strokes
        startIfNeeded()
    }

    /// Waits until everything queued so far is on disk.
    func flush() async {
        while let worker {
            await worker.value
            if self.worker == worker { break }
        }
    }

    private func startIfNeeded() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while let self, let job = self.nextJob() {
                await job()
                self.writeCount += 1
            }
            self?.worker = nil
        }
    }

    private func nextJob() -> (() async -> Void)? {
        let store = store, itemId = itemId, profileId = profileId
        if let fills = pendingFills {
            pendingFills = nil
            return { await store.saveFills(fills, itemId: itemId, profileId: profileId) }
        }
        if let strokes = pendingStrokes {
            pendingStrokes = nil
            return { await store.saveStrokes(strokes, itemId: itemId, profileId: profileId) }
        }
        return nil
    }
}
