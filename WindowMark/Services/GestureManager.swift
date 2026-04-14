import AppKit

@MainActor
final class GestureManager {
    var onSwipeRight: (() -> Void)?
    var onSwipeLeft: (() -> Void)?

    private var monitor: Any?
    private var accumulatedDeltaX: CGFloat = 0
    private let swipeThreshold: CGFloat = 50
    private var cooldownUntil: Date = .distantPast

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleScrollEvent(event)
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    // MARK: - Private

    private func handleScrollEvent(_ event: NSEvent) {
        // Only trackpad (not mouse scroll wheel)
        guard event.hasPreciseScrollingDeltas else { return }

        // Only when Option is held
        guard event.modifierFlags.contains(.option) else {
            accumulatedDeltaX = 0
            return
        }

        // Ignore momentum scrolling — only respond to active finger contact
        guard event.momentumPhase == [] else { return }

        // Cooldown after firing to prevent rapid re-triggering
        guard Date.now >= cooldownUntil else { return }

        accumulatedDeltaX += event.scrollingDeltaX

        if accumulatedDeltaX > swipeThreshold {
            onSwipeRight?()
            accumulatedDeltaX = 0
            cooldownUntil = Date.now.addingTimeInterval(0.3)
        } else if accumulatedDeltaX < -swipeThreshold {
            onSwipeLeft?()
            accumulatedDeltaX = 0
            cooldownUntil = Date.now.addingTimeInterval(0.3)
        }

        // Reset accumulator when gesture ends
        if event.phase == .ended || event.phase == .cancelled {
            accumulatedDeltaX = 0
        }
    }
}
