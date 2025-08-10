import SwiftUI

@main
struct WatchScrollerBridgeApp: App {
    @StateObject private var bridge = WatchConnectivityBridge.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bridge)
                .onAppear {
                    // App is now running and bridge is active
                    print("iOS Bridge App started")
                }
        }
    }
}