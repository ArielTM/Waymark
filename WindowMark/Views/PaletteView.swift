import SwiftUI

struct PaletteView: View {
    let windows: [WatchedWindow]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if windows.isEmpty {
                Text("No marked windows")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(8)
            } else {
                ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                    Button {
                        onSelect(index)
                    } label: {
                        HStack(spacing: 8) {
                            if let icon = window.appIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(window.displayTitle)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .font(.system(size: 12))
                            Spacer()
                            if index == currentIndex {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(index == currentIndex ? Color.white.opacity(0.05) : Color.clear)
                }
            }
        }
        .frame(width: 220)
    }
}
