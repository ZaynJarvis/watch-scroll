import Foundation
import Network
import Combine
import UIKit

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didConnect to: String)
    func connectionManager(_ manager: ConnectionManager, didDisconnectFrom host: String, error: String?)
    func connectionManager(_ manager: ConnectionManager, didFailToConnect to: String, error: String)
    func connectionManager(_ manager: ConnectionManager, didReceiveData data: Data, from host: String)
}

class ConnectionManager: ObservableObject {
    weak var delegate: ConnectionManagerDelegate?
    
    @Published var isConnected = false
    @Published var connectedHost: String?
    @Published var connectionStatus = "未连接"
    
    // Connection management
    private var connection: NWConnection?
    private let port: UInt16 = 8888
    
    // Retry logic with exponential backoff
    private var retryTimer: Timer?
    private var retryAttempts = 0
    private let maxRetryAttempts = 5
    private let baseRetryInterval: TimeInterval = 1.0 // Start with 1 second
    private let maxRetryInterval: TimeInterval = 30.0 // Cap at 30 seconds
    
    // Connection timeout
    private var connectionTimeoutTimer: Timer?
    private let connectionTimeout: TimeInterval = 10.0
    
    // Heartbeat monitoring
    private var heartbeatTimer: Timer?
    private let heartbeatInterval: TimeInterval = 30.0
    private var lastHeartbeatTime: Date?
    
    // Message throttling
    private var messageQueue: [[String: Any]] = []
    private var messageTimer: Timer?
    private var lastMessageTime = Date()
    private let messageInterval: TimeInterval = 0.016 // 60 FPS
    
    // Background task management
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Public Interface
    
    func connect(to host: String) {
        guard !isConnected && connection?.state != .ready else {
            print("✅ [ConnectionManager] Already connected to \(connectedHost ?? "unknown")")
            return
        }
        
        // Validate IP address format
        if host.contains("%") || host.hasPrefix("169.254.") || host.hasPrefix("fe80::") {
            print("❌ [ConnectionManager] Invalid IP address format: \(host)")
            delegate?.connectionManager(self, didFailToConnect: host, error: "无效的IP地址格式")
            return
        }
        
        print("🔌 [ConnectionManager] Connecting to \(host):\(port)")
        
        // Cancel existing connection if any
        disconnect()
        
        // Set host after disconnect to avoid it being cleared
        connectedHost = host
        connectionStatus = "连接中..."
        
        // Create new connection
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(integerLiteral: port)
        connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        
        setupConnectionHandlers()
        
        // Start connection timeout
        startConnectionTimeout()
        
        connection?.start(queue: .main)
    }
    
    func disconnect() {
        print("🔌 [ConnectionManager] Disconnecting from \(connectedHost ?? "unknown")")
        
        // Stop all timers
        stopAllTimers()
        
        // Cancel connection
        connection?.cancel()
        connection = nil
        
        // Update state
        isConnected = false
        connectionStatus = "已断开"
        connectedHost = nil
        
        // Reset retry state
        retryAttempts = 0
    }
    
    func sendMessage(_ message: [String: Any]) {
        guard isConnected, connection?.state == .ready else {
            print("📤 [ConnectionManager] Connection not ready, queuing message")
            messageQueue.append(message)
            return
        }
        
        // Add to queue for throttling
        messageQueue.append(message)
        processMessageQueue()
    }
    
    // MARK: - Connection Setup
    
