import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: MihomoSession
    @StateObject private var store = ControllerStore()
    @State private var showingAddController = false
    @State private var showingCoreActions = false

    var body: some View {
        NavigationView {
            List {
                // 当前控制器
                Section("当前控制器") {
                    if let active = store.activeController {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(active.name)
                                .font(.headline)
                            Text(active.baseUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("未连接")
                            .foregroundColor(.secondary)
                    }
                }

                // 控制器管理
                Section("控制器列表") {
                    ForEach(store.controllers) { controller in
                        ControllerRow(controller: controller, isActive: controller.id == store.activeControllerId) {
                            store.activate(controller)
                            Task { await session.connect(controller) }
                        } onDelete: {
                            store.delete(controller)
                        }
                    }
                }

                // 快捷导航
                Section("高级") {
                    NavigationLink("核心配置") {
                        CoreConfigView()
                    }
                    NavigationLink("核心操作") {
                        CoreActionsView()
                    }
                    Button("清除图标缓存") {
                        Task { try? await RustCore.shared.clearIconCache() }
                    }
                }

                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddController = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddController) {
                AddControllerView(store: store)
            }
        }
    }
}

struct ControllerRow: View {
    let controller: Controller
    let isActive: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isActive ? .blue : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.name)
                    .font(.body)
                Text(controller.baseUrl)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
    }
}

struct AddControllerView: View {
    @ObservedObject var store: ControllerStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var baseUrl = ""
    @State private var secret = ""
    @State private var allowInsecure = false

    var body: some View {
        NavigationView {
            Form {
                TextField("名称", text: $name)
                TextField("地址（如 http://192.168.1.1:9090）", text: $baseUrl)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                SecureField("密钥（可选）", text: $secret)
                Toggle("允许不安全连接", isOn: $allowInsecure)
            }
            .navigationTitle("添加控制器")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let controller = Controller(
                            name: name.isEmpty ? baseUrl : name,
                            baseUrl: baseUrl.hasPrefix("http") ? baseUrl : "http://\(baseUrl)",
                            secret: secret.isEmpty ? nil : secret,
                            allowInsecure: allowInsecure
                        )
                        store.add(controller)
                        dismiss()
                    }
                    .disabled(baseUrl.isEmpty)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MihomoSession())
}