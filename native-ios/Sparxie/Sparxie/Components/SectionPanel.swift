import SwiftUI

/// 通用圆角面板容器，用于页面内分区块展示内容。
struct SectionPanel<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content

    init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            content
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 16) {
        SectionPanel(title: "流量", icon: "chart.bar") {
            Text("↑ 1.2 MB  ↓ 45.6 MB")
                .font(.subheadline)
        }
        SectionPanel(title: "内存") {
            Text("42.3 MB / 256 MB")
                .font(.subheadline)
        }
    }
    .padding()
}