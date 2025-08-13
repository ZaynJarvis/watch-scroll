import Foundation
import Combine
import UIKit

class StateManager: ObservableObject {
    // Published properties for UI binding
    @Published var isConnected = false
    @Published var connectionStatus = "初始化中..."
    @Published var currentIPSource = "未连接"
    @Published var macHostAddress = "等待发现..."
    @Published var connectionError: String?
    @Published var discoveredServices: [String] = []
    @Published var isUsingManualIP = false
    @Published var savedIPAddress = ""
    
    // Service instances
    private let discoveryService = DiscoveryService()
    private let connectionManager = ConnectionManager()
    private let networkMonitor = NetworkMonitor()
    
    // Current state
    private var currentIP: String?
    private var discoveryInProgress = false
    
    // App lifecycle monitoring
    private var appStateSubscription: AnyCancellable?
    
    init() {
        setupServiceDelegates()
        setupAppLifecycleMonitoring()
        loadInitialState()
        startServices()
    }
    
    // MARK: - Service Setup
    
    private func setupServiceDelegates() {
        discoveryService.delegate = self
        connectionManager.delegate = self
        networkMonitor.delegate = self
    }
    
    private func setupAppLifecycleMonitoring() {
        appStateSubscription = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWentToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    private func loadInitialState() {
        // Load saved settings
        savedIPAddress = discoveryService.savedManualIP
        isUsingManualIP = discoveryService.isUsingManualIP
        
        if isUsingManualIP && !savedIPAddress.isEmpty {
            macHostAddress = savedIPAddress
            currentIPSource = "手动设置"
        } else {
            macHostAddress = "等待自动发现..."
            currentIPSource = "自动发现"
        }
        
        print("📱 [StateManager] Initial state loaded - manual IP: \(isUsingManualIP), address: \(macHostAddress)")
    }
    
    private func startServices() {
        print("📱 [StateManager] Starting services")
        
        // Start network monitoring
        networkMonitor.startMonitoring()
        
        // Start discovery if not using manual IP or if manual IP connection fails
        if !isUsingManualIP {
            startDiscovery()
        } else {
            // Try connecting to manual IP
            connectToCurrentIP()
        }
    }
    
    // MARK: - Discovery Management
    
    private func startDiscovery() {
        guard !discoveryInProgress else {
            logWarning("Discovery already in progress", category: "StateManager")
            return
        }
        
        logDiscovery("Starting IP discovery")
        discoveryInProgress = true
        connectionError = "正在搜索 Mac 应用..."
        currentIPSource = isUsingManualIP ? "手动设置" : "自动发现"
        
        discoveryService.startDiscovery()
    }
    
    private func stopDiscovery() {
        print("🔍 [StateManager] Stopping discovery")
        discoveryInProgress = false
        discoveryService.stopDiscovery()
    }
    
    // MARK: - Connection Management
    
    private func connectToCurrentIP() {
        guard let ip = currentIP, !ip.isEmpty, ip != "等待自动发现..." else {
            print("❌ [StateManager] No valid IP to connect to")
            return
        }
        
        print("🔌 [StateManager] Connecting to IP: \(ip)")
        connectionManager.connect(to: ip)
    }
    
    private func disconnect() {
        print("🔌 [StateManager] Disconnecting")
        connectionManager.disconnect()
        isConnected = false
        connectionStatus = "已断开"
    }
    
    // MARK: - Public Interface
    
    func reconnect() {
        print("🔄 [StateManager] Manual reconnect requested")
        
        // Stop current operations
        stopDiscovery()
        disconnect()
        
        // Reset state
        connectionError = nil
        discoveredServices.removeAll()
        
        // Reload settings
        loadInitialState()
        
        // Start fresh discovery or connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if self?.isUsingManualIP == true {
                self?.connectToCurrentIP()
            } else {
                self?.startDiscovery()
            }
        }
    }
    
    func setManualIP(_ ip: String) {
        print("🔧 [StateManager] Setting manual IP: \(ip)")
        
        // Stop current operations
        stopDiscovery()
        disconnect()
        
        // Update discovery service
        discoveryService.setManualIP(ip)
        discoveryService.clearCache() // Clear cache to force using new IP
        
        // Update state
        savedIPAddress = ip
        macHostAddress = ip
        isUsingManualIP = true
        currentIPSource = "手动设置"
        currentIP = ip
        connectionError = "连接到手动IP: \(ip)"
        
        // Connect to manual IP
        connectToCurrentIP()
    }
    
    func clearManualIP() {
        print("🗑️ [StateManager] Clearing manual IP")
        
        // Stop current operations
        stopDiscovery()
        disconnect()
        
        // Update discovery service
        discoveryService.clearManualIP()
        
        // Reset state
        isUsingManualIP = false
        macHostAddress = "等待自动发现..."
        currentIPSource = "自动发现"
        currentIP = nil
        connectionError = "切换到自动发现模式..."
        discoveredServices.removeAll()
        
        // Start auto-discovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startDiscovery()
        }
    }
    
    func sendMessage(_ message: [String: Any]) {
        connectionManager.sendMessage(message)
    }
    
    func forceHealthCheck() {
        connectionManager.forceHealthCheck()
    }
    
    // MARK: - App Lifecycle Handling
    
    @objc private func handleAppWentToBackground() {
        print("📱 [StateManager] App went to background")
        connectionManager.handleAppWentToBackground()
    }
    
    private func handleAppBecameActive() {
        print("📱 [StateManager] App became active")
        connectionManager.handleAppBecameActive()
        
        // Force network check
        networkMonitor.forceNetworkCheck()
        
        // Check connection health if connected
        if isConnected {
            forceHealthCheck()
        }
    }
    
    deinit {
        print("📱 [StateManager] Deinitializing")
        stopDiscovery()
        disconnect()
        networkMonitor.stopMonitoring()
        NotificationCenter.default.removeObserver(self)
        appStateSubscription?.cancel()
    }
}

