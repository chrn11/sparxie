import SwiftUI

/// 代理节点头像，显示类型首字母或自定义图标。
struct ProxyAvatar: View {
    let name: String
    let proxyType: String
    let iconUrl: String?

    var body: some View {
        Group {
            if let urlString = iconUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure, .empty:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
            Text(String(typeInitial))
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    private var typeInitial: String {
        let mapping: [String: String] = [
            "Shadowsocks": "SS", "ss": "SS",
            "VMess": "VM", "vmess": "VM",
            "VLESS": "VL", "vless": "VL",
            "Trojan": "TR", "trojan": "TR",
            "Hysteria": "HY", "hysteria": "HY",
            "Hysteria2": "H2", "hysteria2": "H2",
            "TUIC": "TU", "tuic": "TU",
            "WireGuard": "WG", "wireguard": "WG",
            "Direct": "DR", "direct": "DR",
            "Reject": "RJ", "reject": "RJ",
            "Compatible": "CP", "compatible": "CP",
            "URLTest": "UT", "urltest": "UT",
            "Fallback": "FB", "fallback": "FB",
            "LoadBalance": "LB", "loadbalance": "LB",
            "Selector": "SL", "selector": "SL",
        ]
        return mapping[proxyType] ?? String(proxyType.prefix(2)).uppercased()
    }

    private var backgroundColor: Color {
        switch proxyType.lowercased() {
        case "shadowsocks", "ss": return .blue
        case "vmess": return .indigo
        case "vless": return .purple
        case "trojan": return .orange
        case "hysteria", "hysteria2": return .pink
        case "tuic": return .teal
        case "wireguard": return .cyan
        case "direct": return .green
        case "reject": return .red
        default: return .gray
        }
    }
}

#Preview("Avatar variants") {
    HStack(spacing: 16) {
        ProxyAvatar(name: "东京", proxyType: "Shadowsocks", iconUrl: nil)
        ProxyAvatar(name: "新加坡", proxyType: "VMess", iconUrl: nil)
        ProxyAvatar(name: "直连", proxyType: "Direct", iconUrl: nil)
        ProxyAvatar(name: "自动", proxyType: "URLTest", iconUrl: nil)
        ProxyAvatar(name: "选择", proxyType: "Selector", iconUrl: nil)
    }
    .padding()
}