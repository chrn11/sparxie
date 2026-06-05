import SwiftUI

/// 连接详情行，显示单条活跃连接的摘要信息。
struct ConnectionTile: View {
    let id: String
    let host: String
    let destination: String
    let network: String
    let rule: String
    let upload: Int64
    let download: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(host)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text(network.uppercased())
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(3)
            }

            Text(destination)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            HStack {
                Text("规则: \(rule)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Label(ByteCountFormatter.string(fromByteCount: upload, countStyle: .file),
                          systemImage: "arrow.up")
                    Label(ByteCountFormatter.string(fromByteCount: download, countStyle: .file),
                          systemImage: "arrow.down")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ConnectionTile(
            id: "conn-1",
            host: "example.com:443",
            destination: "93.184.216.34:443",
            network: "tcp",
            rule: "DOMAIN-SUFFIX,example.com,DIRECT",
            upload: 1024,
            download: 524288
        )
    }
}