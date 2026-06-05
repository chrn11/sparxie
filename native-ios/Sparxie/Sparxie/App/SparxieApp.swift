import SwiftUI

@main
struct SparxieApp: App {
    @StateObject private var session = MihomoSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}