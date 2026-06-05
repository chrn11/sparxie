import Foundation

struct LogEntry: Codable, Identifiable {
    let time: String
    let level: String
    let message: String

    var id: String { "\(time)-\(level)-\(message.prefix(20))" }
}