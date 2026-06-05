import Foundation

// MARK: - C ABI Callback Types

typealias SparxieCallback = @convention(c) (_ result: UnsafePointer<CChar>?, _ error: UnsafePointer<CChar>?) -> Void
typealias SparxieStreamCallback = @convention(c) (_ data: UnsafePointer<CChar>?, _ done: Bool) -> Void

// MARK: - RustCore Actor

/// Thread-safe wrapper around the Rust C ABI.
/// All calls are serialized through this actor to ensure thread safety.
actor RustCore {
    static let shared = RustCore()

    private init() {
        sparxie_init_app()
    }

    // MARK: - Cache Init

    func initialize(cacheDir: String) -> Int32 {
        cacheDir.withCString { sparxie_init_cache($0) }
    }

    // MARK: - Target Lifecycle

    func createTarget(baseUrl: String, secret: String? = nil, allowInsecure: Bool = false) -> SparxieTargetHandle {
        let secretC = secret?.withCString { $0 }
        guard let ptr = baseUrl.withCString({ urlPtr in
            secretC.flatMap { secPtr in
                sparxie_target_create(urlPtr, secPtr, allowInsecure)
            } ?? sparxie_target_create(urlPtr, nil, allowInsecure)
        }) else {
            fatalError("Failed to create SparxieTarget")
        }
        return SparxieTargetHandle(ptr: ptr)
    }

    func freeTarget(_ handle: SparxieTargetHandle) {
        sparxie_target_free(handle.ptr)
    }

    // MARK: - Version

    func version(target: SparxieTargetHandle) async throws -> String {
        try await asyncCall { callback in
            sparxie_version(target.ptr, callback)
        }
    }

    func versionInfo(target: SparxieTargetHandle) async throws -> VersionInfo {
        let json = try await asyncCall { callback in
            sparxie_version_info(target.ptr, callback)
        }
        return try JSONDecoder().decode(VersionInfo.self, from: Data(json.utf8))
    }

    // MARK: - Proxies

    func proxyCatalog(target: SparxieTargetHandle, includeHidden: Bool = false, filter: String = "") async throws -> ProxyCatalog {
        let json = try await asyncCall { callback in
            filter.withCString { filterC in
                sparxie_proxy_catalog(target.ptr, includeHidden, filterC, callback)
            }
        }
        return try JSONDecoder().decode(ProxyCatalog.self, from: Data(json.utf8))
    }

    func selectProxy(target: SparxieTargetHandle, group: String, name: String) async throws {
        try await asyncUnit { callback in
            group.withCString { groupC in
                name.withCString { nameC in
                    sparxie_select_proxy(target.ptr, groupC, nameC, callback)
                }
            }
        }
    }

    func proxyGroupMembers(target: SparxieTargetHandle, group: String, offset: UInt32, limit: UInt32, memberSort: Int32) async throws -> [ProxyMemberEntry] {
        let json = try await asyncCall { callback in
            group.withCString { groupC in
                sparxie_proxy_group_members(target.ptr, groupC, offset, limit, memberSort, callback)
            }
        }
        return try JSONDecoder().decode([ProxyMemberEntry].self, from: Data(json.utf8))
    }

    func proxyDelay(target: SparxieTargetHandle, name: String, testUrl: String, timeoutMs: UInt32) async throws -> Int64 {
        let result = try await asyncCall { callback in
            name.withCString { nameC in
                testUrl.withCString { urlC in
                    sparxie_proxy_delay(target.ptr, nameC, urlC, timeoutMs, nil, callback)
                }
            }
        }
        return Int64(result) ?? 0
    }

    // MARK: - Connections

    func connectionsStream(target: SparxieTargetHandle, intervalMs: UInt32) -> AsyncStream<ConnectionsFrame> {
        AsyncStream { continuation in
            let callback: SparxieStreamCallback = { dataC, done in
                if done {
                    continuation.finish()
                    return
                }
                guard let dataC = dataC else { return }
                let json = String(cString: dataC)
                if let data = json.data(using: .utf8),
                   let frame = try? JSONDecoder().decode(ConnectionsFrame.self, from: data) {
                    continuation.yield(frame)
                }
            }
            sparxie_connections_stream(target.ptr, intervalMs, callback)
        }
    }

    func trafficStream(target: SparxieTargetHandle) -> AsyncStream<TrafficSample> {
        AsyncStream { continuation in
            let callback: SparxieStreamCallback = { dataC, done in
                if done {
                    continuation.finish()
                    return
                }
                guard let dataC = dataC else { return }
                let json = String(cString: dataC)
                if let data = json.data(using: .utf8),
                   let sample = try? JSONDecoder().decode(TrafficSample.self, from: data) {
                    continuation.yield(sample)
                }
            }
            sparxie_traffic_stream(target.ptr, callback)
        }
    }

    func memoryStream(target: SparxieTargetHandle) -> AsyncStream<MemorySample> {
        AsyncStream { continuation in
            let callback: SparxieStreamCallback = { dataC, done in
                if done {
                    continuation.finish()
                    return
                }
                guard let dataC = dataC else { return }
                let json = String(cString: dataC)
                if let data = json.data(using: .utf8),
                   let sample = try? JSONDecoder().decode(MemorySample.self, from: data) {
                    continuation.yield(sample)
                }
            }
            sparxie_memory_stream(target.ptr, callback)
        }
    }

    func logsStream(target: SparxieTargetHandle, level: String) -> AsyncStream<[LogEntry]> {
        AsyncStream { continuation in
            let callback: SparxieStreamCallback = { dataC, done in
                if done {
                    continuation.finish()
                    return
                }
                guard let dataC = dataC else { return }
                let json = String(cString: dataC)
                if let data = json.data(using: .utf8),
                   let entries = try? JSONDecoder().decode([LogEntry].self, from: data) {
                    continuation.yield(entries)
                }
            }
            level.withCString { levelC in
                sparxie_logs_stream(target.ptr, levelC, callback)
            }
        }
    }

    func clearLogs(target: SparxieTargetHandle, level: String) {
        level.withCString { levelC in
            sparxie_clear_logs(target.ptr, levelC)
        }
    }

    func closeConnection(target: SparxieTargetHandle, id: String) async throws {
        try await asyncUnit { callback in
            id.withCString { idC in
                sparxie_close_connection(target.ptr, idC, callback)
            }
        }
    }

    func closeAllConnections(target: SparxieTargetHandle) async throws {
        try await asyncUnit { callback in
            sparxie_close_all_connections(target.ptr, callback)
        }
    }

    func stopTargetStreams(target: SparxieTargetHandle) {
        sparxie_stop_target_streams(target.ptr)
    }

    // MARK: - Configs

    func configs(target: SparxieTargetHandle) async throws -> String {
        try await asyncCall { callback in
            sparxie_configs(target.ptr, callback)
        }
    }

    func patchConfigs(target: SparxieTargetHandle, bodyJson: String) async throws {
        try await asyncUnit { callback in
            bodyJson.withCString { jsonC in
                sparxie_patch_configs(target.ptr, jsonC, callback)
            }
        }
    }

    func reloadConfigs(target: SparxieTargetHandle, path: String? = nil, payload: String? = nil, force: Bool = false) async throws {
        try await asyncUnit { callback in
            let pathC = path ?? ""
            let payloadC = payload ?? ""
            pathC.withCString { pathPtr in
                payloadC.withCString { payloadPtr in
                    sparxie_reload_configs(target.ptr, pathPtr, payloadPtr, force, callback)
                }
            }
        }
    }

    // MARK: - Providers

    func proxyProviderCatalog(target: SparxieTargetHandle) async throws -> [ProxyProviderEntry] {
        let json = try await asyncCall { callback in
            sparxie_proxy_provider_catalog(target.ptr, callback)
        }
        return try JSONDecoder().decode([ProxyProviderEntry].self, from: Data(json.utf8))
    }

    func proxyProviderUpdate(target: SparxieTargetHandle, name: String) async throws {
        try await asyncUnit { callback in
            name.withCString { nameC in
                sparxie_proxy_provider_update(target.ptr, nameC, callback)
            }
        }
    }

    func ruleProviderCatalog(target: SparxieTargetHandle) async throws -> [RuleProviderEntry] {
        let json = try await asyncCall { callback in
            sparxie_rule_provider_catalog(target.ptr, callback)
        }
        return try JSONDecoder().decode([RuleProviderEntry].self, from: Data(json.utf8))
    }

    func ruleProviderUpdate(target: SparxieTargetHandle, name: String) async throws {
        try await asyncUnit { callback in
            name.withCString { nameC in
                sparxie_rule_provider_update(target.ptr, nameC, callback)
            }
        }
    }

    // MARK: - Cache

    func flushFakeip(target: SparxieTargetHandle) async throws {
        try await asyncUnit { callback in
            sparxie_flush_fakeip(target.ptr, callback)
        }
    }

    func flushDns(target: SparxieTargetHandle) async throws {
        try await asyncUnit { callback in
            sparxie_flush_dns(target.ptr, callback)
        }
    }

    func iconCacheSize() async throws -> UInt64 {
        let result = try await asyncCall { callback in
            sparxie_icon_cache_size(callback)
        }
        return UInt64(result) ?? 0
    }

    func clearIconCache() async throws {
        try await asyncUnit { callback in
            sparxie_clear_icon_cache(callback)
        }
    }

    // MARK: - Upgrade

    func upgradeCore(target: SparxieTargetHandle, channel: String? = nil, force: Bool = false) async throws {
        try await asyncUnit { callback in
            channel.withCString { channelC in
                sparxie_upgrade_core(target.ptr, channelC, force, callback)
            }
        }
    }

    func restartCore(target: SparxieTargetHandle) async throws {
        try await asyncUnit { callback in
            sparxie_restart_core(target.ptr, callback)
        }
    }

    func updateGeo(target: SparxieTargetHandle) async throws {
        try await asyncUnit { callback in
            sparxie_update_geo(target.ptr, callback)
        }
    }

    // MARK: - Rules

    func rulesLoad(target: SparxieTargetHandle, filter: String) async throws -> RulesSummary {
        let json = try await asyncCall { callback in
            filter.withCString { filterC in
                sparxie_rules_load(target.ptr, filterC, callback)
            }
        }
        return try JSONDecoder().decode(RulesSummary.self, from: Data(json.utf8))
    }

    func rulesWindow(target: SparxieTargetHandle, offset: UInt32, limit: UInt32) async throws -> [RuleEntry] {
        let json = try await asyncCall { callback in
            sparxie_rules_window(target.ptr, offset, limit, callback)
        }
        return try JSONDecoder().decode([RuleEntry].self, from: Data(json.utf8))
    }

    // MARK: - Private Helpers

    private func asyncCall(_ block: (SparxieCallback) -> Void) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let boxed = Box(continuation)
            let callback: SparxieCallback = { resultC, errorC in
                defer { releaseBox(boxed) }
                if let errorC = errorC {
                    let errorStr = String(cString: errorC)
                    continuation.resume(throwing: RustError.generic(errorStr))
                } else if let resultC = resultC {
                    continuation.resume(returning: String(cString: resultC))
                } else {
                    continuation.resume(throwing: RustError.nullPointer)
                }
            }
            block(callback)
        }
    }

    private func asyncUnit(_ block: (SparxieCallback) -> Void) async throws {
        _ = try await asyncCall(block)
    }
}

// MARK: - Supporting Types

/// Wrapper for opaque target pointer.
struct SparxieTargetHandle {
    let ptr: OpaquePointer
}

/// Box for storing continuation across C callback boundaries.
final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}

private func releaseBox<T>(_ box: Box<T>) {
    // Prevents premature deallocation
    _ = box
}

enum RustError: Error {
    case generic(String)
    case nullPointer
    case jsonDecodeError(String)
}