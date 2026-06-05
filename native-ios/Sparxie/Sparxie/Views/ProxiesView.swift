import SwiftUI

struct ProxiesView: View {
    @EnvironmentObject var session: MihomoSession
    @State private var searchText = ""
    @State private var isTesting = false

    var filteredGroups: [ProxyGroupEntry] {
        guard let catalog = session.proxyCatalog else { return [] }
        if searchText.isEmpty { return catalog.groups }
        return catalog.groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            List(filteredGroups) { group in
                NavigationLink(destination: ProxyGroupDetailView(group: group)) {
                    HStack {
                        Text(group.name)
                            .font(.body)
                        Spacer()
                        Text(group.now)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(group.memberCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索代理组")
            .navigationTitle("代理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await session.refreshProxyCatalog() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if session.proxyCatalog == nil {
                    ProgressView("加载中…")
                }
            }
        }
    }
}

struct ProxyGroupDetailView: View {
    let group: ProxyGroupEntry
    @EnvironmentObject var session: MihomoSession
    @State private var members: [ProxyMemberEntry] = []
    @State private var isLoading = false

    var body: some View {
        List(members) { member in
            HStack {
                Text(member.name)
                Spacer()
                DelayBadge(delay: member.delay)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Task { await session.selectProxy(group: group.name, name: member.name) }
            }
        }
        .navigationTitle(group.name)
        .task { await loadMembers() }
    }

    private func loadMembers() async {
        guard let handle = session.targetHandle else { return }
        isLoading = true
        members = (try? await RustCore.shared.proxyGroupMembers(
            target: handle, group: group.name, offset: 0, limit: 200, memberSort: 0)) ?? []
        isLoading = false
    }
}

#Preview {
    ProxiesView()
        .environmentObject(MihomoSession())
}