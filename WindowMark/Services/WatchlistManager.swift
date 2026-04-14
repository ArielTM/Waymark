import AppKit
import ApplicationServices
import Observation

@Observable
@MainActor
final class WatchlistManager {
    /// Shared instance set during init — used by AXObserver C callbacks.
    nonisolated(unsafe) static weak var shared: WatchlistManager?

    private(set) var windows: [WatchedWindow] = []
    private(set) var currentIndex: Int = 0
    private(set) var lastToastMessage: String?

    let windowManager: WindowManager
    private var observers: [CGWindowID: AXObserver] = [:]

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        WatchlistManager.shared = self
    }

    // MARK: - Toggle Mark

    func toggleMark() {
        guard let focused = windowManager.getFocusedWindow() else {
            lastToastMessage = "No window to mark"
            return
        }

        if let existingIndex = windows.firstIndex(where: { $0.id == focused.id }) {
            removeObserver(for: focused.id)
            windows.remove(at: existingIndex)
            if windows.isEmpty {
                currentIndex = 0
            } else if existingIndex <= currentIndex {
                currentIndex = max(0, currentIndex - 1)
            }
            lastToastMessage = "− Unmarked: \(focused.displayTitle) [\(windows.count) watched]"
        } else {
            windows.append(focused)
            addObserver(for: focused)
            lastToastMessage = "+ Marked: \(focused.displayTitle) [\(windows.count) watched]"
        }
    }

    // MARK: - Cycle Forward

    func cycleNext() {
        guard !windows.isEmpty else {
            lastToastMessage = "No watched windows — press ⌃⌥M to mark"
            return
        }

        currentIndex = (currentIndex + 1) % windows.count
        focusCurrentAndToast()
    }

    // MARK: - Cycle Backward

    func cyclePrev() {
        guard !windows.isEmpty else {
            lastToastMessage = "No watched windows — press ⌃⌥M to mark"
            return
        }

        currentIndex = (currentIndex - 1 + windows.count) % windows.count
        focusCurrentAndToast()
    }

    // MARK: - Focus Window at Index

    func focusWindow(at index: Int) {
        guard index >= 0, index < windows.count else { return }
        currentIndex = index
        windowManager.focusWindow(windows[index])
    }

    // MARK: - Clear All

    func clearAll() {
        removeAllObservers()
        windows.removeAll()
        currentIndex = 0
        lastToastMessage = "Watchlist cleared"
    }

    // MARK: - Stale Window Cleanup

    func removeStaleWindows() {
        let liveIDs = windowManager.getAllWindowIDs()
        let before = windows.count
        windows.removeAll { !liveIDs.contains($0.id) }

        if windows.isEmpty {
            currentIndex = 0
        } else if currentIndex >= windows.count {
            currentIndex = windows.count - 1
        }

        let removed = before - windows.count
        if removed > 0 {
            print("[WindowMark] Removed \(removed) stale window(s). \(windows.count) remaining.")
        }
    }

    /// Remove all watched windows belonging to a terminated application.
    func removeWindows(forPID pid: pid_t) {
        let before = windows.count
        windows.removeAll { $0.pid == pid }

        if windows.isEmpty {
            currentIndex = 0
        } else if currentIndex >= windows.count {
            currentIndex = windows.count - 1
        }

        let removed = before - windows.count
        if removed > 0 {
            print("[WindowMark] App terminated (PID \(pid)). Removed \(removed) window(s).")
        }
    }

    /// Remove a specific window by ID (used by AXObserver callbacks).
    func removeWindow(byID windowID: CGWindowID) {
        guard let index = windows.firstIndex(where: { $0.id == windowID }) else { return }
        windows.remove(at: index)

        if windows.isEmpty {
            currentIndex = 0
        } else if index <= currentIndex && currentIndex > 0 {
            currentIndex -= 1
        } else if currentIndex >= windows.count {
            currentIndex = windows.count - 1
        }

        print("[WindowMark] Window \(windowID) destroyed. \(windows.count) remaining.")
    }

    // MARK: - Private

    private func focusCurrentAndToast() {
        windowManager.updateTitle(of: &windows[currentIndex])
        windowManager.focusWindow(windows[currentIndex])
        lastToastMessage = "[\(currentIndex + 1)/\(windows.count)] \(windows[currentIndex].displayTitle)"
    }

    // MARK: - AXObserver Management

    private func addObserver(for window: WatchedWindow) {
        guard let axElement = window.axElement else { return }

        var observer: AXObserver?
        let pid = window.pid
        let windowID = window.id

        // Create a raw pointer to the window ID for the callback context
        let context = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<CGWindowID>.size, alignment: MemoryLayout<CGWindowID>.alignment)
        context.storeBytes(of: windowID, as: CGWindowID.self)

        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            let wid = refcon.load(as: CGWindowID.self)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    WatchlistManager.shared?.removeWindow(byID: wid)
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

    private func removeObserver(for windowID: CGWindowID) {
        observers.removeValue(forKey: windowID)
        // AXObserver is automatically cleaned up when deinitialized
    }

    private func removeAllObservers() {
        observers.removeAll()
    }
}
