import SwiftUI

@main
struct scroll_watch_Watch_AppApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
                .onAppear {
                    // App initialization
                }
        }
    }
}
