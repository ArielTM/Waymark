import SwiftUI
import AppKit

struct ExposeView: View {
    let watchlistManager: WatchlistManager
    let dismiss: () -> Void
    var onThumbnailsFailed: (() -> Void)?

    @State private var selectedIndex: Int
    @State private var thumbnails: [CGWindowID: NSImage] = [:]
    @State private var loadingThumbnails = true

    init(watchlistManager: WatchlistManager, dismiss: @escaping () -> Void, onThumbnailsFailed: (() -> Void)? = nil) {
        self.watchlistManager = watchlistManager
        self.dismiss = dismiss
        self.onThumbnailsFailed = onThumbnailsFailed
        _selectedIndex = State(initialValue: watchlistManager.currentIndex)
    }

    private var columns: Int {
        switch watchlistManager.windows.count {
        case 1: return 1
        case 2...3: return 2
        default: return 3
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(280), spacing: 20), count: columns)
    }

    var body: some View {
        ZStack {
            // Click-to-dismiss background
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(spacing: 24) {
                Spacer()

                LazyVGrid(columns: gridColumns, spacing: 20) {
                    ForEach(Array(watchlistManager.windows.enumerated()), id: \.element.id) { index, window in
                        WindowThumbnailCell(
                            window: window,
                            index: index,
                            isSelected: index == selectedIndex,
                            thumbnail: thumbnails[window.id]
                        )
                        .onTapGesture {
                            watchlistManager.focusWindow(at: index)
                            dismiss()
                        }
                    }
                }

                // Keyboard hints
                Text("← → ↑ ↓ navigate · Enter to focus · 1-9 jump · Esc to dismiss")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 8)

                Spacer()
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.return) {
            watchlistManager.focusWindow(at: selectedIndex)
            dismiss()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -columns)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: columns)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456789")) { press in
            if let char = press.characters.first,
               let num = Int(String(char)),
               num >= 1, num <= watchlistManager.windows.count {
                watchlistManager.focusWindow(at: num - 1)
                dismiss()
                return .handled
            }
            return .ignored
        }
        .task {
            await loadThumbnails()
        }
    }

    private func moveSelection(by offset: Int) {
        let count = watchlistManager.windows.count
        guard count > 0 else { return }
        let newIndex = selectedIndex + offset
        if newIndex >= 0 && newIndex < count {
            selectedIndex = newIndex
        }
    }

    private func loadThumbnails() async {
        var successCount = 0
        for window in watchlistManager.windows {
            let image = await watchlistManager.windowManager.captureThumbnail(
                for: window,
                size: CGSize(width: 280, height: 175)
            )
            if let image {
                thumbnails[window.id] = image
                successCount += 1
            }
        }
        loadingThumbnails = false

        // If no thumbnails loaded, Screen Recording permission is likely missing
        if successCount == 0 && !watchlistManager.windows.isEmpty {
            onThumbnailsFailed?()
        }
    }
}

// MARK: - Thumbnail Cell

struct WindowThumbnailCell: View {
    let window: WatchedWindow
    let index: Int
    let isSelected: Bool
    let thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail area
            ZStack(alignment: .topLeading) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 175)
                        .clipped()
                } else {
                    // Placeholder: app icon on dark background
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 280, height: 175)
                        .overlay {
                            VStack(spacing: 8) {
                                if let icon = window.appIcon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                } else {
                                    Image(systemName: "macwindow")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white.opacity(0.2))
                                }
                                Text("Screenshot unavailable")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                }

                // Number badge
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.blue : Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }

            // App info bar
            HStack(spacing: 8) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(window.appName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(window.title)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.white.opacity(isSelected ? 0.08 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .contentShape(Rectangle())
    }
}