// MARK: - DiscoveryServiceDelegate

extension StateManager: DiscoveryServiceDelegate {
    func discoveryService(_ service: DiscoveryService, didDiscoverIP ipAddress: String, source: String) {
        logSuccess("Discovery found IP: \(ipAddress), source: \(source)", category: "StateManager")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.discoveryInProgress = false
            self.currentIP = ipAddress
            self.macHostAddress = ipAddress
            self.currentIPSource = source
            self.connectionError = nil
            
            // Update discovered services list
            if !self.discoveredServices.contains(ipAddress) {
                self.discoveredServices.append(ipAddress)
            }
            
            // Connect to discovered IP
            self.connectToCurrentIP()
        }
    }
    
    func discoveryService(_ service: DiscoveryService, didFailWithError error: String) {
        logError("Discovery failed: \(error)", category: "StateManager")
        
        DispatchQueue.main.async { [weak self] in
            self?.discoveryInProgress = false
            self?.connectionError = error
            self?.currentIPSource = "发现失败"
        }
    }
}

// MARK: - ConnectionManagerDelegate

extension StateManager: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didConnect to: String) {
        logSuccess("Connected to: \(to)", category: "StateManager")
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
            self?.connectionStatus = "已连接"
            self?.connectionError = nil
        }
    }
    
    func connectionManager(_ manager: ConnectionManager, didDisconnectFrom host: String, error: String?) {
        logError("Disconnected from: \(host), error: \(error ?? "none")", category: "StateManager")
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.connectionStatus = "已断开"
            self?.connectionError = error
            
            // If this was due to network issues, trigger rediscovery
            if let error = error, error.contains("网络") {
                self?.handleNetworkIssue()
            }
        }
    }
    
    func connectionManager(_ manager: ConnectionManager, didFailToConnect to: String, error: String) {
        logError("Failed to connect to: \(to), error: \(error)", category: "StateManager")
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.connectionStatus = "连接失败"
            self?.connectionError = "连接失败: \(error)"
            
            // If connection failed and we're using auto-discovery, try rediscovery
            if self?.isUsingManualIP == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.handleConnectionFailure()
                }
            }
        }
    }
    
    func connectionManager(_ manager: ConnectionManager, didReceiveData data: Data, from host: String) {
        // Handle received data if needed (for future features)
        // Currently just used for connection health monitoring
    }
    
    private func handleConnectionFailure() {
        print("🔄 [StateManager] Handling connection failure - triggering rediscovery")
        
        // Clear cache and restart discovery
        discoveryService.clearCache()
        currentIP = nil
        macHostAddress = "等待重新发现..."
        currentIPSource = "重新发现中"
        startDiscovery()
    }
    
    private func handleNetworkIssue() {
        print("📡 [StateManager] Handling network issue")
        
        connectionError = "网络问题 - 等待网络恢复..."
        
        // Network monitor will handle the actual network change detection
        // and trigger appropriate actions
    }
}

// MARK: - NetworkMonitorDelegate

extension StateManager: NetworkMonitorDelegate {
    func networkMonitor(_ monitor: NetworkMonitor, didDetectNetworkChange reason: String) {
        print("📡 [StateManager] Network change detected: \(reason)")
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionError = "\(reason) - 重新连接中..."
            
            // Disconnect current connection
            self?.disconnect()
            
            // Clear discovery cache since network changed
            self?.discoveryService.clearCache()
            self?.discoveredServices.removeAll()
            
            // Wait for network to stabilize, then reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self?.handleNetworkReconnection()
            }
        }
    }
    
    func networkMonitor(_ monitor: NetworkMonitor, didDetectIPChange oldIP: String?, newIP: String?) {
        print("📡 [StateManager] IP change: \(oldIP ?? "none") → \(newIP ?? "none")")
        // Handled by didDetectNetworkChange
    }
    
    func networkMonitor(_ monitor: NetworkMonitor, didDetectWiFiChange oldSSID: String?, newSSID: String?) {
        print("📡 [StateManager] WiFi change: \(oldSSID ?? "none") → \(newSSID ?? "none")")
        // Handled by didDetectNetworkChange  
    }
    
    private func handleNetworkReconnection() {
        print("🔄 [StateManager] Handling network reconnection")
        
        if isUsingManualIP {
            // For manual IP, try reconnecting directly
            connectionError = "网络重连 - 连接到手动IP"
            connectToCurrentIP()
        } else {
            // For auto-discovery, restart discovery process
            macHostAddress = "等待重新发现..."
            currentIPSource = "重新发现"
            connectionError = "网络重连 - 搜索设备中..."
            startDiscovery()
        }
    }
}