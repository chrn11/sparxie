import SwiftUI

struct ResourcesView: View {
    @EnvironmentObject var session: MihomoSession

    var body: some View {
        NavigationView {
            List {
                Section("代理订阅") {
                    ForEach(session.proxyProviders) { provider in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name)
                                    .font(.body)
                                Text(provider.vehicleType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if provider.updatable {
                                Button("更新") {
                                    Task { await session.updateProvider(name: provider.name, isRule: false) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                Section("规则集") {
                    ForEach(session.ruleProviders) { provider in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name)
                                    .font(.body)
                                Text("\(provider.vehicleType) · \(provider.behavior) · \(provider.ruleCount) 条")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if provider.updatable {
                                Button("更新") {
                                    Task { await session.updateProvider(name: provider.name, isRule: true) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .navigationTitle("资源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await session.refreshProviders() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

#Preview {
    ResourcesView()
        .environmentObject(MihomoSession())
}