    private func setupConnectionHandlers() {
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionStateChange(state)
            }
        }
        
        connection?.pathUpdateHandler = { [weak self] path in
            print("📡 [ConnectionManager] Path updated: \(path)")
        }
    }
    
    private func handleConnectionStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            print("✅ [ConnectionManager] Connected to \(connectedHost ?? "unknown")")
            
            // Clear timeout timer
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
            
            // Update state
            isConnected = true
            connectionStatus = "已连接"
            retryAttempts = 0 // Reset retry counter
            
            // Start monitoring
            startHeartbeat()
            startReceiving()
            
            // Process any queued messages
            processMessageQueue()
            
            // Notify delegate
            if let host = connectedHost {
                delegate?.connectionManager(self, didConnect: host)
            }
            
        case .failed(let error):
            print("❌ [ConnectionManager] Connection failed: \(error)")
            
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
            
            isConnected = false
            connectionStatus = "连接失败"
            
            let errorMessage = error.localizedDescription
            
            // Notify delegate
            if let host = connectedHost {
                delegate?.connectionManager(self, didFailToConnect: host, error: errorMessage)
            }
            
            // Handle different error types
            if errorMessage.contains("Connection refused") || errorMessage.contains("error 61") {
                // Server not available - use exponential backoff
                startRetryTimer()
            } else if errorMessage.contains("No route to host") || errorMessage.contains("Host is down") {
                // Network issue - trigger rediscovery
                delegate?.connectionManager(self, didDisconnectFrom: connectedHost ?? "unknown", error: "网络不可达")
            }
            
        case .cancelled:
            print("🚫 [ConnectionManager] Connection cancelled")
            
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
            
            isConnected = false
            connectionStatus = "已取消"
            
            if let host = connectedHost {
                delegate?.connectionManager(self, didDisconnectFrom: host, error: nil)
            }
            
        case .waiting(let error):
            print("⏳ [ConnectionManager] Waiting: \(error)")
            connectionStatus = "等待连接..."
            
        default:
            print("🔄 [ConnectionManager] State: \(state)")
        }
    }
    
    // MARK: - Connection Timeout
    
    private func startConnectionTimeout() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            print("⏰ [ConnectionManager] Connection timeout")
            
            guard let self = self else { return }
            
            self.connection?.cancel()
            self.isConnected = false
            self.connectionStatus = "连接超时"
            
            if let host = self.connectedHost {
                self.delegate?.connectionManager(self, didFailToConnect: host, error: "连接超时")
            }
            
            self.startRetryTimer()
        }
    }
    
    // MARK: - Retry Logic with Exponential Backoff
    
    private func startRetryTimer() {
        guard retryAttempts < maxRetryAttempts else {
            print("❌ [ConnectionManager] Max retry attempts reached")
            connectionStatus = "连接失败，请重试"
            return
        }
        
        retryAttempts += 1
        
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s, then cap at maxRetryInterval
        let retryInterval = min(baseRetryInterval * pow(2.0, Double(retryAttempts - 1)), maxRetryInterval)
        
        print("🔄 [ConnectionManager] Scheduling retry \(retryAttempts)/\(maxRetryAttempts) in \(retryInterval)s")
        connectionStatus = "重试中... (\(retryAttempts)/\(maxRetryAttempts))"
        
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: false) { [weak self] _ in
            guard let self = self, let host = self.connectedHost else { return }
            self.connect(to: host)
        }
    }
    
    // MARK: - Heartbeat Monitoring
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
        
        lastHeartbeatTime = Date()
    }
    
    private func sendHeartbeat() {
        let heartbeat = [
            "a": 3, // ping action
            "t": Date().timeIntervalSince1970
        ] as [String: Any]
        
        sendMessage(heartbeat)
        lastHeartbeatTime = Date()
    }
    
    // MARK: - Data Reception
    
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            DispatchQueue.main.async {
                self?.handleReceivedData(data: data, isComplete: isComplete, error: error)
            }
        }
    }
    
    private func handleReceivedData(data: Data?, isComplete: Bool, error: Error?) {
        if let data = data, !data.isEmpty {
            // Notify delegate
            if let host = connectedHost {
                delegate?.connectionManager(self, didReceiveData: data, from: host)
            }
        }
        
        if let error = error {
            print("❌ [ConnectionManager] Receive error: \(error)")
            
            isConnected = false
            connectionStatus = "连接中断"
            
            if let host = connectedHost {
                delegate?.connectionManager(self, didDisconnectFrom: host, error: error.localizedDescription)
            }
            
            // Try immediate reconnect for receive errors
            if let host = connectedHost {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.connect(to: host)
                }
            }
            return
        }
        
        if !isComplete {
            // Continue receiving
            startReceiving()
        }
    }
    
    // MARK: - Message Throttling
    
    private func processMessageQueue() {
        guard !messageQueue.isEmpty, isConnected, connection?.state == .ready else {
            return
        }
        
        let now = Date()
        let timeSinceLastMessage = now.timeIntervalSince(lastMessageTime)
        
        if timeSinceLastMessage >= messageInterval {
            sendQueuedMessage()
        } else {
            // Schedule delayed send
            messageTimer?.invalidate()
            messageTimer = Timer.scheduledTimer(withTimeInterval: messageInterval - timeSinceLastMessage, repeats: false) { [weak self] _ in
                self?.sendQueuedMessage()
            }
        }
    }
    
    private func sendQueuedMessage() {
        guard !messageQueue.isEmpty, isConnected, connection?.state == .ready else {
            return
        }
        
        // Get most recent message (drop older ones for real-time behavior)
        let message = messageQueue.removeLast()
        messageQueue.removeAll()
        
        guard let data = try? JSONSerialization.data(withJSONObject: message) else {
            return
        }
        
        // Add newline delimiter
        let dataWithDelimiter = data + "\n".data(using: .utf8)!
        
        connection?.send(content: dataWithDelimiter, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("❌ [ConnectionManager] Send error: \(error)")
            }
        })
        
        lastMessageTime = Date()
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    // MARK: - Background Task Management
    
    func handleAppWentToBackground() {
        startBackgroundTask()
    }
    
    func handleAppBecameActive() {
        endBackgroundTask()
        
        // Check connection health
        if isConnected, let lastTime = lastHeartbeatTime, Date().timeIntervalSince(lastTime) > heartbeatInterval * 2 {
            // Connection might be stale, try to reconnect
            print("🔄 [ConnectionManager] Connection might be stale, reconnecting")
            if let host = connectedHost {
                connect(to: host)
            }
        }
    }
    
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "MaintainConnection") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Cleanup
    
    private func stopAllTimers() {
        retryTimer?.invalidate()
        retryTimer = nil
        
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    deinit {
        disconnect()
        endBackgroundTask()
    }
}

// MARK: - Connection Health Monitoring Extension

extension ConnectionManager {
    var isHealthy: Bool {
        guard isConnected, let lastTime = lastHeartbeatTime else {
            return false
        }
        return Date().timeIntervalSince(lastTime) < heartbeatInterval * 2
    }
    
    func forceHealthCheck() {
        if isConnected && !isHealthy {
            print("🏥 [ConnectionManager] Force health check failed, reconnecting")
            if let host = connectedHost {
                connect(to: host)
            }
        }
    }
}