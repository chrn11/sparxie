import Foundation

@MainActor
class AppPrefs: ObservableObject {
    @AppStorage("navLayout") var navLayout: Int = 0 // 0=automatic
    @AppStorage("proxiesSort") var proxiesSort: Int = 0 // 0=Original, 1=Name, 2=Delay
    @AppStorage("delayTestScope") var delayTestScope: Int = 0 // 0=all, 1=visible
    @AppStorage("connectionsSort") var connectionsSort: Int = 0 // 0=Time, 1=Upload, etc.
    @AppStorage("groupSort") var groupSort: Int = 0
    @AppStorage("closeMode") var closeMode: Int = 0
    @AppStorage("logLevel") var logLevel: String = "info"
    @AppStorage("autoRefreshInterval") var autoRefreshInterval: Int = 3000
}