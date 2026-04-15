import SwiftUI

struct MenuBarView: View {
    let watchlistManager: WatchlistManager
    @State private var selectedPosition = PalettePosition.stored

    var body: some View {
        if watchlistManager.windows.isEmpty {
            Text("No watched windows")
                .foregroundStyle(.secondary)
        } else {
            Text("\(watchlistManager.windows.count) watched window\(watchlistManager.windows.count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)

            Divider()

            ForEach(Array(watchlistManager.windows.enumerated()), id: \.element.id) { index, window in
                Button {
                    watchlistManager.focusWindow(at: index)
                } label: {
                    HStack {
                        if let icon = window.appIcon {
                            Image(nsImage: icon)
                        }
                        Text(window.displayTitle)
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
                    selectedPosition = position
                    PalettePosition.stored = position
                } label: {
                    HStack {
                        Text(position.displayName)
                        if position == selectedPosition {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        if !watchlistManager.windows.isEmpty {
            Button("Clear All", role: .destructive) {
                watchlistManager.clearAll()
            }
        }

        Divider()

        Text("⌃⌥M mark · ⌃⌥N cycle · ⌃⌥L exposé")
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Button("Quit WindowMark") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
