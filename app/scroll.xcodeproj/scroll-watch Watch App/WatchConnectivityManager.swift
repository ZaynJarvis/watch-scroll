import Foundation
import Combine
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isConnected = false
    @Published var connectionError: String?
    @Published var messagesSent: Int = 0
    
    // WatchConnectivity session
    private var session: WCSession?
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    // MARK: - Public Methods
    
    func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            connectionError = "设备不支持"
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        
        
        // Force check status after a delay to ensure connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let session = self.session, session.activationState == .activated {
                self.isConnected = true
            }
        }
    }
    
    func sendMessage(_ message: [String: Any]) {
        guard let session = session else {
            connectionError = "会话不可用"
            return
        }
        
        // More aggressive sending - try even if not activated or reachable
        if session.activationState != .activated {
        }
        
        if !session.isReachable {
        }
        
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.connectionError = nil
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.connectionError = "发送失败: \(error.localizedDescription)"
            }
        })
        
        DispatchQueue.main.async { [weak self] in
            self?.messagesSent += 1
        }
    }
    
    /// 发送滚动命令 - Ultra minimal JSON for real-time performance
    func sendScrollCommand(pixels: Double) {
        // Ultra minimal: "a"=action, "p"=pixels (integer for efficiency)
        let message = [
            "a": 1,  // 1 = scroll action
            "p": Int(pixels.rounded())  // Integer pixels, no floats
        ] as [String: Any]
        
        sendMessage(message)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            switch activationState {
            case .activated:
                // Consider connected if session is activated
                self?.isConnected = true
                self?.connectionError = nil
            case .inactive:
                self?.isConnected = false
                self?.connectionError = "会话不活跃"
            case .notActivated:
                self?.isConnected = false
                self?.connectionError = "会话未激活"
            @unknown default:
                self?.isConnected = false
                self?.connectionError = "未知状态"
            }
            
            if let error = error {
                self?.connectionError = error.localizedDescription
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            
            if session.isReachable {
                self?.isConnected = true
                self?.connectionError = nil
            } else {
                // Don't immediately disconnect - reachability can be temporary
                self?.connectionError = "正在重连iPhone..."
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            replyHandler(["status": "received"])
        }
    }
}