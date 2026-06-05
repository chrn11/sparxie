import SwiftUI

struct RulesView: View {
    @EnvironmentObject var session: MihomoSession
    @State private var filter = ""
    @State private var ruleEntries: [RuleEntry] = []

    var body: some View {
        NavigationStack {
            List(ruleEntries) { rule in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(rule.ruleType)
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        Text(rule.payload)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    HStack {
                        Text("→ \(rule.proxy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("命中 \(rule.hitCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("规则")
            .searchable(text: $filter, prompt: "搜索规则")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await loadRules() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func loadRules() async {
        guard let handle = session.targetHandle else { return }
        do {
            let summary = try await RustCore.shared.rulesLoad(target: handle, filter: filter)
            session.rulesSummary = summary
            ruleEntries = try await RustCore.shared.rulesWindow(target: handle, offset: 0, limit: UInt32(summary.filtered))
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RulesView()
        .environmentObject(MihomoSession())
}