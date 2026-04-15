import AppKit
import ApplicationServices
import Observation

@Observable
@MainActor
final class WatchlistManager {
    /// Shared instance set during init — used by AXObserver C callbacks.
    nonisolated(unsafe) static weak var shared: WatchlistManager?

    private(set) var targets: [WatchTarget] = []
    private(set) var currentIndex: Int = 0
    private(set) var lastToastMessage: String?

    let windowManager: WindowManager
    let chromeTabService: ChromeTabService
    private var observers: [CGWindowID: AXObserver] = [:]

    init(windowManager: WindowManager, chromeTabService: ChromeTabService) {
        self.windowManager = windowManager
        self.chromeTabService = chromeTabService
        WatchlistManager.shared = self
    }

    // MARK: - Toggle Mark

    func toggleMark() {
        guard let focused = windowManager.getFocusedWindow() else {
            lastToastMessage = "No window to mark"
            return
        }

        // Build the target: Chrome tab or plain window
        let target: WatchTarget
        if ChromeTabService.isChrome(focused.bundleIdentifier),
           let tabInfo = chromeTabService.getActiveTab() {
            target = .chromeTab(focused, tabInfo)
        } else {
            target = .window(focused)
        }

        // Check for existing entry to toggle off
        if let existingIndex = targets.firstIndex(where: { $0.id == target.id }) {
            let removed = targets[existingIndex]
            removeObserver(for: removed)
            targets.remove(at: existingIndex)
            if targets.isEmpty {
                currentIndex = 0
            } else if existingIndex <= currentIndex {
                currentIndex = max(0, currentIndex - 1)
            }
            lastToastMessage = "− Unmarked: \(removed.displayTitle) [\(targets.count) watched]"
        } else {
            // For chrome tabs, dedup by URL (same tab might be in a different window)
            if case .chromeTab(_, let tab) = target,
               targets.contains(where: {
                   if case .chromeTab(_, let existing) = $0 { return existing.url == tab.url }
                   return false
               }) {
                lastToastMessage = "Tab already marked"
                return
            }
            targets.append(target)
            addObserver(for: target)
            lastToastMessage = "+ Marked: \(target.displayTitle) [\(targets.count) watched]"
        }
    }

    // MARK: - Cycle Forward

    func cycleNext() {
        guard !targets.isEmpty else {
            lastToastMessage = "No watched windows — press ⌃⌥M to mark"
            return
        }

        currentIndex = (currentIndex + 1) % targets.count
        focusCurrentAndToast()
    }

    // MARK: - Cycle Backward

    func cyclePrev() {
        guard !targets.isEmpty else {
            lastToastMessage = "No watched windows — press ⌃⌥M to mark"
            return
        }

        currentIndex = (currentIndex - 1 + targets.count) % targets.count
        focusCurrentAndToast()
    }

    // MARK: - Focus Target at Index

    func focusTarget(at index: Int) {
        guard index >= 0, index < targets.count else { return }
        currentIndex = index
        let target = targets[index]
        windowManager.focusWindow(target.parentWindow)
        if case .chromeTab(_, let tab) = target {
            _ = chromeTabService.activateTab(url: tab.url)
        }
    }

    // MARK: - Clear All

    func clearAll() {
        removeAllObservers()
        targets.removeAll()
        currentIndex = 0
        lastToastMessage = "Watchlist cleared"
    }

    // MARK: - Stale Target Cleanup

