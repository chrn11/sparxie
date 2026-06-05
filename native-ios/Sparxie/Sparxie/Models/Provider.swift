import Foundation

struct ProxyProviderEntry: Codable, Identifiable {
    let name: String
    let vehicleType: String
    let proxies: [String]?
    let updatedAt: String?
    let updatable: Bool

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, vehicleType, proxies, updatedAt, updatable
    }
}

struct RuleProviderEntry: Codable, Identifiable {
    let name: String
    let vehicleType: String
    let behavior: String
    let format: String?
    let ruleCount: Int
    let updatedAt: String?
    let updatable: Bool

    var id: String { name }
}