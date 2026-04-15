import ServiceManagement
import SwiftUI

struct MenuBarView: View {
    let watchlistManager: WatchlistManager
    @Bindable var settings: Settings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        if watchlistManager.targets.isEmpty {
            Text("No watched windows")
                .foregroundStyle(.secondary)
        } else {
            Text("\(watchlistManager.targets.count) watched item\(watchlistManager.targets.count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)

            Divider()

            ForEach(Array(watchlistManager.targets.enumerated()), id: \.element.id) { index, target in
                Button {
                    watchlistManager.focusTarget(at: index)
                } label: {
                    HStack {
                        if let icon = target.appIcon {
                            Image(nsImage: icon)
                        }
                        Text(target.displayTitle)
                            .lineLimit(1)
                        if index == watchlistManager.currentIndex {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        Divider()

        // Palette Position submenu
        Menu("Palette Position") {
            ForEach(PalettePosition.allCases, id: \.rawValue) { position in
                Button {
                    settings.palettePosition = position
                } label: {
                    HStack {
                        Text(position.displayName)
                        if position == settings.palettePosition {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Toggle("Hide on Full Screen", isOn: $settings.hideOnFullScreen)

        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                } catch {
                    NSLog("[Waymark] Launch at Login error: %@", error.localizedDescription)
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        ))

        if !watchlistManager.targets.isEmpty {
            Button("Clear All", role: .destructive) {
                watchlistManager.clearAll()
            }
        }

        Divider()

        Text("⌃⌥M mark · ⌃⌥N cycle · ⌃⌥L exposé")
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Button("About Waymark") {
            AboutPanelController.shared.show()
        }

        Button("Quit Waymark") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
