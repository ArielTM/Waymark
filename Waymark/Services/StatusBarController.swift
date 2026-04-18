import AppKit
import ServiceManagement

/// AppKit-backed menu bar controller.
///
/// We use `NSStatusItem` + `NSMenu` instead of SwiftUI's `MenuBarExtra` so the
/// `NSMenuDelegate.menuWillOpen(_:)` hook can fire an async title refresh the
/// moment the user opens the menu — `MenuBarExtra` has no equivalent hook.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let watchlistManager: WatchlistManager
    private let settings: Settings
    private let menu = NSMenu()

    // Row 0..targetCount-1 of menu items that render a marked target.
    // Kept around so async title refresh can update `.title` in place.
    private var targetItems: [NSMenuItem] = []

    init(watchlistManager: WatchlistManager, settings: Settings) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.watchlistManager = watchlistManager
        self.settings = settings
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        refreshButton()
        observeTargetCount()
    }

    // MARK: - Button rendering

    private func refreshButton() {
        let count = watchlistManager.targets.count
        guard let button = statusItem.button else { return }
        // CairnIcon.menuBarImage already sets isTemplate = true so macOS tints
        // it for light/dark mode — don't override.
        button.image = CairnIcon.menuBarImage(filled: count > 0)
        button.imagePosition = .imageLeading
        button.title = count > 0 ? " \(count)" : ""
    }

    private func observeTargetCount() {
        withObservationTracking {
            _ = watchlistManager.targets.count
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.refreshButton()
                self.observeTargetCount()
            }
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()

        // Show cached titles immediately, refresh in place once fresh titles arrive.
        Task { [weak self] in
            guard let self else { return }
            await self.watchlistManager.refreshAllTitles()
            self.updateOpenMenuTitles()
        }
    }

    private func updateOpenMenuTitles() {
        let targets = watchlistManager.targets
        for (i, item) in targetItems.enumerated() where i < targets.count {
            let fresh = targetTitle(for: targets[i], index: i)
            if item.title != fresh {
                item.title = fresh
            }
        }
    }

    // MARK: - Menu rebuild

    private func rebuildMenu() {
        menu.removeAllItems()
        targetItems.removeAll()

        let targets = watchlistManager.targets

        if targets.isEmpty {
            let header = NSMenuItem(title: "No watched windows", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        } else {
            let header = NSMenuItem(
                title: "\(targets.count) watched item\(targets.count == 1 ? "" : "s")",
                action: nil,
                keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(.separator())

            for (index, target) in targets.enumerated() {
                let item = NSMenuItem(
                    title: targetTitle(for: target, index: index),
                    action: #selector(focusTarget(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                if let icon = target.appIcon {
                    let resized = NSImage(size: NSSize(width: 16, height: 16))
                    resized.lockFocus()
                    icon.draw(in: NSRect(origin: .zero, size: NSSize(width: 16, height: 16)))
                    resized.unlockFocus()
                    item.image = resized
                }
                if index == watchlistManager.currentIndex {
                    item.state = .on
                }
                menu.addItem(item)
                targetItems.append(item)
            }
        }

        menu.addItem(.separator())

        // Palette Position submenu
        let positionMenu = NSMenu(title: "Palette Position")
        for position in PalettePosition.allCases {
            let item = NSMenuItem(
                title: position.displayName,
                action: #selector(setPalettePosition(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = position.rawValue
            if position == settings.palettePosition {
                item.state = .on
            }
            positionMenu.addItem(item)
        }
        let positionParent = NSMenuItem(title: "Palette Position", action: nil, keyEquivalent: "")
        positionParent.submenu = positionMenu
        menu.addItem(positionParent)

        // Show Palette submenu (replaces old "Full Screen Apps")
        let visibilityMenu = NSMenu(title: "Show Palette")
        for visibility in PaletteVisibility.allCases {
            let item = NSMenuItem(
                title: visibility.displayName,
                action: #selector(setPaletteVisibility(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = visibility.rawValue
            if visibility == settings.paletteVisibility {
                item.state = .on
            }
            visibilityMenu.addItem(item)
        }
        let visibilityParent = NSMenuItem(title: "Show Palette", action: nil, keyEquivalent: "")
        visibilityParent.submenu = visibilityMenu
        menu.addItem(visibilityParent)

        // Launch at Login
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(launchItem)

        if !targets.isEmpty {
            let clear = NSMenuItem(title: "Clear All", action: #selector(clearAll(_:)), keyEquivalent: "")
            clear.target = self
            menu.addItem(clear)
        }

        menu.addItem(.separator())

        let hints = NSMenuItem(
            title: "⌃⌥M mark · ⌃⌥N cycle · ⌃⌥L exposé",
            action: nil,
            keyEquivalent: ""
        )
        hints.isEnabled = false
        menu.addItem(hints)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Waymark", action: #selector(showAbout(_:)), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit Waymark", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        quit.keyEquivalentModifierMask = .command
        menu.addItem(quit)
    }

    private func targetTitle(for target: WatchTarget, index: Int) -> String {
        target.displayTitle
    }

    // MARK: - Actions

    @objc private func focusTarget(_ sender: NSMenuItem) {
        watchlistManager.focusTarget(at: sender.tag)
    }

    @objc private func setPalettePosition(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let position = PalettePosition(rawValue: raw) else { return }
        settings.palettePosition = position
    }

    @objc private func setPaletteVisibility(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let visibility = PaletteVisibility(rawValue: raw) else { return }
        settings.paletteVisibility = visibility
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let enabled = SMAppService.mainApp.status == .enabled
        do {
            if enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("[Waymark] Launch at Login error: %@", error.localizedDescription)
        }
    }

    @objc private func clearAll(_ sender: NSMenuItem) {
        watchlistManager.clearAll()
    }

    @objc private func showAbout(_ sender: NSMenuItem) {
        AboutPanelController.shared.show()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}
