import Foundation

struct TrafficSample: Codable {
    let up: Int64
    let down: Int64
    let upTotal: Int64
    let downTotal: Int64
}

struct MemorySample: Codable {
    let inuse: Int64
    let oslimit: Int64
}