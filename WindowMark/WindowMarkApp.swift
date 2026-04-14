import SwiftUI
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var watchlistManager: WatchlistManager!
    var hotkeyManager: HotkeyManager!
    private var permissionTimer: Timer?
    private var cleanupTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AXIsProcessTrusted() {
            startServices()
        } else {
            showAccessibilityAlert()
            startPermissionPolling()
        }
    }

    private func startServices() {
        wireHotkeys()
        hotkeyManager.start()
        startCleanupTimer()
        startAppTerminationObserver()
    }

    private func wireHotkeys() {
        hotkeyManager.onToggleMark = { [weak self] in
            MainActor.assumeIsolated {
                self?.watchlistManager.toggleMark()
            }
        }
        hotkeyManager.onCycleNext = { [weak self] in
            MainActor.assumeIsolated {
                self?.watchlistManager.cycleNext()
            }
        }
        hotkeyManager.onCyclePrev = { [weak self] in
            MainActor.assumeIsolated {
                self?.watchlistManager.cyclePrev()
            }
        }
        hotkeyManager.onShowExpose = { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let wm = self.watchlistManager else { return }
                if ExposePanelController.shared.isVisible {
                    ExposePanelController.shared.dismiss()
                } else {
                    ExposePanelController.shared.show(watchlistManager: wm)
                }
            }
        }
        hotkeyManager.onClearAll = { [weak self] in
            MainActor.assumeIsolated {
                self?.watchlistManager.clearAll()
            }
        }
    }

    // MARK: - Permission Flow

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "WindowMark needs Accessibility permission to detect hotkeys and manage windows.\n\nPlease grant access in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if AXIsProcessTrusted() {
                    self?.permissionTimer?.invalidate()
                    self?.permissionTimer = nil
                    self?.startServices()
                }
            }
        }
    }

    // MARK: - Auto-Cleanup

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.watchlistManager.removeStaleWindows()
            }
        }
    }

    private func startAppTerminationObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                self?.watchlistManager.removeWindows(forPID: app.processIdentifier)
            }
        }
    }
}

@main
struct WindowMarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var watchlistManager: WatchlistManager {
        appDelegate.watchlistManager
    }

    init() {
        let windowManager = WindowManager()
        let watchlist = WatchlistManager(windowManager: windowManager)
        let hotkeys = HotkeyManager()

        // Inject into the delegate. Since @NSApplicationDelegateAdaptor creates the delegate
        // before init() completes, we can set properties here.
        let delegate = NSApplication.shared.delegate as! AppDelegate
        delegate.watchlistManager = watchlist
        delegate.hotkeyManager = hotkeys
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(watchlistManager: watchlistManager)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: watchlistManager.windows.isEmpty ? "bookmark" : "bookmark.fill")
                if !watchlistManager.windows.isEmpty {
                    Text("\(watchlistManager.windows.count)")
                }
            }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: watchlistManager.lastToastMessage) { _, newValue in
            if let message = newValue {
                ToastOverlay.shared.show(message: message)
            }
        }
    }
}
