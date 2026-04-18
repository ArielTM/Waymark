import SwiftUI
import ApplicationServices

@MainActor
final class AppState: ObservableObject {
    let settings = Settings()
    let watchlistManager: WatchlistManager
    let hotkeyManager: HotkeyManager
    let gestureManager = GestureManager()
    let paletteController = PalettePanelController()
    let chromeTabService = ChromeTabService()
    private var statusBarController: StatusBarController?
    private var permissionTimer: Timer?
    private var cleanupTimer: Timer?

    init() {
        let windowManager = WindowManager()
        self.watchlistManager = WatchlistManager(windowManager: windowManager, chromeTabService: chromeTabService)
        self.hotkeyManager = HotkeyManager()

        // Defer startup to avoid running modal alerts during SwiftUI init
        DispatchQueue.main.async { [self] in
            let axTrusted = AXIsProcessTrusted()
            let inputAccess = CGPreflightListenEventAccess()
            NSLog("[Waymark] AXIsProcessTrusted: %d, CGPreflightListenEventAccess: %d", axTrusted ? 1 : 0, inputAccess ? 1 : 0)

            // Always install the status item so the user sees the app in the menu bar,
            // even before permissions are granted.
            self.statusBarController = StatusBarController(
                watchlistManager: self.watchlistManager,
                settings: self.settings
            )

            if axTrusted && inputAccess {
                self.startServices()
                NSLog("[Waymark] Services started")
            } else {
                NSLog("[Waymark] Requesting permissions")
                self.requestPermissions(axTrusted: axTrusted, inputAccess: inputAccess)
                self.startPermissionPolling()
            }
        }
    }

    private func startServices() {
        wireHotkeys()
        hotkeyManager.start()
        startCleanupTimer()
        startAppTerminationObserver()
        startPalette()
        startToastBridge()
        wireGestures()
        gestureManager.start()
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

    private func requestPermissions(axTrusted: Bool, inputAccess: Bool) {
        if !axTrusted {
            // Register app in Accessibility list
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options = [promptKey: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        if !inputAccess {
            // This shows the system prompt for Input Monitoring
            CGRequestListenEventAccess()
        }

        ToastOverlay.shared.show(message: "Grant Accessibility + Input Monitoring in System Settings")
    }

    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                let ax = AXIsProcessTrusted()
                let input = CGPreflightListenEventAccess()
                NSLog("[Waymark] Polling — AX: %d, Input: %d", ax ? 1 : 0, input ? 1 : 0)
                if ax && input {
                    NSLog("[Waymark] All permissions granted")
                    self?.permissionTimer?.invalidate()
                    self?.permissionTimer = nil
                    self?.startServices()
                    NSLog("[Waymark] Services started")
                }
            }
        }
    }

    // MARK: - Auto-Cleanup

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.watchlistManager.removeStaleTargets()
            }
        }
    }

    private func wireGestures() {
        gestureManager.onSwipeRight = { [weak self] in
            MainActor.assumeIsolated {
                self?.watchlistManager.cycleNext()
            }
        }
        gestureManager.onSwipeLeft = { [weak self] in
            MainActor.assumeIsolated {
                self?.watchlistManager.cyclePrev()
            }
        }
    }

    private func startPalette() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.paletteController.update(watchlistManager: self.watchlistManager, settings: self.settings)
            }
        }
    }

    /// Bridge `WatchlistManager.lastToastMessage` → `ToastOverlay` using
    /// `withObservationTracking`. Previously this was done via SwiftUI
    /// `.onChange` inside the MenuBarExtra scene; now that the status item is
    /// AppKit-owned, we observe directly.
    private func startToastBridge() {
        observeToast()
    }

    private func observeToast() {
        withObservationTracking {
            _ = watchlistManager.lastToastMessage
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if let message = self.watchlistManager.lastToastMessage {
                    ToastOverlay.shared.show(message: message)
                }
                self.observeToast()
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
                self?.watchlistManager.removeTargets(forPID: app.processIdentifier)
            }
        }
    }
}

@main
struct WaymarkApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menu bar UI is owned by AppKit (StatusBarController). This scene only
        // exists to satisfy SwiftUI's requirement for at least one Scene in an
        // @main App. LSUIElement=true in Info.plist keeps the app dockless.
        // Using SwiftUI.Settings disambiguates from our `Settings` model.
        SwiftUI.Settings {
            EmptyView()
        }
    }
}
