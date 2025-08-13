import Foundation
import Network
import SystemConfiguration
import Combine

protocol NetworkMonitorDelegate: AnyObject {
    func networkMonitor(_ monitor: NetworkMonitor, didDetectNetworkChange reason: String)
    func networkMonitor(_ monitor: NetworkMonitor, didDetectIPChange oldIP: String?, newIP: String?)
    func networkMonitor(_ monitor: NetworkMonitor, didDetectWiFiChange oldSSID: String?, newSSID: String?)
}

class NetworkMonitor: ObservableObject {
    weak var delegate: NetworkMonitorDelegate?
    
    @Published var isNetworkAvailable = false
    @Published var currentIP: String?
    @Published var currentWiFiSSID: String?
    @Published var networkType: String = "未知"
    
    // Network monitoring
    private var pathMonitor: NWPathMonitor?
    private var monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")
    
    // Network state tracking
    private var previousIP: String?
    private var previousSSID: String?
    private var isMonitoring = false
    
    // Interface flags for network monitoring
    private let IFF_UP: Int32 = 0x1
    private let IFF_RUNNING: Int32 = 0x40
    
    init() {
        updateCurrentNetworkInfo()
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        print("📡 [NetworkMonitor] Starting network monitoring")
        isMonitoring = true
        
        // Store initial state
        previousIP = currentIP
        previousSSID = currentWiFiSSID
        
        // Start path monitoring
        pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
        pathMonitor?.start(queue: monitorQueue)
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("📡 [NetworkMonitor] Stopping network monitoring")
        isMonitoring = false
        
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    func forceNetworkCheck() {
        print("📡 [NetworkMonitor] Force checking network state")
        updateCurrentNetworkInfo()
        checkForChanges()
    }
    
    // MARK: - Network Path Monitoring
    
    private func handlePathUpdate(_ path: NWPath) {
        let wasAvailable = isNetworkAvailable
        isNetworkAvailable = (path.status == .satisfied)
        
        // Update network type
        if path.usesInterfaceType(.wifi) {
            networkType = "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            networkType = "蜂窝网络"
        } else if path.usesInterfaceType(.wiredEthernet) {
            networkType = "以太网"
        } else {
            networkType = "未知"
        }
        
        print("📡 [NetworkMonitor] Network path updated - available: \(isNetworkAvailable), type: \(networkType)")
        
        if isNetworkAvailable && !wasAvailable {
            // Network became available
            print("📡 [NetworkMonitor] Network reconnected")
            
            // Delay to let network stabilize
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.handleNetworkReconnected()
            }
        } else if !isNetworkAvailable && wasAvailable {
            // Network became unavailable
            print("📡 [NetworkMonitor] Network disconnected")
            delegate?.networkMonitor(self, didDetectNetworkChange: "网络连接断开")
        }
    }
    
    private func handleNetworkReconnected() {
        print("📡 [NetworkMonitor] Handling network reconnection")
        updateCurrentNetworkInfo()
        checkForChanges()
    }
    
    // MARK: - Network State Detection
    
    private func updateCurrentNetworkInfo() {
        currentIP = getCurrentLocalIP()
        currentWiFiSSID = getCurrentWiFiIdentifier()
    }
    
    private func checkForChanges() {
        let newIP = currentIP
        let newSSID = currentWiFiSSID
        
        // Check for WiFi network change (SSID change)
        if let prevSSID = previousSSID, let currSSID = newSSID, prevSSID != currSSID {
            print("📡 [NetworkMonitor] WiFi network changed: \(prevSSID) → \(currSSID)")
            delegate?.networkMonitor(self, didDetectWiFiChange: prevSSID, newSSID: currSSID)
            delegate?.networkMonitor(self, didDetectNetworkChange: "WiFi网络更换")
        }
        
        // Check for IP address change (same network, different IP)
        else if let prevIP = previousIP, let currIP = newIP, prevIP != currIP {
            print("📡 [NetworkMonitor] IP address changed: \(prevIP) → \(currIP)")
            delegate?.networkMonitor(self, didDetectIPChange: prevIP, newIP: currIP)
            delegate?.networkMonitor(self, didDetectNetworkChange: "IP地址变更")
        }
        
        // Check for first-time network detection
        else if previousIP == nil && newIP != nil {
            print("📡 [NetworkMonitor] Network detected for first time: \(newIP ?? "unknown")")
            // Don't trigger change event for initial detection
        }
        
        // Update previous state
        previousIP = newIP
        previousSSID = newSSID
    }
    
