import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: MihomoSession
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("仪表盘", systemImage: "gauge.open.withLines.needle.33percent") }
                .tag(0)

            ProxiesView()
                .tabItem { Label("代理", systemImage: "network") }
                .tag(1)

            ConnectionsView()
                .tabItem { Label("连接", systemImage: "link") }
                .tag(2)

            RulesView()
                .tabItem { Label("规则", systemImage: "list.bullet.rectangle") }
                .tag(3)

            LogsView()
                .tabItem { Label("日志", systemImage: "text.alignleft") }
                .tag(4)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(5)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MihomoSession())
}