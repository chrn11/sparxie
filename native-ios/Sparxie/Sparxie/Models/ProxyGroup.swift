import Foundation

struct ProxyCatalog: Codable {
    let groups: [ProxyGroupEntry]
    let iconUrls: [String]
}

struct ProxyGroupEntry: Codable, Identifiable {
    let name: String
    let proxyType: String
    let icon: String?
    let memberCount: Int
    let membersHash: UInt32
    let now: String
    let testUrl: String?
    let fixed: String?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, proxyType = "type", icon, memberCount, membersHash, now, testUrl, fixed
    }
}

struct ProxyMemberEntry: Codable, Identifiable {
    let name: String
    let proxyType: String
    let delay: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, proxyType = "type", delay
    }
}

enum ProxyMemberSort: Int32, Codable {
    case original = 0, name, delay
}