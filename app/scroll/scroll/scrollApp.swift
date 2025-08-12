import SwiftUI
import Network

@main
struct scrollApp: App {
    @StateObject private var bridge = WatchConnectivityBridge.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bridge)
                .onAppear {
                    // 强制触发本地网络权限请求 - 目前不必要了。
//                    requestLocalNetworkPermission()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    private func requestLocalNetworkPermission() {
        
        // 方法1: UDP广播触发权限（iOS 18推荐方法）
        let udpConnection = NWConnection(host: "255.255.255.255", port: 12345, using: .udp)
        udpConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let message = "WatchScroller Permission Request".data(using: .utf8)!
                udpConnection.send(content: message, completion: .contentProcessed { _ in
                    udpConnection.cancel()
                })
            case .failed:
                udpConnection.cancel()
            default:
                break
            }
        }
        udpConnection.start(queue: .main)
        
//        // 方法2: TCP连接备选方案
//        let connection = NWConnection(host: "192.168.1.1", port: 80, using: .tcp)
//        connection.stateUpdateHandler = { state in
//            switch state {
//            case .ready, .failed:
//                connection.cancel()
//            default:
//                break
//            }
//        }
//        connection.start(queue: .main)
        
        // 方法3: 延迟启动Bonjour浏览器 - DISABLED to prevent automatic switching
        // DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        //     WatchConnectivityBridge.shared.clearManualIPAndUseBonjour()
        // }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            bridge.handleAppBecameActive()
        case .inactive:
            bridge.handleAppBecameInactive()
        case .background:
            bridge.handleAppWentToBackground()
        @unknown default:
            break
        }
    }
}
