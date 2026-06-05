import Foundation

struct RuleEntry: Codable, Identifiable {
    let index: Int
    let ruleType: String
    let payload: String
    let proxy: String
    let disabled: Bool
    let hitCount: Int
    let missCount: Int

    var id: Int { index }

    enum CodingKeys: String, CodingKey {
        case index, ruleType = "type", payload, proxy, disabled, hitCount, missCount
    }
}

struct RulesSummary: Codable {
    let total: Int
    let filtered: Int
}