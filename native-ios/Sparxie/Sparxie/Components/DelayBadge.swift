import SwiftUI

/// 代理节点延迟徽章，根据延迟值显示不同颜色。
struct DelayBadge: View {
    let delay: Int

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private var label: String {
        switch delay {
        case ..<0: return "超时"
        case 0: return "未测试"
        default: return "\(delay)ms"
        }
    }

    private var color: Color {
        switch delay {
        case ..<0: return .red
        case 0: return .gray
        case 1...200: return .green
        case 201...500: return .orange
        default: return .red
        }
    }
}

#Preview("Delay variants") {
    HStack {
        DelayBadge(delay: 45)
        DelayBadge(delay: 350)
        DelayBadge(delay: 1200)
        DelayBadge(delay: -1)
        DelayBadge(delay: 0)
    }
    .padding()
}