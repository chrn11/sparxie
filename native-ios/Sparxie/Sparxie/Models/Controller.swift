import Foundation

struct Controller: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var baseUrl: String
    var secret: String?
    var allowInsecure: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, baseUrl, secret, allowInsecure
    }

    static func == (lhs: Controller, rhs: Controller) -> Bool {
        lhs.id == rhs.id
    }
}