import Foundation
import Combine
import WatchConnectivity
import UIKit

class WatchConnectivityBridgeV2: NSObject, ObservableObject {
    static let shared = WatchConnectivityBridgeV2()
    
    // Published properties for UI (delegated to StateManager)
    @Published var isWatchConnected = false
    @Published var isMacConnected = false
    @Published var connectionError: String?
    @Published var macHostAddress = "等待自动发现..."
    @Published var savedIPAddress = ""
    @Published var scrollCount = 0
    @Published var discoveredServices: [String] = []
    @Published var isUsingManualIP = false
    @Published var currentIPSource = "未连接"
    
    // Core services
    private let stateManager = StateManager()
    
    // WatchConnectivity session
    private var session: WCSession?
    
    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        print("🔄 [WatchConnectivityBridgeV2] Initializing bridge with modular architecture")
        setupWatchConnectivity()
        setupStateManagerBindings()
    }
    
    // MARK: - Watch Connectivity Setup
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("❌ [WatchConnectivityBridgeV2] WCSession not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        
        print("✅ [WatchConnectivityBridgeV2] WCSession activated")
    }
    
    // MARK: - State Manager Bindings
    
    private func setupStateManagerBindings() {
        // Bind StateManager properties to our published properties
        stateManager.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isMacConnected, on: self)
            .store(in: &cancellables)
        
        stateManager.$connectionError
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionError, on: self)
            .store(in: &cancellables)
        
        stateManager.$macHostAddress
            .receive(on: DispatchQueue.main)
            .assign(to: \.macHostAddress, on: self)
            .store(in: &cancellables)
        
        stateManager.$savedIPAddress
            .receive(on: DispatchQueue.main)
            .assign(to: \.savedIPAddress, on: self)
            .store(in: &cancellables)
        
        stateManager.$discoveredServices
            .receive(on: DispatchQueue.main)
            .assign(to: \.discoveredServices, on: self)
            .store(in: &cancellables)
        
        stateManager.$isUsingManualIP
            .receive(on: DispatchQueue.main)
            .assign(to: \.isUsingManualIP, on: self)
            .store(in: &cancellables)
        
        stateManager.$currentIPSource
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentIPSource, on: self)
            .store(in: &cancellables)
        
        print("✅ [WatchConnectivityBridgeV2] State manager bindings established")
    }
    
    // MARK: - Public Interface (Simplified)
    
    func reconnectToMac() {
        print("🔄 [WatchConnectivityBridgeV2] Manual reconnect requested")
        stateManager.reconnect()
    }
    
    func setMacIPAddress(_ ipAddress: String) {
        print("🔧 [WatchConnectivityBridgeV2] Setting manual IP: \(ipAddress)")
        stateManager.setManualIP(ipAddress)
    }
    
    func clearManualIPAndUseBonjour() {
        print("🗑️ [WatchConnectivityBridgeV2] Clearing manual IP")
        stateManager.clearManualIP()
    }
    
    // MARK: - Message Forwarding
    
    private func sendToWatch(_ message: [String: Any]) {
        guard let session = session, session.isPaired && session.isReachable else {
            print("❌ [WatchConnectivityBridgeV2] Watch not reachable")
            return
        }
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("❌ [WatchConnectivityBridgeV2] Failed to send to Watch: \(error)")
        })
    }
    
    private func sendToMac(_ message: [String: Any]) {
        stateManager.sendMessage(message)
    }
    
    // MARK: - App Lifecycle (Simplified)
    
    func handleAppBecameActive() {
        print("📱 [WatchConnectivityBridgeV2] App became active")
        stateManager.forceHealthCheck()
    }
    
    func handleAppBecameInactive() {
        print("📱 [WatchConnectivityBridgeV2] App became inactive")
        // StateManager handles background transition automatically
    }
    
    func handleAppWentToBackground() {
        print("📱 [WatchConnectivityBridgeV2] App went to background")
        // StateManager handles background tasks automatically
    }
    
    deinit {
        print("🧹 [WatchConnectivityBridgeV2] Cleaning up")
        cancellables.removeAll()
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityBridgeV2: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            switch activationState {
            case .activated:
                self?.isWatchConnected = session.isPaired && session.isReachable
                print("✅ [WatchConnectivityBridgeV2] Session activated, Watch connected: \(self?.isWatchConnected ?? false)")
            case .inactive:
                self?.isWatchConnected = false
                print("⏸️ [WatchConnectivityBridgeV2] Session inactive")
            case .notActivated:
                self?.isWatchConnected = false
                print("❌ [WatchConnectivityBridgeV2] Session not activated")
            @unknown default:
                self?.isWatchConnected = false
                print("❓ [WatchConnectivityBridgeV2] Unknown session state")
            }
            
            if let error = error {
                print("❌ [WatchConnectivityBridgeV2] Session activation error: \(error)")
                self?.connectionError = "Watch连接错误: \(error.localizedDescription)"
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⏸️ [WatchConnectivityBridgeV2] Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("❌ [WatchConnectivityBridgeV2] Session deactivated, reactivating...")
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            let wasConnected = self?.isWatchConnected ?? false
            self?.isWatchConnected = session.isPaired && session.isReachable
            
            let isConnected = self?.isWatchConnected ?? false
            if wasConnected != isConnected {
                print("📱 [WatchConnectivityBridgeV2] Watch state changed: \(isConnected)")
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            let wasConnected = self?.isWatchConnected ?? false
            self?.isWatchConnected = session.isPaired && session.isReachable
            
            let isConnected = self?.isWatchConnected ?? false
            if wasConnected != isConnected {
                print("📡 [WatchConnectivityBridgeV2] Watch reachability changed: \(isConnected)")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Handle minimal scroll messages (a=1 is scroll action)
        if let action = message["a"] as? Int, action == 1 {
            DispatchQueue.main.async {
                self.scrollCount += 1
            }
        }
        
        // Forward message to Mac
        sendToMac(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Handle minimal scroll messages (a=1 is scroll action)
        if let action = message["a"] as? Int, action == 1 {
            DispatchQueue.main.async {
                self.scrollCount += 1
            }
        }
        
        // Special handling for status requests (a=2 is status request)
        if let action = message["a"] as? Int, action == 2 {
            // Send current status immediately to Watch
            let statusResponse = [
                "action": "statusResponse",
                "isConnected": isMacConnected,
                "hasPermission": true,
                "isEnabled": true,
                "sensitivity": 1.0,
                "timestamp": Date().timeIntervalSince1970,
                "source": "iPhone bridge v2"
            ] as [String: Any]
            
            replyHandler(statusResponse)
        } else {
            replyHandler(["status": "forwarded_to_mac"])
        }
        
        // Forward message to Mac
        sendToMac(message)
    }
}