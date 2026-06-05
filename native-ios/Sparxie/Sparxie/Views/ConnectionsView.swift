import SwiftUI

struct ConnectionsView: View {
    @EnvironmentObject var session: MihomoSession
    @State private var showClosed = false
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            List {
                if let frame = session.connectionsFrame {
                    Section("活跃连接 (\(frame.activeCount))") {
                        ConnectionSummaryRow(upload: frame.uploadTotal, download: frame.downloadTotal)
                    }
                }
                ForEach(session.connectionGroups) { group in
                    Section(group.name) {
                        Text("\(group.count) 个连接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索连接")
            .navigationTitle("连接")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { Task { await session.closeAllConnections() } }) {
                        Image(systemName: "xmark.circle")
                    }
                    Button(action: { showClosed.toggle() }) {
                        Image(systemName: showClosed ? "eye" : "eye.slash")
                    }
                }
            }
        }
    }
}

struct ConnectionSummaryRow: View {
    let upload: Int64
    let download: Int64
    var body: some View {
        HStack {
            Label(ByteCountFormatter.string(fromByteCount: upload, countStyle: .file), systemImage: "arrow.up")
            Spacer()
            Label(ByteCountFormatter.string(fromByteCount: download, countStyle: .file), systemImage: "arrow.down")
        }
        .font(.subheadline)
    }
}

#Preview {
    ConnectionsView()
        .environmentObject(MihomoSession())
}