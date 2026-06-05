import Foundation
import Combine

@MainActor
class MihomoSession: ObservableObject {
    @Published var traffic: TrafficSample?
    @Published var memory: MemorySample?
    @Published var versionString: String?
    @Published var versionInfo: VersionInfo?
    @Published var proxyCatalog: ProxyCatalog?
    @Published var connectionsFrame: ConnectionsFrame?
    @Published var connectionGroups: [ConnectionGroup] = []
    @Published var rulesSummary: RulesSummary?
    @Published var ruleEntries: [RuleEntry] = []
    @Published var logEntries: [LogEntry] = []
    @Published var proxyProviders: [ProxyProviderEntry] = []
    @Published var ruleProviders: [RuleProviderEntry] = []
    @Published var configJson: String?
    @Published var errorMessage: String?
    @Published var isLoading = false

    var targetHandle: SparxieTargetHandle?
    private var trafficTask: Task<Void, Never>?
    private var memoryTask: Task<Void, Never>?
    private var connectionsTask: Task<Void, Never>?
    private var logsTask: Task<Void, Never>?

    // MARK: - Controller Management

    func connect(_ controller: Controller) async {
        isLoading = true
        errorMessage = nil

        // Clean up previous connection
        disconnect()

        let handle = await RustCore.shared.createTarget(
            baseUrl: controller.baseUrl,
            secret: controller.secret,
            allowInsecure: controller.allowInsecure
        )
        self.targetHandle = handle

        do {
            // Initialize cache
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.path
            _ = await RustCore.shared.initialize(cacheDir: cacheDir)

            // Fetch version info
            self.versionInfo = try await RustCore.shared.versionInfo(target: handle)
            self.versionString = self.versionInfo?.version

            // Start streams
            startTrafficStream()
            startMemoryStream()
            startConnectionsStream()

            // Fetch initial data
            await refreshProxyCatalog()
            await refreshProviders()

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func disconnect() {
        guard let handle = targetHandle else { return }
        targetHandle = nil
        trafficTask?.cancel()
        memoryTask?.cancel()
        connectionsTask?.cancel()
        logsTask?.cancel()
        trafficTask = nil
        memoryTask = nil
        connectionsTask = nil
        logsTask = nil
        Task {
            await RustCore.shared.stopTargetStreams(target: handle)
            await RustCore.shared.freeTarget(handle)
        }
    }

    // MARK: - Stream Subscriptions

    private func startTrafficStream() {
        guard let handle = targetHandle else { return }
        trafficTask = Task {
            for await sample in await RustCore.shared.trafficStream(target: handle) {
                self.traffic = sample
            }
        }
    }

    private func startMemoryStream() {
        guard let handle = targetHandle else { return }
        memoryTask = Task {
            for await sample in await RustCore.shared.memoryStream(target: handle) {
                self.memory = sample
            }
        }
    }

    private func startConnectionsStream() {
        guard let handle = targetHandle else { return }
        connectionsTask = Task {
            for await frame in await RustCore.shared.connectionsStream(target: handle, intervalMs: 1000) {
                self.connectionsFrame = frame
            }
        }
    }

    func startLogsStream(level: String = "info") {
        guard let handle = targetHandle else { return }
        logsTask?.cancel()
        logsTask = Task {
            for await entries in await RustCore.shared.logsStream(target: handle, level: level) {
                self.logEntries.append(contentsOf: entries)
                // Keep last 500 entries
                if self.logEntries.count > 500 {
                    self.logEntries.removeFirst(self.logEntries.count - 500)
                }
            }
        }
    }

    func clearLogs(level: String = "info") {
        guard let handle = targetHandle else { return }
        Task { await RustCore.shared.clearLogs(target: handle, level: level) }
        logEntries.removeAll()
    }

    // MARK: - Data Fetching

    func refreshProxyCatalog() async {
        guard let handle = targetHandle else { return }
        do {
            self.proxyCatalog = try await RustCore.shared.proxyCatalog(target: handle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshProviders() async {
        guard let handle = targetHandle else { return }
        do {
            self.proxyProviders = try await RustCore.shared.proxyProviderCatalog(target: handle)
            self.ruleProviders = try await RustCore.shared.ruleProviderCatalog(target: handle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectProxy(group: String, name: String) async {
        guard let handle = targetHandle else { return }
        do {
            try await RustCore.shared.selectProxy(target: handle, group: group, name: name)
            await refreshProxyCatalog()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeConnection(id: String) async {
        guard let handle = targetHandle else { return }
        do {
            try await RustCore.shared.closeConnection(target: handle, id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeAllConnections() async {
        guard let handle = targetHandle else { return }
        do {
            try await RustCore.shared.closeAllConnections(target: handle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadRules(filter: String = "") async {
        guard let handle = targetHandle else { return }
        do {
            self.rulesSummary = try await RustCore.shared.rulesLoad(target: handle, filter: filter)
            if let summary = self.rulesSummary {
                self.ruleEntries = try await RustCore.shared.rulesWindow(target: handle, offset: 0, limit: UInt32(summary.filtered))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProvider(name: String, isRule: Bool) async {
        guard let handle = targetHandle else { return }
        do {
            if isRule {
                try await RustCore.shared.ruleProviderUpdate(target: handle, name: name)
            } else {
                try await RustCore.shared.proxyProviderUpdate(target: handle, name: name)
            }
            await refreshProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadConfig() async {
        guard let handle = targetHandle else { return }
        do {
            self.configJson = try await RustCore.shared.configs(target: handle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func patchConfig(body: String) async {
        guard let handle = targetHandle else { return }
        do {
            try await RustCore.shared.patchConfigs(target: handle, bodyJson: body)
            await loadConfig()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadConfig(path: String? = nil, payload: String? = nil, force: Bool = false) async {
        guard let handle = targetHandle else { return }
        do {
            try await RustCore.shared.reloadConfigs(target: handle, path: path, payload: payload, force: force)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restartCore() async {
        guard let handle = targetHandle else { return }
        do {
            try await RustCore.shared.restartCore(target: handle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateGeo() async {
        guard let handle = targetHandle else { return }
        do {
            try await RustCore.shared.updateGeo(target: handle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upgradeCore(channel: String? = nil, force: Bool = false) async {
        guard let handle = targetHandle else { return }
        do {
            try await RustCore.shared.upgradeCore(target: handle, channel: channel, force: force)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}