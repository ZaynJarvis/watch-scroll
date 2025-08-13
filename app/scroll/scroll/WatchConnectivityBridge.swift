import Foundation
import Combine
import WatchConnectivity
import Network
import UIKit
import SystemConfiguration

// Interface flags for network monitoring
private let IFF_UP: Int32 = 0x1
private let IFF_RUNNING: Int32 = 0x40

class WatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = WatchConnectivityBridge()
    
    // UserDefaults keys
    private let manualIPKey = "WatchScroller_ManualIP"
    private let useManualIPKey = "WatchScroller_UseManualIP"
    
    @Published var isWatchConnected = false
    @Published var isMacConnected = false
    @Published var connectionError: String?
    @Published var macHostAddress = "等待自动发现..." // Will be set by Bonjour or UserDefaults
    @Published var savedIPAddress = "" // Always contains the saved IP from UserDefaults, even if not currently used
    @Published var scrollCount = 0 // Counter for scroll messages from Watch
    @Published var discoveredServices: [String] = [] // Discovered Bonjour services
    @Published var isUsingManualIP = false // Track if using manually set IP
    @Published var currentIPSource = "未连接" // Track the source of current IP (手动设置/自动发现/重连中)
    
    // Message throttling
    private var lastMessageTime = Date()
    private var messageQueue: [[String: Any]] = []
    private var messageTimer: Timer?
    
    // WatchConnectivity session
    private var session: WCSession?
    
    // Network connection to Mac
    private var connection: NWConnection?
    private let macPort: UInt16 = 8888
    private var isConnecting = false  // Prevent multiple simultaneous connection attempts
    private var connectionTimeoutTimer: Timer?  // Timeout for connection attempts
    
    // Bonjour browser for service discovery
    private var browser: NWBrowser?
    
    // Retry mechanism for Bonjour discovery
    private var discoveryRetryTimer: Timer?
    private var discoveryRetryCount = 0
    private let maxDiscoveryRetries = 5
    private var bonjourTimeoutTimer: Timer?
    
    // Supabase fallback service discovery
    private let supabaseUrl = "https://qeioxayacjcrbxbuqzef.functions.supabase.co"
    private let uuid = "zaynjarvis"
    private var supabaseFallbackAttempted = false
    
    // Auto-reconnection mechanism - simplified and less aggressive
    private var reconnectionTimer: Timer?
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 3 // Only 3 attempts
    private let reconnectionInterval: TimeInterval = 5.0 // 5 seconds between attempts
    private var shouldAutoReconnect = true // Flag to control auto-reconnection
    private var lastReconnectionTime: Date? // Prevent rapid reconnections
    
    // Discovered IP tracking for optimized reconnection
    private var discoveredIP: String? // Last successfully discovered IP via Bonjour
    private var discoveredIPFailureCount = 0 // Track failures for discovered IP
    private let maxDiscoveredIPFailures = 3 // After 3 failures, rediscover
    
    // Track initial setup phase
    private var isInitialSetup = true // Prevent premature lifecycle interference
    
    // Background task management
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundKeepaliveTimer: Timer?
    
    // Network monitoring for IP changes
    private var networkMonitor: NWPathMonitor?
    private var currentWiFiSSID: String?
    private var currentLocalIP: String?
    
    override init() {
        super.init()
        print("🔄 [WatchConnectivityBridge] Initializing bridge")
        loadSavedIPSettings()
        setupWatchConnectivity()
        startNetworkMonitoring()
        
        // Start Bonjour discovery only if not using manual IP
        if !isUsingManualIP {
            print("🔍 [WatchConnectivityBridge] Starting auto-discovery mode")
            connectionError = "正在搜索 Mac 应用..."
            currentIPSource = "自动发现"
            startBonjourDiscovery()
        }
        
        // If we have a manually set IP, connect to it
        if isUsingManualIP {
            print("🔧 [WatchConnectivityBridge] Using manual IP: \(macHostAddress)")
            connectionError = "连接到保存的IP: \(macHostAddress)"
            currentIPSource = "手动设置"
            // Connect to saved IP with small delay to let initialization complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setupMacConnection()
            }
        }
    }
    
    private func loadSavedIPSettings() {
        let savedIP = UserDefaults.standard.string(forKey: manualIPKey) ?? ""
        let useManualIP = UserDefaults.standard.bool(forKey: useManualIPKey)
        
        // Always store the saved IP address for display in the input field
        savedIPAddress = savedIP
        
        if useManualIP && !savedIP.isEmpty {
            macHostAddress = savedIP
            isUsingManualIP = true
        } else {
            macHostAddress = "等待自动发现..."
            isUsingManualIP = false
        }
    }
    
    // MARK: - Bonjour Service Discovery
    
    private func startBonjourDiscovery() {
        // Don't start discovery if we already have a discovered IP
        if let existingIP = discoveredIP {
            print("🔍 [Bonjour] Already have discovered IP (\(existingIP)), skipping discovery")
            return
        }
        
        print("🔍 [Bonjour] Starting service discovery")
        
        // Step 1: Preflight permission check using _preflight_check._tcp
        performPreflightPermissionCheck()
        
        // Step 2: Create browser for WatchScroller services
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        parameters.requiredInterfaceType = .wifi  // 强制使用WiFi接口
        
        browser = NWBrowser(for: .bonjour(type: "_watchscroller._tcp", domain: nil), using: parameters)
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            print("🔍 [Bonjour] Browse results changed - found \(results.count) services")
            print("🔍 [Bonjour] Changes: \(changes)")
            for result in results {
                print("🔍 [Bonjour] Service: \(result.endpoint)")
            }
            
            // Clear previous discoveries
            DispatchQueue.main.async {
                self?.discoveredServices.removeAll()
            }
            
            if results.isEmpty {
                DispatchQueue.main.async {
                    self?.connectionError = "未找到 Mac 应用，请确保:\n1. Mac 应用正在运行\n2. 设备在同一网络"
                }
                // Try Supabase fallback before scheduling retry
                self?.attemptSupabaseFallback()
            } else {
                // Reset retry count on successful discovery
                self?.discoveryRetryCount = 0
                self?.discoveryRetryTimer?.invalidate()
                self?.bonjourTimeoutTimer?.invalidate()  // Cancel timeout since we found services
                
                // Only resolve if we don't already have a discovered IP
                guard self?.discoveredIP == nil else {
                    print("🔍 [Bonjour] Already have discovered IP (\(self?.discoveredIP ?? "")), skipping resolution")
                    return
                }
                
                // Only resolve the first service found
                if let firstResult = results.first {
                    switch firstResult.endpoint {
                    case let .service(name: name, type: _, domain: _, interface: _):
                        print("🔍 [Bonjour] Resolving first service: \(name)")
                        self?.resolveService(firstResult.endpoint)
                    default:
                        break
                    }
                }
            }
        }
        
        browser?.stateUpdateHandler = { state in
            print("🔍 [Bonjour] Browser state changed to: \(state)")
            switch state {
            case .ready:
                print("🔍 [Bonjour] Browser is ready and actively browsing")
                DispatchQueue.main.async { [weak self] in
                    if self?.connectionError?.contains("权限问题") == true {
                        self?.connectionError = "正在搜索 Mac 应用..."
                    }
                }
            case .failed(let error):
                if error.localizedDescription.contains("65555") || error.localizedDescription.contains("NoAuth") {
                    DispatchQueue.main.async { [weak self] in
                        self?.connectionError = "本地网络权限问题"
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.connectionError = "网络发现失败: \(error.localizedDescription)"
                    }
                }
            default:
                break
            }
        }
        
        // Start browsing
        print("🔍 [Bonjour] Starting browser for _watchscroller._tcp services")
        browser?.start(queue: .main)
        
        // Start 3-second timeout timer for Bonjour discovery
        bonjourTimeoutTimer?.invalidate()
        bonjourTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Only trigger timeout if we still don't have a discovered IP
            if self.discoveredIP == nil {
                print("🔍 [Bonjour] 3-second timeout reached, no services found - falling back to Supabase")
                DispatchQueue.main.async {
                    self.connectionError = "本地发现超时，尝试云端发现..."
                }
                self.attemptSupabaseFallback()
            } else {
                print("🔍 [Bonjour] Timeout reached but IP already discovered: \(self.discoveredIP ?? "")")
            }
        }
    }
    
    private func performPreflightPermissionCheck() {
        
        // Method 1: Create a temporary preflight browser to trigger permissions
        let preflightParameters = NWParameters()
        let preflightBrowser = NWBrowser(for: .bonjour(type: "_preflight_check._tcp", domain: nil), using: preflightParameters)
        
        preflightBrowser.stateUpdateHandler = { state in
            switch state {
            case .ready:
                preflightBrowser.cancel()
            case .failed(let error):
                if error.localizedDescription.contains("65555") {
                    DispatchQueue.main.async { [weak self] in
                        self?.connectionError = "权限问题：请重启设备后重试\n这是iOS 17/18的已知bug"
                    }
                }
                preflightBrowser.cancel()
            default:
                break
            }
        }
        
        preflightBrowser.start(queue: .main)
        
        // Method 2: UDP broadcast trigger (iOS 18 recommended)
        let udpConnection = NWConnection(host: "255.255.255.255", port: 12345, using: .udp)
        udpConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let message = "WatchScroller Preflight".data(using: .utf8)!
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
        
        // Clean up after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            preflightBrowser.cancel()
            udpConnection.cancel()
        }
    }
    
    private func attemptSupabaseFallback() {
        // Only try Supabase fallback once per discovery session
        guard !supabaseFallbackAttempted else {
            scheduleDiscoveryRetry()
            return
        }
        
        supabaseFallbackAttempted = true
        print("🌐 [Supabase] Attempting fallback service discovery")
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionError = "尝试备用服务发现..."
        }
        
        // Make GET request to Supabase endpoint
        guard let url = URL(string: "\(supabaseUrl)/get-ip?uuid=\(uuid)") else {
            print("❌ [Supabase] Invalid URL")
            scheduleDiscoveryRetry()
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ [Supabase] Request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.scheduleDiscoveryRetry()
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ [Supabase] Failed to parse JSON response")
                DispatchQueue.main.async {
                    self?.scheduleDiscoveryRetry()
                }
                return
            }
            
            // Handle nested data structure: {"data": {"ip": "..."}}
            let ipAddress: String?
            if let dataObject = json["data"] as? [String: Any] {
                ipAddress = dataObject["ip"] as? String
            } else {
                // Fallback to root level IP for backwards compatibility
                ipAddress = json["ip"] as? String
            }
            
            guard let validIP = ipAddress else {
                print("❌ [Supabase] Invalid response format - no IP found")
                print("📝 [Supabase] Response JSON: \(json)")
                DispatchQueue.main.async {
                    self?.scheduleDiscoveryRetry()
                }
                return
            }
            
            print("🌐 [Supabase] Retrieved IP address: \(validIP)")
            
            DispatchQueue.main.async {
                // Record the discovered IP from Supabase
                self?.discoveredIP = validIP
                self?.discoveredIPFailureCount = 0
                
                // Only use discovered IP if not using manual IP
                if self?.isUsingManualIP == false {
                    print("🌐 [Supabase] Using fallback discovered IP \(validIP)")
                    self?.macHostAddress = validIP
                    self?.currentIPSource = "备用发现"
                    self?.connectionError = nil
                    
                    // Connect to the fallback IP
                    if self?.connection == nil && self?.isMacConnected == false && self?.isConnecting == false {
                        print("🌐 [Supabase] Auto-connecting to fallback service")
                        self?.setupMacConnection()
                    } else {
                        print("🌐 [Supabase] Connection exists or in progress, skipping auto-connect")
                    }
                } else {
                    print("🌐 [Supabase] Using manual IP, ignoring fallback service")
                }
                
                // Always add to discovered services for UI display
                if !(self?.discoveredServices.contains(validIP) ?? true) {
                    self?.discoveredServices.append(validIP)
                }
            }
        }
        
        task.resume()
    }
    
    private func scheduleDiscoveryRetry() {
        guard discoveryRetryCount < maxDiscoveryRetries else {
            DispatchQueue.main.async { [weak self] in
                self?.connectionError = "无法找到 Mac 应用\n\n请检查:\n1. Mac 应用是否在运行\n2. 两台设备是否在同一 WiFi 网络\n3. 网络防火墙设置"
            }
            return
        }
        
        discoveryRetryCount += 1
        let retryDelay = Double(discoveryRetryCount) * 2.0 // 2s, 4s, 6s...
        
        
        discoveryRetryTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            // Don't retry if we already have a discovered IP
            guard self?.discoveredIP == nil else {
                print("🔍 [scheduleDiscoveryRetry] Already have IP, skipping retry")
                return
            }
            print("🚫 [CANCEL-10] scheduleDiscoveryRetry canceling browser for retry")
            self?.browser?.cancel()
            self?.startBonjourDiscovery()
        }
    }
    
    private func resolveService(_ endpoint: Network.NWEndpoint) {
        
        // Create a temporary connection to resolve the service
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // Get the resolved IP address
                if let remoteEndpoint = connection.currentPath?.remoteEndpoint {
                    
                    if case let .hostPort(host: host, port: _) = remoteEndpoint {
                        var ipAddress: String?
                        
                        switch host {
                        case .ipv4(let address):
                            ipAddress = "\(address)"
                        case .ipv6(let address):
                            ipAddress = "\(address)"
                        case .name(let hostname, _):
                            // For hostname, try to resolve to IP
                            ipAddress = self?.resolveHostnameToIP(hostname) ?? hostname
                        @unknown default:
                            break
                        }
                        
                        if let ip = ipAddress {
                            print("🔍 [resolveService] Discovered service at \(ip)")
                            DispatchQueue.main.async {
                                // Record the discovered IP
                                self?.discoveredIP = ip
                                self?.discoveredIPFailureCount = 0
                                
                                // Only use discovered IP if not using manual IP
                                if self?.isUsingManualIP == false {
                                    print("🔍 [resolveService] Using discovered IP \(ip)")
                                    self?.macHostAddress = ip
                                    self?.currentIPSource = "自动发现"
                                    self?.connectionError = nil
                                    
                                    // Stop Bonjour discovery once we have IP
                                    print("🔍 [resolveService] Stopping Bonjour discovery - IP found")
                                    print("👌 [DONE-9] resolveService canceling browser after IP discovery")
                                    self?.browser?.cancel()
                                    
                                    // Connect only if no existing connection
                                    if self?.connection == nil && self?.isMacConnected == false && self?.isConnecting == false {
                                        print("🔍 [resolveService] Auto-connecting to discovered service")
                                        self?.setupMacConnection()
                                    } else {
                                        print("🔍 [resolveService] Connection exists or in progress, skipping auto-connect")
                                    }
                                } else {
                                    print("🔍 [resolveService] Using manual IP, ignoring discovered service")
                                }
                                
                                // Always add to discovered services for UI display
                                if !(self?.discoveredServices.contains(ip) ?? true) {
                                    self?.discoveredServices.append(ip)
                                }
                            }
                        }
                    }
                } else {
                }
                // Close the temporary connection
                print("👌 [DONE-1] Temporary service resolution connection cancelled")
                connection.cancel()
                
            case .failed(_):
                print("🚫 [CANCEL-2] Failed service resolution connection cancelled")
                connection.cancel()
            case .waiting(_):
                break
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    private func resolveHostnameToIP(_ hostname: String) -> String? {
        let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
            for case let theAddress as NSData in addresses {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let numAddress = String(cString: hostname)
                    return numAddress
                }
            }
        }
        return nil
    }
    
    // MARK: - Watch Connectivity Setup
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        
    }
    
    // MARK: - Mac Connection Setup
    
    private func setupMacConnection() {
        print("🔌 [setupMacConnection] Attempting connection to \(macHostAddress):\(macPort)")
        
        // Only connect if we have a discovered IP address
        guard macHostAddress != "等待自动发现...", !macHostAddress.isEmpty else {
            print("❌ [setupMacConnection] No valid IP address to connect to")
            return
        }
        
        // If already connected or connecting to the same host, don't reconnect
        if isMacConnected || (connection?.state == .ready) {
            print("✅ [setupMacConnection] Already connected to \(macHostAddress), skipping")
            return
        }
        
        // Prevent multiple simultaneous connection attempts
        guard !isConnecting else {
            print("⚠️ [setupMacConnection] Already connecting, skipping")
            return
        }
        
        print("🔌 [setupMacConnection] Connecting to \(macHostAddress):\(macPort)")
        isConnecting = true
        
        // Start connection timeout timer (10 seconds)
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            print("⏰ [setupMacConnection] Connection attempt timed out")
            self?.handleConnectionTimeout()
        }
        
        // Only cancel if connection is not in a good state
        if let existingConnection = connection {
            let state = existingConnection.state
            
            // Don't cancel if connection is ready/working
            if state == .ready {
                print("⚠️ [CANCEL-3-SKIP] NOT canceling ready connection - this would break working connection!")
                isConnecting = false
                return
            }
            
            // Only cancel failed/cancelled/waiting connections
            switch state {
            case .failed, .cancelled:
                print("🚫 [CANCEL-3] setupMacConnection canceling non-ready connection (state: \(state))")
                existingConnection.cancel()
                connection = nil
            case .waiting:
                print("🚫 [CANCEL-3] setupMacConnection canceling waiting connection (state: \(state))")
                existingConnection.cancel()
                connection = nil
            default:
                print("⚠️ [CANCEL-3-SKIP] NOT canceling connection in state: \(state)")
                isConnecting = false
                return
            }
        }
        
        let host = NWEndpoint.Host(macHostAddress)
        let port = NWEndpoint.Port(integerLiteral: macPort)
        
        // Use simple TCP connection - don't over-engineer
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ [Connection] Successfully connected to \(self?.macHostAddress ?? "unknown")")
                
                // Clear connection timeout since we succeeded
                self?.connectionTimeoutTimer?.invalidate()
                self?.connectionTimeoutTimer = nil
                
                // Update connection state immediately (already on main queue)
                self?.isMacConnected = true
                self?.isConnecting = false
                self?.connectionError = nil
                
                // Mark initial setup as complete
                self?.isInitialSetup = false
                // Stop auto-reconnection (includes resetting attempts)
                self?.stopAutoReconnection()
                
                // Reset discovered IP failure count on successful connection
                if self?.isUsingManualIP == false {
                    self?.discoveredIPFailureCount = 0
                }
                
                // End background task since we have active connection
                self?.endBackgroundTask()
                
                // Set up receive handler immediately to keep connection alive
                self?.receiveFromMac()
                
                // Process any queued messages after successful connection
                self?.processMessageQueue()
            case .failed(let error):
                print("❌ [Connection] Failed to connect to \(self?.macHostAddress ?? "unknown"): \(error.localizedDescription)")
                
                // Clear connection timeout since we failed
                self?.connectionTimeoutTimer?.invalidate()
                self?.connectionTimeoutTimer = nil
                
                // Update connection state immediately (already on main queue)
                self?.isMacConnected = false
                self?.isConnecting = false
                self?.connectionError = "Mac连接失败: \(error.localizedDescription)"
                
                // Clean up failed connection
                self?.connection = nil
                
                // Handle different types of connection failures
                if error.localizedDescription.contains("Connection reset by peer") || 
                   error.localizedDescription.contains("error 54") {
                    // Server closed connection - try immediate reconnect
                    print("🔄 [Connection] Server closed connection, attempting auto-reconnect")
                    self?.setupMacConnection()
                } else if error.localizedDescription.contains("Connection refused") ||
                         error.localizedDescription.contains("error 61") ||
                         error.localizedDescription.contains("No route to host") ||
                         error.localizedDescription.contains("Host is down") {
                    // Connection refused or host unreachable - server may have changed IP
                    print("🔄 [Connection] Server unreachable, may have changed IP - triggering rediscovery")
                    self?.handleServerIPChange()
                }
            case .cancelled:
                print("🚫 [Connection] Connection cancelled")
                
                // Clear connection timeout 
                self?.connectionTimeoutTimer?.invalidate()
                self?.connectionTimeoutTimer = nil
                
                // Update connection state immediately (already on main queue)
                self?.isMacConnected = false
                self?.isConnecting = false
                // Show user-friendly message since server is likely still working
                self?.connectionError = "连接已断开 - 服务器可能已关闭"
                // Clean up connection
                self?.connection = nil
            case .waiting(let error):
                print("⏳ [Connection] Waiting to connect to \(self?.macHostAddress ?? "unknown"): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.connectionError = "正在连接到 \(self?.macHostAddress ?? "")..."
                }
            default:
                print("🔄 [Connection] State changed: \(state)")
                break
            }
        }
        
        connection?.start(queue: .main)
    }
    
    private func handleConnectionTimeout() {
        print("⏰ [handleConnectionTimeout] Connection attempt timed out, cleaning up")
        
        // Cancel the stuck connection
        if let conn = connection {
            print("🚫 [CANCEL-12] handleConnectionTimeout canceling stuck connection")
            conn.cancel()
        }
        connection = nil
        
        // Reset connecting state
        isConnecting = false
        
        // Update UI immediately (timeout handler runs on main queue)
        isMacConnected = false
        connectionError = "连接超时 - 请重试"
        
        // Clear the timeout timer
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
    }
    
    private func receiveFromMac() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processDataFromMac(data)
            }
            
            if let error = error {
                print("❌ [receiveFromMac] Server closed connection or network error: \(error.localizedDescription)")
                // Update connection state immediately (receive handler runs on main queue)
                self?.isMacConnected = false
                self?.connectionError = "服务器连接中断 - 尝试重连中..."
                
                // Cancel the connection since it's no longer working
                if let conn = self?.connection {
                    print("🚫 [CANCEL-11] receiveFromMac canceling failed connection due to error")
                    conn.cancel()
                }
                self?.connection = nil
                
                // Auto-reconnect after server disconnection immediately
                print("🔄 [receiveFromMac] Attempting auto-reconnect after server disconnection")
                // State is already updated synchronously, safe to reconnect immediately
                self?.setupMacConnection()
                return
            }
            
            if !isComplete {
                // Continue receiving to keep connection alive
                self?.receiveFromMac()
            }
        }
    }
    
    private func processDataFromMac(_ data: Data) {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        
        // Forward message to Watch
        sendToWatch(message)
    }
    
    // MARK: - Message Forwarding
    
    private func sendToWatch(_ message: [String: Any]) {
        guard let session = session, session.isPaired && session.isReachable else {
            return
        }
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
        })
    }
    
    private func sendToMac(_ message: [String: Any]) {
        // If no connection exists or is not connected, queue message and try to reconnect
        if connection == nil || !isMacConnected {
            print("📤 [sendToMac] No connection, queuing message and attempting reconnect")
            messageQueue.append(message)
            
            // Try to reconnect if we have a valid IP
            if !macHostAddress.isEmpty && macHostAddress != "等待自动发现..." {
                // Don't spam reconnection attempts
                if !isConnecting {
                    print("📤 [sendToMac] Triggering reconnection")
                    setupMacConnection()
                }
            }
            return
        }
        
        // Add message to queue and process with throttling
        messageQueue.append(message)
        processMessageQueue()
    }
    
    private func processMessageQueue() {
        guard !messageQueue.isEmpty else { return }
        
        let now = Date()
        let timeSinceLastMessage = now.timeIntervalSince(lastMessageTime)
        
        // Send immediately if enough time has passed (16ms = 60 FPS for ultra-smooth)
        if timeSinceLastMessage >= 0.016 {
            sendQueuedMessage()
        } else {
            // Schedule delayed send
            messageTimer?.invalidate()
            messageTimer = Timer.scheduledTimer(withTimeInterval: 0.016 - timeSinceLastMessage, repeats: false) { _ in
                self.sendQueuedMessage()
            }
        }
    }
    
    private func sendQueuedMessage() {
        guard !messageQueue.isEmpty else { return }
        
        // Get the most recent message (drop older ones for real-time behavior)
        let message = messageQueue.removeLast()
        messageQueue.removeAll() // Clear queue to prevent lag
        
        guard let data = try? JSONSerialization.data(withJSONObject: message) else {
            return
        }
        
        // Add newline delimiter to prevent message concatenation
        let dataWithDelimiter = data + "\n".data(using: .utf8)!
        
        connection?.send(content: dataWithDelimiter, completion: .contentProcessed { error in
            if let error = error {
                print("❌ [sendQueuedMessage] Send failed: \(error.localizedDescription)")
            }
            // Remove successful send logs as they're too frequent
        })
        
        lastMessageTime = Date()
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    // MARK: - Auto-reconnection Methods
    
    private func startAutoReconnection() {
        guard shouldAutoReconnect else {
            print("🚫 [Reconnection] Auto-reconnection disabled")
            return
        }
        
        // Prevent rapid reconnections - require at least 5 seconds between attempts
        let now = Date()
        if let lastTime = lastReconnectionTime, now.timeIntervalSince(lastTime) < 5.0 {
            let cooldown = 5.0 - now.timeIntervalSince(lastTime)
            print("⏳ [Reconnection] Still in cooldown period, waiting \(String(format: "%.1f", cooldown))s")
            return
        }
        
        guard reconnectionAttempts < maxReconnectionAttempts else {
            print("❌ [Reconnection] Max attempts reached (\(maxReconnectionAttempts)), giving up")
            DispatchQueue.main.async { [weak self] in
                self?.connectionError = "连接失败，请手动重试"
            }
            return
        }
        
        // Cancel any existing timer
        reconnectionTimer?.invalidate()
        
        reconnectionAttempts += 1
        lastReconnectionTime = now
        
        print("🔄 [Reconnection] Starting attempt #\(reconnectionAttempts)/\(maxReconnectionAttempts), will retry in \(reconnectionInterval)s")
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionError = "正在重试连接... (\(self?.reconnectionAttempts ?? 0)/\(self?.maxReconnectionAttempts ?? 0))"
        }
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: reconnectionInterval, repeats: false) { [weak self] _ in
            print("⏰ [Reconnection] Timer fired, attempting reconnection")
            self?.attemptReconnection()
        }
    }
    
    private func attemptReconnection() {
        print("🔧 [attemptReconnection] Starting reconnection attempt")
        print("🔧 [attemptReconnection] Current state: isUsingManualIP=\(isUsingManualIP), savedIPAddress=\(savedIPAddress), discoveredIP=\(discoveredIP ?? "nil"), discoveredIPFailureCount=\(discoveredIPFailureCount)")
        
        // Reload saved IP settings to get latest configuration
        loadSavedIPSettings()
        
        // Prioritize reconnection strategy based on current mode
        if isUsingManualIP && !savedIPAddress.isEmpty {
            print("🔧 [attemptReconnection] Using manual IP strategy: \(savedIPAddress)")
            reconnectWithIP(savedIPAddress, source: "手动设置", isManual: true)
        } else if let discoveredIP = discoveredIP, discoveredIPFailureCount < maxDiscoveredIPFailures {
            print("🔍 [attemptReconnection] Using discovered IP strategy: \(discoveredIP) (failures: \(discoveredIPFailureCount)/\(maxDiscoveredIPFailures))")
            reconnectWithIP(discoveredIP, source: "重连中(自动发现)", isManual: false)
        } else if discoveredIPFailureCount >= maxDiscoveredIPFailures {
            print("🔄 [attemptReconnection] Too many failures for discovered IP, triggering rediscovery")
            triggerRediscovery()
        } else if !savedIPAddress.isEmpty {
            print("💾 [attemptReconnection] Using saved IP fallback: \(savedIPAddress)")
            reconnectWithIP(savedIPAddress, source: "重连中(已保存)", isManual: false)
        } else {
            print("🔍 [attemptReconnection] No IP available, triggering discovery")
            triggerRediscovery()
        }
    }
    
    private func reconnectWithIP(_ ipAddress: String, source: String, isManual: Bool) {
        print("🔄 [reconnectWithIP] Attempting to reconnect with IP: \(ipAddress), source: \(source), isManual: \(isManual)")
        let previousHost = macHostAddress
        let previousUsingManual = isUsingManualIP
        
        macHostAddress = ipAddress
        isUsingManualIP = isManual
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionError = "重试连接到: \(ipAddress)"
            self?.currentIPSource = source
        }
        
        // Try to connect
        print("🔄 [reconnectWithIP] Calling setupMacConnection")
        setupMacConnection()
        
        // Restore previous settings after connection attempt if failed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if self?.isMacConnected == false {
                if !isManual {
                    // If reconnection with discovered IP failed, increment failure count
                    if ipAddress == self?.discoveredIP {
                        self?.discoveredIPFailureCount += 1
                    }
                }
                self?.macHostAddress = previousHost
                self?.isUsingManualIP = previousUsingManual
            }
        }
    }
    
    private func triggerRediscovery() {
        
        // Reset discovered IP tracking
        discoveredIP = nil
        discoveredIPFailureCount = 0
        supabaseFallbackAttempted = false
        
        DispatchQueue.main.async { [weak self] in
            self?.macHostAddress = "等待自动发现..."
            self?.currentIPSource = "重新发现中"
            self?.isUsingManualIP = false
            self?.discoveredServices.removeAll()
        }
        
        // Cancel current browser and start fresh
        print("🚫 [CANCEL-4] triggerRediscovery canceling browser")
        browser?.cancel()
        bonjourTimeoutTimer?.invalidate()  // Cancel any running timeout
        startBonjourDiscovery()
    }
    
    private func stopAutoReconnection() {
        guard reconnectionTimer != nil || reconnectionAttempts > 0 else {
            return // No need to stop if nothing is running
        }
        print("🛑 [Reconnection] Stopping auto-reconnection (was at \(reconnectionAttempts) attempts)")
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        reconnectionAttempts = 0
    }
    
    private func resetReconnectionAttempts() {
        guard reconnectionAttempts > 0 else {
            return // No need to reset if already 0
        }
        print("🔄 [Reconnection] Resetting attempts counter (was at \(reconnectionAttempts))")
        reconnectionAttempts = 0
    }
    
    // MARK: - App Lifecycle Methods
    
    func handleAppBecameActive() {
        print("📱 [Lifecycle] App became active - isMacConnected: \(isMacConnected), connection state: \(String(describing: connection?.state)), isInitialSetup: \(isInitialSetup)")
        shouldAutoReconnect = true
        
        // Don't interfere during initial startup - let normal discovery process work
        if isInitialSetup || macHostAddress == "等待自动发现..." {
            print("📱 [Lifecycle] Initial setup in progress, not interfering")
            return
        }
        
        // Only reconnect if we actually lost connection and have a known IP
        if !isMacConnected && (connection == nil || connection?.state != .ready) && !macHostAddress.isEmpty {
            print("📱 [Lifecycle] Connection lost, attempting immediate reconnect")
            autoReconnectToMac()
        } else {
            print("📱 [Lifecycle] Connection is good or no IP available, no reconnect needed")
        }
    }
    
    func handleAppBecameInactive() {
        // Keep auto-reconnect enabled but don't start new connections
    }
    
    func handleAppWentToBackground() {
        // Keep shouldAutoReconnect enabled so we can reconnect when app becomes active
        // iOS will suspend the connection but we'll detect and reconnect when active
        
        // Start a background task to try to keep connection alive briefly
        startBackgroundTask()
        
        // Start network monitoring for IP changes
        startNetworkMonitoring()
    }
    
    private func startBackgroundTask() {
        // Request additional background time to maintain connection
        // This gives us ~30 seconds to maintain the connection
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "MaintainConnection") { [weak self] in
            // Background time expired, clean up
            self?.endBackgroundTask()
        }
        
        
        // Send periodic keepalive messages
        startBackgroundKeepalive()
    }
    
    private func startBackgroundKeepalive() {
        // Send a ping every 5 seconds while in background
        backgroundKeepaliveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isMacConnected {
                // Send ping message to keep connection alive
                let pingMessage = [
                    "a": 3, // ping action
                    "t": Date().timeIntervalSince1970
                ] as [String: Any]
                
                self.sendToMac(pingMessage)
            } else {
                self.stopBackgroundKeepalive()
            }
        }
    }
    
    private func stopBackgroundKeepalive() {
        backgroundKeepaliveTimer?.invalidate()
        backgroundKeepaliveTimer = nil
    }
    
    private func endBackgroundTask() {
        stopBackgroundKeepalive()
        
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        
    }
    
    // MARK: - Network Change Monitoring
    
    private func startNetworkMonitoring() {
        print("📡 [NetworkMonitor] Starting network change monitoring")
        
        networkMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            self?.handleNetworkPathChange(path)
        }
        
        networkMonitor?.start(queue: .main)
        
        // Store initial network state
        updateCurrentNetworkInfo()
    }
    
    private func handleNetworkPathChange(_ path: Network.NWPath) {
        let isConnected = path.status == .satisfied
        print("📡 [NetworkMonitor] Network path changed - connected: \(isConnected)")
        
        if isConnected {
            // WiFi reconnected - check if IP or network changed
            checkForIPAddressChange()
        } else {
            // WiFi disconnected
            print("📡 [NetworkMonitor] WiFi disconnected")
            DispatchQueue.main.async { [weak self] in
                if self?.isMacConnected == true {
                    self?.connectionError = "WiFi连接断开"
                }
            }
        }
    }
    
    private func checkForIPAddressChange() {
        let previousSSID = currentWiFiSSID
        let previousIP = currentLocalIP
        
        updateCurrentNetworkInfo()
        
        // Check if WiFi network changed (SSID changed)
        if let prevSSID = previousSSID, let currSSID = currentWiFiSSID, prevSSID != currSSID {
            print("📡 [NetworkMonitor] WiFi network changed from \(prevSSID) to \(currSSID)")
            handleNetworkChange(reason: "WiFi网络更换")
            return
        }
        
        // Check if local IP address changed (same network, but IP changed)
        if let prevIP = previousIP, let currIP = currentLocalIP, prevIP != currIP {
            print("📡 [NetworkMonitor] Local IP changed from \(prevIP) to \(currIP)")
            handleNetworkChange(reason: "IP地址变更")
            return
        }
        
        // If we get here, network reconnected but no significant change detected
        if previousSSID == nil || previousIP == nil {
            print("📡 [NetworkMonitor] WiFi reconnected - first time detection")
            handleNetworkReconnection()
        }
    }
    
    private func updateCurrentNetworkInfo() {
        currentWiFiSSID = getCurrentWiFiSSID()
        currentLocalIP = getCurrentLocalIP()
        print("📡 [NetworkMonitor] Current network - SSID: \(currentWiFiSSID ?? "unknown"), IP: \(currentLocalIP ?? "unknown")")
    }
    
    private func getCurrentWiFiSSID() -> String? {
        // Note: CNCopyCurrentNetworkInfo requires Location permission in iOS 13+ and is deprecated
        // For network change detection, we'll use interface name as a fallback identifier
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let name = String(cString: interface.ifa_name)
            
            // Check if this is the WiFi interface and it's active
            if name == "en0" && (interface.ifa_flags & UInt32(IFF_UP)) != 0 && (interface.ifa_flags & UInt32(IFF_RUNNING)) != 0 {
                // Use interface name + flags as a network identifier
                address = "WiFi-Active-\(interface.ifa_flags)"
                break
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    private func getCurrentLocalIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 interface
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                
                // Check interface name
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // WiFi interface
                    
                    // Convert interface address to a human readable string
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    private func handleNetworkChange(reason: String) {
        print("🔄 [NetworkChange] Handling network change: \(reason)")
        
        // Clear discovered IP since network changed
        discoveredIP = nil
        discoveredIPFailureCount = 0
        supabaseFallbackAttempted = false
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionError = "\(reason) - 重新连接中..."
            self?.discoveredServices.removeAll()
        }
        
        // Cancel existing connection
        if let conn = connection {
            print("🚫 [NetworkChange] Canceling connection due to network change")
            conn.cancel()
            connection = nil
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isMacConnected = false
            self?.isConnecting = false
        }
        
        // Wait a moment for network to stabilize, then reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.handleNetworkReconnection()
        }
    }
    
    private func handleNetworkReconnection() {
        print("🔄 [NetworkReconnection] Handling network reconnection")
        
        if isUsingManualIP && !savedIPAddress.isEmpty {
            // For manual IP, try to reconnect directly
            print("🔄 [NetworkReconnection] Reconnecting to manual IP: \(savedIPAddress)")
            DispatchQueue.main.async { [weak self] in
                self?.connectionError = "网络重连 - 连接到手动IP"
                self?.currentIPSource = "手动设置"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.setupMacConnection()
            }
        } else {
            // For auto-discovery, restart the discovery process
            print("🔄 [NetworkReconnection] Restarting service discovery")
            
            // Cancel current browser and start fresh discovery
            browser?.cancel()
            bonjourTimeoutTimer?.invalidate()
            
            DispatchQueue.main.async { [weak self] in
                self?.macHostAddress = "等待自动发现..."
                self?.currentIPSource = "重新发现"
                self?.connectionError = "网络重连 - 搜索设备中..."
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startBonjourDiscovery()
            }
        }
    }
    
    private func stopNetworkMonitoring() {
        print("📡 [NetworkMonitor] Stopping network monitoring")
        networkMonitor?.cancel()
        networkMonitor = nil
    }
    
    private func handleServerIPChange() {
        print("🔄 [ServerIPChange] Handling potential server IP change")
        
        if isUsingManualIP {
            // For manual IP, don't clear it but increment retry attempts
            print("🔄 [ServerIPChange] Manual IP mode - starting auto-reconnection")
            startAutoReconnection()
        } else {
            // For auto-discovery, clear the discovered IP and restart discovery
            print("🔄 [ServerIPChange] Auto-discovery mode - clearing old IP and restarting discovery")
            
            // Clear old discovered IP
            discoveredIP = nil
            discoveredIPFailureCount = 0
            supabaseFallbackAttempted = false
            
            DispatchQueue.main.async { [weak self] in
                self?.connectionError = "服务器IP可能已变更 - 重新发现中..."
                self?.currentIPSource = "重新发现"
                self?.discoveredServices.removeAll()
                self?.macHostAddress = "等待自动发现..."
            }
            
            // Cancel current browser and restart discovery
            browser?.cancel()
            bonjourTimeoutTimer?.invalidate()
            
            // Wait a moment before restarting discovery
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startBonjourDiscovery()
            }
        }
    }
    
    // MARK: - Public Methods
    
    private func autoReconnectToMac() {
        print("🔄 [autoReconnectToMac] Attempting auto-reconnection")
        
        // Don't interfere with initial discovery
        guard macHostAddress != "等待自动发现..." else {
            print("🔄 [autoReconnectToMac] Initial discovery in progress, skipping auto-reconnect")
            return
        }
        
        // Stop any ongoing auto-reconnection and reset attempts
        stopAutoReconnection()
        resetReconnectionAttempts()
        
        // Cancel any pending timers
        discoveryRetryTimer?.invalidate()
        discoveryRetryTimer = nil
        
        // Reset discovery state
        discoveryRetryCount = 0
        
        // Properly cancel existing connection and browser
        if let existingConnection = connection {
            existingConnection.cancel()
            connection = nil
        }
        
        // Reset UI state
        DispatchQueue.main.async { [weak self] in
            self?.isMacConnected = false
            self?.isConnecting = false
        }
        
        // Always reload saved IP settings to ensure we have the latest configuration
        loadSavedIPSettings()
        
        // Prioritize saved IP address for auto-reconnect
        if !savedIPAddress.isEmpty {
            // Temporarily switch to use the saved IP for auto-reconnect
            let wasUsingManualIP = isUsingManualIP
            macHostAddress = savedIPAddress
            isUsingManualIP = true
            
            DispatchQueue.main.async { [weak self] in
                self?.connectionError = "自动重连到: \(self?.savedIPAddress ?? "")"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setupMacConnection()
                // Restore original setting after connection attempt
                self?.isUsingManualIP = wasUsingManualIP
            }
        } else {
            // Fall back to manual reconnect logic if no saved IP
            reconnectToMac()
        }
    }
    
    func reconnectToMac() {
        
        // Stop any ongoing auto-reconnection and reset attempts
        stopAutoReconnection()
        resetReconnectionAttempts()
        
        // Cancel any pending timers
        discoveryRetryTimer?.invalidate()
        discoveryRetryTimer = nil
        
        // Reset discovery state
        discoveryRetryCount = 0
        
        // Properly cancel existing connection and browser
        if let existingConnection = connection {
            existingConnection.cancel()
            connection = nil
        }
        
        // Reset UI state
        DispatchQueue.main.async { [weak self] in
            self?.isMacConnected = false
            self?.isConnecting = false
            self?.discoveredServices.removeAll()
        }
        
        // Reload saved IP settings to ensure we use the latest configuration
        loadSavedIPSettings()
        
        if isUsingManualIP {
            // Prioritize saved manual IP
            DispatchQueue.main.async { [weak self] in
                self?.connectionError = "重新连接到: \(self?.macHostAddress ?? "")"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setupMacConnection()
            }
        } else {
            // Start fresh Bonjour discovery
            print("🚫 [CANCEL-5] reconnectToMac canceling browser")
            browser?.cancel()
            DispatchQueue.main.async { [weak self] in
                self?.macHostAddress = "等待自动发现..."
                self?.connectionError = "正在搜索 Mac 应用..."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startBonjourDiscovery()
            }
        }
    }
    
    func setMacIPAddress(_ ipAddress: String) {
        print("🔧 [Manual IP] Setting manual IP: \(ipAddress)")
        
        // Save to UserDefaults
        UserDefaults.standard.set(ipAddress, forKey: manualIPKey)
        UserDefaults.standard.set(true, forKey: useManualIPKey)
        
        // Update state
        macHostAddress = ipAddress
        savedIPAddress = ipAddress
        isUsingManualIP = true
        
        // Reset discovered IP failure tracking since we're switching to manual
        discoveredIPFailureCount = 0
        
        // Cancel browser since we're using manual IP
        print("🚫 [CANCEL-6] setMacIPAddress canceling browser")
        browser?.cancel()
        
        // Clear existing connection
        if let existingConnection = connection {
            print("🚫 [CANCEL-7] setMacIPAddress canceling existing connection (state: \(existingConnection.state))")
            existingConnection.cancel()
            connection = nil
        }
        
        // Reset connection state and connect
        DispatchQueue.main.async { [weak self] in
            self?.connectionError = "连接到手动设置IP: \(ipAddress)"
            self?.currentIPSource = "手动设置"
            self?.isMacConnected = false
            self?.isConnecting = false
        }
        
        setupMacConnection()
    }
    
    func clearManualIPAndUseBonjour() {
        
        // Stop any ongoing auto-reconnection and reset attempts
        stopAutoReconnection()
        resetReconnectionAttempts()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: manualIPKey)
        UserDefaults.standard.set(false, forKey: useManualIPKey)
        
        // Update state
        isUsingManualIP = false
        
        // Cancel current connection
        shouldAutoReconnect = false  // Temporarily disable auto-reconnect
        if let existingConnection = connection {
            print("🚫 [CANCEL-8] clearManualIPAndUseBonjour canceling connection (state: \(existingConnection.state))")
            existingConnection.cancel()
        }
        connection = nil
        
        // Reset discovered IP tracking
        discoveredIP = nil
        discoveredIPFailureCount = 0
        supabaseFallbackAttempted = false
        
        // Reset network monitoring state for fresh discovery
        currentWiFiSSID = nil
        currentLocalIP = nil
        updateCurrentNetworkInfo()
        
        // Reset UI and start Bonjour discovery
        DispatchQueue.main.async { [weak self] in
            self?.isMacConnected = false
            self?.isConnecting = false
            self?.macHostAddress = "等待自动发现..."
            self?.currentIPSource = "自动发现"
            self?.connectionError = "切换到自动发现模式..."
            self?.discoveredServices.removeAll()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.shouldAutoReconnect = true  // Re-enable auto-reconnect
            self?.startBonjourDiscovery()
        }
    }
    
    deinit {
        print("🧹 [WatchConnectivityBridge] Cleaning up")
        stopNetworkMonitoring()
        browser?.cancel()
        connection?.cancel()
        messageTimer?.invalidate()
        reconnectionTimer?.invalidate()
        discoveryRetryTimer?.invalidate()
        bonjourTimeoutTimer?.invalidate()
        connectionTimeoutTimer?.invalidate()
        endBackgroundTask()
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            switch activationState {
            case .activated:
                self?.isWatchConnected = session.isPaired
            case .inactive:
                self?.isWatchConnected = false
            case .notActivated:
                self?.isWatchConnected = false
            @unknown default:
                self?.isWatchConnected = false
            }
            
            if let error = error {
                self?.connectionError = error.localizedDescription
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate the session for new Apple Watch
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchConnected = session.isPaired
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchConnected = session.isPaired && session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        
        // Handle minimal scroll messages (a=1 is scroll action)
        if let action = message["a"] as? Int, action == 1 {
            DispatchQueue.main.async {
                self.scrollCount += 1
            }
        }
        
        // Forward message to Mac (will auto-reconnect if needed)
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
                "source": "iPhone bridge"
            ] as [String: Any]
            
            replyHandler(statusResponse)
            
            // Also forward request to Mac (will auto-reconnect if needed)
            sendToMac(message)
        } else {
            // Forward other messages normally (will auto-reconnect if needed)
            sendToMac(message)
            replyHandler(["status": "forwarded_to_mac"])
        }
    }
}
