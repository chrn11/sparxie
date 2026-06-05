import SwiftUI

struct CoreConfigView: View {
    @EnvironmentObject var session: MihomoSession
    @State private var configText = ""
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            VStack {
                if isEditing {
                    TextEditor(text: $configText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                } else {
                    ScrollView {
                        Text(configText)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle("核心配置")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { Task { await loadConfig() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button(isEditing ? "保存" : "编辑") {
                        if isEditing {
                            Task { await saveConfig() }
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
    }

    private func loadConfig() async {
        guard let handle = session.targetHandle else { return }
        do {
            configText = try await RustCore.shared.configs(target: handle)
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }

    private func saveConfig() async {
        guard let handle = session.targetHandle else { return }
        do {
            try await RustCore.shared.patchConfigs(target: handle, bodyJson: configText)
            isEditing = false
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CoreConfigView()
        .environmentObject(MihomoSession())
}