    // MARK: - IP Address Detection
    
    private func getCurrentLocalIP() -> String? {
        // Method 1: Try connection-based IP detection first (more reliable)
        if let connectionIP = getLocalIPViaConnection() {
            return connectionIP
        }
        
        // Method 2: Fallback to interface scanning
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { 
            return nil 
        }
        
        defer { freeifaddrs(ifaddr) }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            // Check for IPv4 interface
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                
                // Check if this is WiFi interface (en0) and it's active
                if name == "en0" && (interface.ifa_flags & UInt32(IFF_UP)) != 0 && (interface.ifa_flags & UInt32(IFF_RUNNING)) != 0 {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    let ipString = String(cString: hostname)
                    
                    // Filter out link-local addresses
                    if !ipString.hasPrefix("169.254.") && !ipString.contains("%") {
                        address = ipString
                        break
                    }
                }
            }
        }
        
        return address
    }
    
    private func getLocalIPViaConnection() -> String? {
        do {
            // Create UDP socket to external server to determine local IP
            let socket = socket(AF_INET, SOCK_DGRAM, 0)
            guard socket != -1 else { return nil }
            defer { close(socket) }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = 0
            inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr)
            
            let connectResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            guard connectResult == 0 else { return nil }
            
            var localAddr = sockaddr_in()
            var localAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let getsocknameResult = withUnsafeMutablePointer(to: &localAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getsockname(socket, $0, &localAddrLen)
                }
            }
            
            guard getsocknameResult == 0 else { return nil }
            
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &localAddr.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return nil
            }
            
            return String(cString: buffer)
        } catch {
            return nil
        }
    }
    
    private func getCurrentWiFiIdentifier() -> String? {
        // Note: CNCopyCurrentNetworkInfo is deprecated and requires location permission
        // We'll use interface state as a network identifier instead
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { 
            return nil 
        }
        
        defer { freeifaddrs(ifaddr) }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let name = String(cString: interface.ifa_name)
            
            // Check if this is the WiFi interface and it's active
            if name == "en0" && (interface.ifa_flags & UInt32(IFF_UP)) != 0 && (interface.ifa_flags & UInt32(IFF_RUNNING)) != 0 {
                // Use interface flags + IP as network identifier (since we can't get SSID reliably)
                if let ip = getCurrentLocalIP() {
                    return "WiFi-\(interface.ifa_flags)-\(ip.suffix(8))"
                } else {
                    return "WiFi-Active-\(interface.ifa_flags)"
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Alternative IP Detection Method
    
    private func getLocalIPViaDNSLookup() -> String? {
        do {
            // Create a socket connection to external server to determine local IP
            let socket = CFSocketCreate(nil, PF_INET, SOCK_DGRAM, IPPROTO_UDP, 0, nil, nil)
            defer { 
                if let socket = socket {
                    CFSocketInvalidate(socket)
                }
            }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = CFSwapInt16HostToBig(53) // DNS port
            inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr)
            
            let data = withUnsafePointer(to: &addr) {
                Data(bytes: $0, count: MemoryLayout<sockaddr_in>.size)
            }
            
            let address = CFDataCreate(nil, data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress }, data.count)
            
            if let socket = socket, let address = address {
                CFSocketConnectToAddress(socket, address, 1)
                
                var localAddr: sockaddr_in = sockaddr_in()
                var localAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                
                let socketNative = CFSocketGetNative(socket)
                if getsockname(socketNative, withUnsafeMutablePointer(to: &localAddr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 } }, &localAddrLen) == 0 {
                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &localAddr.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                    return String(cString: buffer)
                }
            }
        } catch {
            print("❌ [NetworkMonitor] Error getting IP via DNS lookup: \(error)")
        }
        
        return nil
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Network Utilities Extension

extension NetworkMonitor {
    var isWiFiConnected: Bool {
        return isNetworkAvailable && networkType == "WiFi"
    }
    
    var networkDescription: String {
        if !isNetworkAvailable {
            return "网络不可用"
        }
        
        var description = networkType
        if let ip = currentIP {
            description += " (\(ip))"
        }
        return description
    }
    
    func getNetworkDiagnostics() -> [String: Any] {
        return [
            "isNetworkAvailable": isNetworkAvailable,
            "networkType": networkType,
            "currentIP": currentIP ?? "unknown",
            "wifiIdentifier": currentWiFiSSID ?? "unknown",
            "isWiFiConnected": isWiFiConnected,
            "isMonitoring": isMonitoring
        ]
    }
}