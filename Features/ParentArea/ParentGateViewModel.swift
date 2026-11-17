import Foundation

/// Press-and-hold gate in front of everything grown-up (settings, profiles, Photos export,
/// backup/restore, clearing art). Releasing early resets it.
@MainActor @Observable
final class ParentGateViewModel {
    static let holdDuration: TimeInterval = 3

    /// 0…1 while holding.
    private(set) var progress: Double = 0
    private(set) var isPassed = false

    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let tick: @MainActor () async -> Void
    @ObservationIgnored private let onPassed: @MainActor () -> Void
    @ObservationIgnored private let onCancel: @MainActor () -> Void
    @ObservationIgnored private var pressStart: Date?
    @ObservationIgnored private var loop: Task<Void, Never>?

    /// - Parameters:
    ///   - now: the clock (tests pass a manual one).
    ///   - tick: waits about one frame between progress updates.
    init(now: @escaping @MainActor () -> Date = { Date() },
         tick: @escaping @MainActor () async -> Void = { try? await Task.sleep(for: .milliseconds(16)) },
         onPassed: @escaping @MainActor () -> Void,
         onCancel: @escaping @MainActor () -> Void) {
        self.now = now
        self.tick = tick
        self.onPassed = onPassed
        self.onCancel = onCancel
    }

    var isHolding: Bool { pressStart != nil }

    func pressBegan() {
        guard pressStart == nil, !isPassed else { return }
        pressStart = now()
        progress = 0
        loop = Task { [weak self] in
            while let self, self.isHolding, !self.isPassed, !Task.isCancelled {
                await self.tick()
                self.update()
            }
        }
    }

    func pressEnded() {
        guard pressStart != nil else { return }
        pressStart = nil
        loop?.cancel()
        loop = nil
        if !isPassed { progress = 0 }
    }

    /// Recomputes progress from the clock; opens the gate at 3 seconds.
    func update() {
        guard let start = pressStart, !isPassed else { return }
        progress = min(1, max(0, now().timeIntervalSince(start) / Self.holdDuration))
        if progress >= 1 {
            isPassed = true
            pressStart = nil
            loop?.cancel()
            loop = nil
            onPassed()
        }
    }

    func cancel() {
        pressEnded()
        onCancel()
    }
}
