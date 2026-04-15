import SwiftUI

struct PaletteView: View {
    let targets: [WatchTarget]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if targets.isEmpty {
                Text("No marked windows")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(8)
            } else {
                ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                    Button {
                        onSelect(index)
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
