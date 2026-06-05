import SwiftUI

struct LogsView: View {
    @EnvironmentObject var session: MihomoSession
    @State private var isPaused = false
    @State private var autoScroll = true

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(session.logEntries) { entry in
                    HStack(alignment: .top, spacing: 6) {
                        Text(entry.level.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(logLevelColor(entry.level))
                            .frame(width: 40, alignment: .leading)
                        Text(entry.message)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .id(entry.id)
                }
                .onChange(of: session.logEntries.count) { _ in
                    if autoScroll, let last = session.logEntries.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .navigationTitle("日志")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { isPaused.toggle() }) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    }
                    Button(action: { session.clearLogs() }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .task {
            session.startLogsStream(level: "info")
        }
    }

    private func logLevelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "error": return .red
        case "warning": return .orange
        case "info": return .blue
        default: return .gray
        }
    }
}

#Preview {
    LogsView()
        .environmentObject(MihomoSession())
}