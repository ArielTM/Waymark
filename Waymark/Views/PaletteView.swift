import SwiftUI

struct PaletteView: View {
    let watchlistManager: WatchlistManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if watchlistManager.targets.isEmpty {
                Text("No marked windows")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(8)
            } else {
                ForEach(Array(watchlistManager.targets.enumerated()), id: \.element.id) { index, target in
                    Button {
                        watchlistManager.focusTarget(at: index)
                    } label: {
                        HStack(spacing: 8) {
                            if let icon = target.appIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(target.displayTitle)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .font(.system(size: 12))
                            Spacer()
                            if index == watchlistManager.currentIndex {
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
                    .background(index == watchlistManager.currentIndex ? Color.white.opacity(0.05) : Color.clear)
                }
            }
        }
        .frame(width: 220)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
