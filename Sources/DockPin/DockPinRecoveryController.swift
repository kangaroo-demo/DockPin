import Foundation

/// Coalesces display changes and gives macOS time to restore the Dock after hot-plug or wake.
final class DockPinRecoveryController {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    private let schedule: Scheduler
    private let applyPin: (Bool) -> Bool
    private let isPinned: () -> Bool
    private let cancelNudge: () -> Void
    private var displaySnapshot: [DisplayInfo] = []
    private var generation = 0

    private(set) var isRecovering = false

    init(
        schedule: @escaping Scheduler = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        },
        applyPin: @escaping (Bool) -> Bool,
        isPinned: @escaping () -> Bool,
        cancelNudge: @escaping () -> Void
    ) {
        self.schedule = schedule
        self.applyPin = applyPin
        self.isPinned = isPinned
        self.cancelNudge = cancelNudge
    }

    func updateDisplays(_ displays: [DisplayInfo]) {
        let snapshot = displays.sorted { $0.id < $1.id }
        guard snapshot != displaySnapshot else {
            // Dock ownership changes visibleFrame and may emit another screen notification.
            // Only physical topology changes should start a new recovery.
            return
        }
        displaySnapshot = snapshot
        requestPin(after: 0.8, restoreCursor: true)
    }

    func requestPin(after delay: TimeInterval, restoreCursor: Bool) {
        cancel()
        isRecovering = true
        scheduleAttempt(after: delay, restoreCursor: restoreCursor, remainingAttempts: 3, generation: generation)
    }

    func cancel() {
        generation += 1
        isRecovering = false
        cancelNudge()
    }

    private func scheduleAttempt(
        after delay: TimeInterval,
        restoreCursor: Bool,
        remainingAttempts: Int,
        generation: Int
    ) {
        schedule(delay) { [weak self] in
            guard let self, self.generation == generation else {
                return
            }
            guard self.applyPin(restoreCursor) else {
                self.isRecovering = false
                return
            }

            // Wait for all activation pulses and cursor restoration before checking ownership.
            self.schedule(1.4) { [weak self] in
                guard let self, self.generation == generation else {
                    return
                }
                guard !self.isPinned(), remainingAttempts > 1 else {
                    self.isRecovering = false
                    return
                }
                self.scheduleAttempt(
                    after: 1.0,
                    restoreCursor: restoreCursor,
                    remainingAttempts: remainingAttempts - 1,
                    generation: generation
                )
            }
        }
    }
}
