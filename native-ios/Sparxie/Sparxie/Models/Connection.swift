import Foundation

// MARK: - Connection (flat structure matching Rust)

struct Connection: Codable, Identifiable {
    let id: String
    let host: String
    let network: String
    let connType: String
    let sourceIp: String
    let sourcePort: Int
    let destinationIp: String
    let destinationPort: Int
    let inboundIp: String
    let inboundPort: Int
    let inboundName: String
    let dnsMode: String
    let uid: Int
    let process: String
    let processPath: String
    let specialProxy: String
    let specialRules: String
    let remoteDestination: String
    let sniffHost: String
    let rule: String
    let rulePayload: String
    let chains: [String]
    let connectionLogs: [String]
    let upload: Int64
    let download: Int64
    let uploadSpeed: Int64
    let downloadSpeed: Int64
    let start: String
    let isClosed: Bool

    enum CodingKeys: String, CodingKey {
        case id, host, network, connType = "type"
        case sourceIp, sourcePort, destinationIp, destinationPort
        case inboundIp, inboundPort, inboundName
        case dnsMode, uid, process, processPath
        case specialProxy, specialRules, remoteDestination, sniffHost
        case rule, rulePayload, chains, connectionLogs
        case upload, download, uploadSpeed, downloadSpeed
        case start, isClosed
    }
}

// MARK: - ConnectionsTotals

struct ConnectionsTotals: Codable {
    let upload: Int64
    let download: Int64
    let memory: Int64
}

// MARK: - ConnectionGroup

struct ConnectionGroup: Codable, Identifiable {
    let key: String
    let label: String
    let process: String
    let processPath: String
    let sourceIp: String
    let count: Int
    let upload: Int64
    let download: Int64
    let uploadSpeed: Int64
    let downloadSpeed: Int64

    var id: String { key }

    /// Display name: prefer label, fall back to key.
    var name: String { label.isEmpty ? key : label }
}

// MARK: - ConnectionsFrame

struct ConnectionsFrame: Codable {
    let activeCount: Int
    let closedCount: Int
    let totals: ConnectionsTotals
    let isInitial: Bool

    /// Convenience computed properties for dashboard display.
    var uploadTotal: Int64 { totals.upload }
    var downloadTotal: Int64 { totals.download }
}

// MARK: - Sort enums (matching Rust int values)

enum ConnectionsSort: Int, Codable {
    case time = 0, upload, download, uploadSpeed, downloadSpeed, process
}

enum ConnectionGroupSort: Int, Codable {
    case name = 0, count, upload, download, uploadSpeed, downloadSpeed
}

enum ConnectionsListKind: Int, Codable {
    case active = 0, closed
}