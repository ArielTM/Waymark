import SwiftUI

struct MenuBarView: View {
    let watchlistManager: WatchlistManager

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

        if !watchlistManager.windows.isEmpty {
            Button("Clear All", role: .destructive) {
                watchlistManager.clearAll()
            }

            Divider()
        }

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
