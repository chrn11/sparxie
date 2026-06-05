import SwiftUI

/// 代理节点网格瓦片，显示名称、类型和延迟徽章。
struct ProxyNodeTile: View {
    let name: String
    let type: String
    let delay: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)

                HStack {
                    Text(type)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    DelayBadge(delay: delay)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Tiles") {
    let columns = [GridItem(.adaptive(minimum: 140))]
    return ScrollView {
        LazyVGrid(columns: columns, spacing: 8) {
            ProxyNodeTile(name: "东京节点", type: "Shadowsocks", delay: 85, isSelected: true) {}
            ProxyNodeTile(name: "新加坡", type: "VMess", delay: 210, isSelected: false) {}
            ProxyNodeTile(name: "美国节点", type: "Trojan", delay: 0, isSelected: false) {}
        }
        .padding()
    }
}