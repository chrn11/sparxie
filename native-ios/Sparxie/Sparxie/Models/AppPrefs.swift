import Foundation

@MainActor
class AppPrefs: ObservableObject {
    @Published var navLayout: Int {
        didSet { UserDefaults.standard.set(navLayout, forKey: "navLayout") }
    }
    @Published var proxiesSort: Int {
        didSet { UserDefaults.standard.set(proxiesSort, forKey: "proxiesSort") }
    }
    @Published var delayTestScope: Int {
        didSet { UserDefaults.standard.set(delayTestScope, forKey: "delayTestScope") }
    }
    @Published var connectionsSort: Int {
        didSet { UserDefaults.standard.set(connectionsSort, forKey: "connectionsSort") }
    }
    @Published var groupSort: Int {
        didSet { UserDefaults.standard.set(groupSort, forKey: "groupSort") }
    }
    @Published var closeMode: Int {
        didSet { UserDefaults.standard.set(closeMode, forKey: "closeMode") }
    }
    @Published var logLevel: String {
        didSet { UserDefaults.standard.set(logLevel, forKey: "logLevel") }
    }
    @Published var autoRefreshInterval: Int {
        didSet { UserDefaults.standard.set(autoRefreshInterval, forKey: "autoRefreshInterval") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.navLayout = defaults.object(forKey: "navLayout") as? Int ?? 0
        self.proxiesSort = defaults.object(forKey: "proxiesSort") as? Int ?? 0
        self.delayTestScope = defaults.object(forKey: "delayTestScope") as? Int ?? 0
        self.connectionsSort = defaults.object(forKey: "connectionsSort") as? Int ?? 0
        self.groupSort = defaults.object(forKey: "groupSort") as? Int ?? 0
        self.closeMode = defaults.object(forKey: "closeMode") as? Int ?? 0
        self.logLevel = defaults.string(forKey: "logLevel") ?? "info"
        self.autoRefreshInterval = defaults.object(forKey: "autoRefreshInterval") as? Int ?? 3000
    }
}