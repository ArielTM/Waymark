import SwiftUI
import ApplicationServices

@MainActor
final class AppState: ObservableObject {
    let watchlistManager: WatchlistManager
    let hotkeyManager: HotkeyManager
    private var permissionTimer: Timer?
    private var cleanupTimer: Timer?

    init() {
        let windowManager = WindowManager()
        self.watchlistManager = WatchlistManager(windowManager: windowManager)
        self.hotkeyManager = HotkeyManager()

        // Defer startup to avoid running modal alerts during SwiftUI init
        DispatchQueue.main.async { [self] in
            if AXIsProcessTrusted() {
                self.startServices()
            } else {
                self.showAccessibilityAlert()
                self.startPermissionPolling()
            }
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
                guard let wm = self?.watchlistManager else { return }
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
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(watchlistManager: appState.watchlistManager)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: appState.watchlistManager.windows.isEmpty ? "bookmark" : "bookmark.fill")
                if !appState.watchlistManager.windows.isEmpty {
                    Text("\(appState.watchlistManager.windows.count)")
                }
            }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: appState.watchlistManager.lastToastMessage) { _, newValue in
            if let message = newValue {
                ToastOverlay.shared.show(message: message)
            }
        }
    }
}
