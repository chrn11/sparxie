import SwiftUI

struct CoreActionsView: View {
    @EnvironmentObject var session: MihomoSession
    @State private var isReloading = false
    @State private var isUpdatingGeo = false
    @State private var isRestarting = false

    var body: some View {
        NavigationView {
            List {
                Section("配置操作") {
                    Button(action: reloadConfig) {
                        Label("重载配置", systemImage: "arrow.clockwise")
                    }
                    .disabled(isReloading)

                    Button(action: updateGeo) {
                        Label("更新 Geo 数据", systemImage: "globe")
                    }
                    .disabled(isUpdatingGeo)

                    Button(action: flushFakeip) {
                        Label("清空 FakeIP 缓存", systemImage: "internaldrive")
                    }

                    Button(action: flushDns) {
                        Label("清空 DNS 缓存", systemImage: "network")
                    }
                }

                Section("核心操作") {
                    Button(action: restartCore) {
                        Label("重启核心", systemImage: "power")
                    }
                    .disabled(isRestarting)

                    Button(action: upgradeCore) {
                        Label("检查更新", systemImage: "arrow.down.circle")
                    }
                }
            }
            .navigationTitle("核心操作")
        }
    }

    private func reloadConfig() {
        isReloading = true
        Task {
            await session.reloadConfig()
            isReloading = false
        }
    }

    private func updateGeo() {
        isUpdatingGeo = true
        Task {
            await session.updateGeo()
            isUpdatingGeo = false
        }
    }

    private func flushFakeip() {
        guard let handle = session.targetHandle else { return }
        Task { try? await RustCore.shared.flushFakeip(target: handle) }
    }

    private func flushDns() {
        guard let handle = session.targetHandle else { return }
        Task { try? await RustCore.shared.flushDns(target: handle) }
    }

    private func restartCore() {
        isRestarting = true
        Task {
            await session.restartCore()
            isRestarting = false
        }
    }

    private func upgradeCore() {
        Task { await session.upgradeCore() }
    }
}

#Preview {
    CoreActionsView()
        .environmentObject(MihomoSession())
}