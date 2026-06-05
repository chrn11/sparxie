import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var session: MihomoSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 仪表盘概览卡片
                    if let traffic = session.traffic {
                        TrafficCard(upload: traffic.up, download: traffic.down,
                                    uploadTotal: traffic.upTotal, downloadTotal: traffic.downTotal)
                    }

                    if let memory = session.memory {
                        MemoryCard(inUse: memory.inuse, osLimit: memory.oslimit)
                    }

                    if let version = session.versionString {
                        VersionCard(version: version)
                    }

                    // 快捷操作
                    QuickActionsCard()
                }
                .padding()
            }
            .navigationTitle("仪表盘")
        }
    }
}

// MARK: - Sub-views

struct TrafficCard: View {
    let upload: Int64
    let download: Int64
    let uploadTotal: Int64
    let downloadTotal: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("流量统计")
                .font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Label("↑ \(formatBytes(uploadTotal))", systemImage: "arrow.up")
                    Label("↓ \(formatBytes(downloadTotal))", systemImage: "arrow.down")
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(formatSpeed(upload))/s")
                        .foregroundColor(.blue)
                    Text("\(formatSpeed(download))/s")
                        .foregroundColor(.green)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatSpeed(_ bytesPerSec: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytesPerSec, countStyle: .file) + "/s"
    }
}

struct MemoryCard: View {
    let inUse: Int64
    let osLimit: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内存使用")
                .font(.headline)
            Text("\(ByteCountFormatter.string(fromByteCount: inUse, countStyle: .memory))" +
                 (osLimit > 0 ? " / \(ByteCountFormatter.string(fromByteCount: osLimit, countStyle: .memory))" : ""))
                .font(.subheadline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct VersionCard: View {
    let version: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("核心版本")
                .font(.headline)
            Text(version)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷操作")
                .font(.headline)
            HStack(spacing: 12) {
                ActionButton(title: "重载配置", icon: "arrow.clockwise")
                ActionButton(title: "更新 Geo", icon: "globe")
                ActionButton(title: "重启核心", icon: "power")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    var body: some View {
        Button(action: {}) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    DashboardView()
        .environmentObject(MihomoSession())
}