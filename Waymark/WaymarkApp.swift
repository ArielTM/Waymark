import SwiftUI
import ApplicationServices

@MainActor
final class AppState: ObservableObject {
    let watchlistManager: WatchlistManager
    let hotkeyManager: HotkeyManager
    let gestureManager = GestureManager()
    let paletteController = PalettePanelController()
    let chromeTabService = ChromeTabService()
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
            NSLog("[WindowMark] AXIsProcessTrusted: %d, CGPreflightListenEventAccess: %d", axTrusted ? 1 : 0, inputAccess ? 1 : 0)

            if axTrusted && inputAccess {
                self.startServices()
                NSLog("[WindowMark] Services started")
            } else {
                NSLog("[WindowMark] Requesting permissions")
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
                NSLog("[WindowMark] Polling — AX: %d, Input: %d", ax ? 1 : 0, input ? 1 : 0)
                if ax && input {
                    NSLog("[WindowMark] All permissions granted")
                    self?.permissionTimer?.invalidate()
                    self?.permissionTimer = nil
                    self?.startServices()
                    NSLog("[WindowMark] Services started")
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
                self.paletteController.update(watchlistManager: self.watchlistManager)
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
struct WindowMarkApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(watchlistManager: appState.watchlistManager)
        } label: {
            let count = appState.watchlistManager.targets.count
            Label {
                Text(count > 0 ? "\(count)" : "")
            } icon: {
                Image(nsImage: CairnIcon.menuBarImage(filled: count > 0))
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