    func removeStaleTargets() {
        let liveIDs = windowManager.getAllWindowIDs()
        let before = targets.count

        // Only query Chrome if there are chrome tab targets
        let hasChromeTargets = targets.contains {
            if case .chromeTab = $0 { return true }
            return false
        }
        let liveTabURLs: Set<String> = hasChromeTargets ? chromeTabService.allTabURLs() : []

        // Collect window IDs that are about to lose all their targets
        let windowIDsBefore = Set(targets.map(\.windowID))

        targets.removeAll { target in
            switch target {
            case .window(let w):
                return !liveIDs.contains(w.id)
            case .chromeTab(let w, let tab):
                return !liveIDs.contains(w.id) || !liveTabURLs.contains(tab.url)
            }
        }

        // Clean up observers for windows that no longer have any targets
        let windowIDsAfter = Set(targets.map(\.windowID))
        for wid in windowIDsBefore.subtracting(windowIDsAfter) {
            observers.removeValue(forKey: wid)
        }

        if targets.isEmpty {
            currentIndex = 0
        } else if currentIndex >= targets.count {
            currentIndex = targets.count - 1
        }

        let removed = before - targets.count
        if removed > 0 {
            print("[Waymark] Removed \(removed) stale target(s). \(targets.count) remaining.")
        }
    }

    /// Remove all targets belonging to a terminated application.
    func removeTargets(forPID pid: pid_t) {
        let windowIDs = Set(targets.filter { $0.pid == pid }.map(\.windowID))
        let before = targets.count
        targets.removeAll { $0.pid == pid }

        // Clean up observers for removed windows
        for wid in windowIDs {
            observers.removeValue(forKey: wid)
        }

        if targets.isEmpty {
            currentIndex = 0
        } else if currentIndex >= targets.count {
            currentIndex = targets.count - 1
        }

        let removed = before - targets.count
        if removed > 0 {
            print("[Waymark] App terminated (PID \(pid)). Removed \(removed) target(s).")
        }
    }

    /// Remove all targets for a specific window ID (used by AXObserver callbacks).
    func removeTarget(byWindowID windowID: CGWindowID) {
        let indicesToRemove = targets.enumerated().filter { $0.element.windowID == windowID }.map(\.offset)
        guard !indicesToRemove.isEmpty else { return }

        for index in indicesToRemove.reversed() {
            targets.remove(at: index)
        }

        observers.removeValue(forKey: windowID)

        if targets.isEmpty {
            currentIndex = 0
        } else if currentIndex >= targets.count {
            currentIndex = targets.count - 1
        }

        print("[Waymark] Window \(windowID) destroyed. \(targets.count) remaining.")
    }

    // MARK: - Private

    private func focusCurrentAndToast() {
        guard currentIndex >= 0, currentIndex < targets.count else { return }
        var target = targets[currentIndex]

        // Update title for window targets
        if case .window(var w) = target {
            windowManager.updateTitle(of: &w)
            target = .window(w)
            targets[currentIndex] = target
        }

        windowManager.focusWindow(target.parentWindow)
        if case .chromeTab(_, let tab) = target {
            _ = chromeTabService.activateTab(url: tab.url)
        }

        lastToastMessage = "[\(currentIndex + 1)/\(targets.count)] \(targets[currentIndex].displayTitle)"
    }

    // MARK: - AXObserver Management

    private func addObserver(for target: WatchTarget) {
        let window = target.parentWindow
        guard let axElement = window.axElement else { return }

        // Skip if we already observe this window (multiple tabs share one window)
        guard observers[window.id] == nil else { return }

        var observer: AXObserver?
        let pid = window.pid
        let windowID = window.id

        let context = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<CGWindowID>.size,
            alignment: MemoryLayout<CGWindowID>.alignment
        )
        context.storeBytes(of: windowID, as: CGWindowID.self)

        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let wid = refcon.load(as: CGWindowID.self)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    WatchlistManager.shared?.removeTarget(byWindowID: wid)
                }
            }
        }

        let result = AXObserverCreate(pid, callback, &observer)
        guard result == .success, let observer else {
            context.deallocate()
            return
        }

        AXObserverAddNotification(observer, axElement, kAXUIElementDestroyedNotification as CFString, context)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        observers[windowID] = observer
    }

    private func removeObserver(for target: WatchTarget) {
        let windowID = target.windowID
        // Only remove observer if no other targets share this window
        let othersWithSameWindow = targets.filter { $0.windowID == windowID && $0.id != target.id }
        if othersWithSameWindow.isEmpty {
            observers.removeValue(forKey: windowID)
        }
    }

    private func removeAllObservers() {
        observers.removeAll()
    }
}
