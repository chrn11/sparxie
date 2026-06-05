import Foundation

struct VersionInfo: Codable, Equatable {
    var version: String
    var isCmfa: Bool
    var isStash: Bool
    var supportsCoreConfig: Bool
    var supportsCoreActions: Bool
    var supportsCoreManagement: Bool
    var supportsCacheFlush: Bool
    var supportsMemory: Bool
}