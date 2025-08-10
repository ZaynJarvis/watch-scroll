import Foundation
import Combine
import WatchConnectivity
import Network

class WatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = WatchConnectivityBridge()
    
    @Published var isWatchConnected = false
    @Published var isMacConnected = false
    @Published var connectionError: String?
    @Published var macHostAddress = "192.168.1.72" // Can be changed by user
    @Published var scrollCount = 0 // Counter for scroll messages from Watch
    
    // WatchConnectivity session
    private var session: WCSession?
    
    // Network connection to Mac
    private var connection: NWConnection?
    private let macPort: UInt16 = 8888
    
    // Possible Mac addresses to try
    private let commonMacHosts = ["localhost", "192.168.1.72", "192.168.0.1", "10.0.0.1"]
    private var currentHostIndex = 0
    
    // Retry mechanism for Mac connection
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 10
    
    override init() {
        super.init()
        setupWatchConnectivity()
        setupMacConnection()
    }
    
    // MARK: - Watch Connectivity Setup
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        
        print("WatchConnectivity bridge setup initiated")
    }
    
    // MARK: - Mac Connection Setup
    
    private func setupMacConnection() {
        retryTimer?.invalidate()
        retryTimer = nil
        
        let host = NWEndpoint.Host(macHostAddress)
        let port = NWEndpoint.Port(integerLiteral: macPort)
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Connected to Mac app")
                DispatchQueue.main.async {
                    self?.isMacConnected = true
                    self?.retryCount = 0
                    self?.connectionError = nil
                }
                self?.receiveFromMac()
            case .failed(let error):
                print("Mac connection failed: \(error)")
                DispatchQueue.main.async {
                    self?.isMacConnected = false
                    self?.connectionError = "Mac连接失败"
                }
                self?.scheduleRetry()
            case .cancelled:
                print("Mac connection cancelled")
                DispatchQueue.main.async {
                    self?.isMacConnected = false
                }
            case .waiting(let error):
                print("Waiting for Mac connection: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "等待Mac连接..."
                }
            default:
                break
            }
        }
        
        connection?.start(queue: .main)
    }
    
    private func scheduleRetry() {
        guard retryCount < maxRetries else {
            // Try next host in the list
            currentHostIndex += 1
            if currentHostIndex < commonMacHosts.count {
                macHostAddress = commonMacHosts[currentHostIndex]
                print("Trying next host: \(macHostAddress)")
                retryCount = 0
                setupMacConnection()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.connectionError = "无法连接到Mac应用。请确保:\n1. Mac应用正在运行\n2. Mac和iPhone在同一WiFi网络\n3. 检查IP地址: \(self?.macHostAddress ?? "")"
                }
            }
            return
        }
        
        retryCount += 1
        let retryDelay = min(Double(retryCount), 10.0)
        
        print("Scheduling Mac connection retry \(retryCount)/\(maxRetries) to \(macHostAddress) in \(retryDelay)s")
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            self?.setupMacConnection()
        }
    }
    
    private func receiveFromMac() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processDataFromMac(data)
            }
            
            if error != nil {
                print("Mac receive error: \(error!)")
                DispatchQueue.main.async {
                    self?.isMacConnected = false
                    self?.setupMacConnection()
                }
            } else if !isComplete {
                self?.receiveFromMac()
            }
        }
    }
    
    private func processDataFromMac(_ data: Data) {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Failed to parse message from Mac")
            return
        }
        
        print("Received from Mac: \(message)")
        
        // Forward message to Watch
        sendToWatch(message)
    }
    
    // MARK: - Message Forwarding
    
    private func sendToWatch(_ message: [String: Any]) {
        guard let session = session, session.isPaired && session.isReachable else {
            print("Watch not reachable")
            return
        }
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("Error sending to Watch: \(error)")
        })
    }
    
    private func sendToMac(_ message: [String: Any]) {
        guard let connection = connection else {
            print("Mac connection not available")
            return
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: message) else {
            print("Failed to serialize message for Mac")
            return
        }
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Error sending to Mac: \(error)")
            } else {
                print("Successfully sent to Mac: \(message)")
            }
        })
    }
    
    
    // MARK: - Public Methods
    
    func reconnectToMac() {
        retryCount = 0
        currentHostIndex = 0
        macHostAddress = commonMacHosts[0]
        connection?.cancel()
        setupMacConnection()
    }
    
    func setMacIPAddress(_ ipAddress: String) {
        macHostAddress = ipAddress
        reconnectToMac()
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            switch activationState {
            case .activated:
                self?.isWatchConnected = session.isPaired
                print("WCSession activated successfully")
            case .inactive:
                self?.isWatchConnected = false
                print("WCSession is inactive")
            case .notActivated:
                self?.isWatchConnected = false
                print("WCSession not activated")
            @unknown default:
                self?.isWatchConnected = false
            }
            
            if let error = error {
                self?.connectionError = error.localizedDescription
                print("WCSession activation error: \(error)")
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession did deactivate")
        // Reactivate the session for new Apple Watch
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchConnected = session.isPaired
            print("Watch state changed - Paired: \(session.isPaired)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchConnected = session.isPaired && session.isReachable
            print("Watch reachability changed: \(session.isReachable)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("Received from Watch: \(message)")
        
        // Handle scroll messages for testing
        if let action = message["action"] as? String, action == "scroll" {
            DispatchQueue.main.async {
                self.scrollCount += 1
                print("📱 Scroll count updated: \(self.scrollCount)")
            }
        }
        
        // Forward message to Mac
        sendToMac(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("Received from Watch (with reply): \(message)")
        
        // Handle scroll messages for testing
        if let action = message["action"] as? String, action == "scroll" {
            DispatchQueue.main.async {
                self.scrollCount += 1
                print("📱 Scroll count updated: \(self.scrollCount)")
            }
        }
        
        // Special handling for status requests
        if let action = message["action"] as? String, action == "requestStatus" {
            // Send current status immediately to Watch
            let statusResponse = [
                "action": "statusResponse",
                "isConnected": isMacConnected,
                "hasPermission": true,
                "isEnabled": true,
                "sensitivity": 1.0,
                "timestamp": Date().timeIntervalSince1970,
                "source": "iPhone bridge"
            ] as [String: Any]
            
            print("Sending status response to Watch: \(statusResponse)")
            replyHandler(statusResponse)
            
            // Also forward request to Mac for future updates
            sendToMac(message)
        } else {
            // Forward other messages normally
            sendToMac(message)
            replyHandler(["status": "forwarded_to_mac"])
        }
    }
}