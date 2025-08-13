import Foundation
import Network
import Combine

protocol DiscoveryServiceDelegate: AnyObject {
    func discoveryService(_ service: DiscoveryService, didDiscoverIP ipAddress: String, source: String)
    func discoveryService(_ service: DiscoveryService, didFailWithError error: String)
}

class DiscoveryService: ObservableObject {
    weak var delegate: DiscoveryServiceDelegate?
    
    @Published var discoveredServices: [String] = []
    @Published var isDiscovering = false
    
    // Discovery methods priority order
    private enum DiscoveryMethod {
        case cached, manual, bonjour, supabase
    }
    
    // Cache management
    private var cachedIP: String?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // Bonjour discovery
    private var browser: NWBrowser?
    private var discoveryTimer: Timer?
    private let discoveryTimeout: TimeInterval = 5.0 // Unified timeout
    
    // Supabase configuration
    private let supabaseUrl = "https://qeioxayacjcrbxbuqzef.functions.supabase.co"
    private let uuid = "zaynjarvis"
    
    // UserDefaults keys
    private let manualIPKey = "WatchScroller_ManualIP"
    private let useManualIPKey = "WatchScroller_UseManualIP"
    private let cachedIPKey = "WatchScroller_CachedIP"
    private let cacheTimestampKey = "WatchScroller_CacheTimestamp"
    
    init() {
        loadCachedIP()
    }
    
    // MARK: - Public Interface
    
    func startDiscovery() {
        guard !isDiscovering else { return }
        
        print("🔍 [DiscoveryService] Starting IP discovery")
        isDiscovering = true
        
        // Try discovery methods in priority order
        tryDiscoveryMethod(.cached)
    }
    
    func clearCache() {
        cachedIP = nil
        cacheTimestamp = nil
        UserDefaults.standard.removeObject(forKey: cachedIPKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        print("🗑️ [DiscoveryService] Cache cleared")
    }
    
    func stopDiscovery() {
        isDiscovering = false
        browser?.cancel()
        browser = nil
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        print("🛑 [DiscoveryService] Discovery stopped")
    }
    
    // MARK: - Discovery Methods
    
    private func tryDiscoveryMethod(_ method: DiscoveryMethod) {
        switch method {
        case .cached:
            if let ip = getCachedIP() {
                print("💾 [DiscoveryService] Using cached IP: \(ip)")
                cacheIP(ip)
                delegate?.discoveryService(self, didDiscoverIP: ip, source: "缓存")
                return
            }
            tryDiscoveryMethod(.manual)
            
        case .manual:
            if let ip = getManualIP() {
                print("🔧 [DiscoveryService] Using manual IP: \(ip)")
                cacheIP(ip)
                delegate?.discoveryService(self, didDiscoverIP: ip, source: "手动设置")
                return
            }
            tryDiscoveryMethod(.bonjour)
            
        case .bonjour:
            startBonjourDiscovery { [weak self] ip in
                if let ip = ip {
                    print("📡 [DiscoveryService] Bonjour discovered IP: \(ip)")
                    self?.cacheIP(ip)
                    self?.delegate?.discoveryService(self!, didDiscoverIP: ip, source: "自动发现")
                } else {
                    self?.tryDiscoveryMethod(.supabase)
                }
            }
            
        case .supabase:
            startSupabaseDiscovery { [weak self] ip in
                if let ip = ip {
                    print("🌐 [DiscoveryService] Supabase discovered IP: \(ip)")
                    self?.cacheIP(ip)
                    self?.delegate?.discoveryService(self!, didDiscoverIP: ip, source: "备用发现")
                } else {
                    self?.isDiscovering = false
                    self?.delegate?.discoveryService(self!, didFailWithError: "无法找到 Mac 应用")
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func loadCachedIP() {
        cachedIP = UserDefaults.standard.string(forKey: cachedIPKey)
        if let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date {
            cacheTimestamp = timestamp
        }
    }
    
    private func getCachedIP() -> String? {
        guard let ip = cachedIP,
              let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < cacheValidityDuration else {
            return nil
        }
        
        // Filter out invalid IP addresses (link-local, scope identifiers)
        if ip.contains("%") || ip.hasPrefix("169.254.") || ip.hasPrefix("fe80::") {
            print("🗑️ [DiscoveryService] Cached IP is invalid: \(ip), clearing cache")
            clearCache()
            return nil
        }
        
        return ip
    }
    
    private func cacheIP(_ ip: String) {
        cachedIP = ip
        cacheTimestamp = Date()
        UserDefaults.standard.set(ip, forKey: cachedIPKey)
        UserDefaults.standard.set(cacheTimestamp, forKey: cacheTimestampKey)
    }
    
    private func getManualIP() -> String? {
        let useManualIP = UserDefaults.standard.bool(forKey: useManualIPKey)
        let savedIP = UserDefaults.standard.string(forKey: manualIPKey)
        
        guard useManualIP, let ip = savedIP, !ip.isEmpty else {
            return nil
        }
        return ip
    }
    
    // MARK: - Bonjour Discovery
    
    private func startBonjourDiscovery(completion: @escaping (String?) -> Void) {
        print("📡 [DiscoveryService] Starting Bonjour discovery")
        
        // Set timeout
        discoveryTimer?.invalidate()
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: discoveryTimeout, repeats: false) { _ in
            print("⏰ [DiscoveryService] Bonjour discovery timeout")
            completion(nil)
        }
        
        // Preflight permission check
        performPreflightCheck()
        
        // Create browser
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        parameters.requiredInterfaceType = .wifi
        
        browser = NWBrowser(for: .bonjour(type: "_watchscroller._tcp", domain: nil), using: parameters)
        
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.discoveredServices = results.map { "\($0.endpoint)" }
            }
            
            if !results.isEmpty {
                let endpoints = results.map { $0.endpoint }
                self.resolveServicesSequentially(endpoints, completion: completion)
            } else {
                print("🔍 [DiscoveryService] No Bonjour services found")
                // Don't call completion here - let timeout handle it
            }
        }
        
        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("📡 [DiscoveryService] Bonjour browser ready")
            case .failed(let error):
                print("❌ [DiscoveryService] Bonjour failed: \(error)")
                completion(nil)
            default:
                break
            }
        }
        
        browser?.start(queue: .main)
    }
    
    private func performPreflightCheck() {
        // Lightweight permission check
        let preflightBrowser = NWBrowser(for: .bonjour(type: "_preflight._tcp", domain: nil), using: NWParameters())
        preflightBrowser.stateUpdateHandler = { state in
            preflightBrowser.cancel()
        }
        preflightBrowser.start(queue: .main)
        
        // UDP broadcast for iOS 18
        let udpConnection = NWConnection(host: "255.255.255.255", port: 12345, using: .udp)
        udpConnection.stateUpdateHandler = { state in
            if state == .ready {
                udpConnection.send(content: "WatchScroller".data(using: .utf8)!, completion: .contentProcessed { _ in
                    udpConnection.cancel()
                })
            }
        }
        udpConnection.start(queue: .main)
    }
    
    private func resolveServicesSequentially(_ endpoints: [NWEndpoint], completion: @escaping (String?) -> Void) {
        guard !endpoints.isEmpty else {
            completion(nil)
            return
        }
        
        let firstEndpoint = endpoints[0]
        let remainingEndpoints = Array(endpoints.dropFirst())
        
        print("🔍 [DiscoveryService] Resolving service \(firstEndpoint)")
        
        resolveService(firstEndpoint) { [weak self] ipAddress in
            if let validIP = ipAddress {
                // Found valid IP, use it
                completion(validIP)
            } else {
                // This service had invalid IP, try next one
                print("🔍 [DiscoveryService] Service had invalid IP, trying next...")
                self?.resolveServicesSequentially(remainingEndpoints, completion: completion)
            }
        }
    }
    
    private func resolveService(_ endpoint: NWEndpoint, completion: @escaping (String?) -> Void) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let remoteEndpoint = connection.currentPath?.remoteEndpoint,
                   case let .hostPort(host: host, port: _) = remoteEndpoint {
                    if let ipAddress = self?.extractIP(from: host) {
                        print("🔍 [resolveService] Successfully resolved valid IP: \(ipAddress)")
                        self?.discoveryTimer?.invalidate()
                        completion(ipAddress)
                    } else {
                        print("🔍 [resolveService] IP was filtered out, trying next service")
                        completion(nil)
                    }
                } else {
                    print("🔍 [resolveService] No remote endpoint found")
                    completion(nil)
                }
                connection.cancel()
            case .failed(_):
                connection.cancel()
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    private func extractIP(from host: NWEndpoint.Host) -> String? {
        switch host {
        case .ipv4(let address):
            let ipString = "\(address)"
            // Filter out link-local IPv4 addresses and scope identifiers
            if ipString.hasPrefix("169.254.") || ipString.contains("%") {
                print("🔍 [extractIP] Filtering invalid IPv4: \(ipString)")
                return nil
            }
            return ipString
        case .ipv6(let address):
            let ipString = "\(address)"
            // Filter out link-local IPv6 addresses (fe80::) and scope identifiers
            if ipString.hasPrefix("fe80::") || ipString.contains("%") {
                print("🔍 [extractIP] Filtering invalid IPv6: \(ipString)")
                return nil
            }
            return ipString
        case .name(let hostname, _):
            let resolvedIP = resolveHostnameToIP(hostname) ?? hostname
            // Filter resolved IPs as well
            if resolvedIP.hasPrefix("169.254.") || resolvedIP.hasPrefix("fe80::") || resolvedIP.contains("%") {
                print("🔍 [extractIP] Filtering invalid resolved IP: \(resolvedIP)")
                return nil
            }
            return resolvedIP
        @unknown default:
            return nil
        }
    }
    
    private func resolveHostnameToIP(_ hostname: String) -> String? {
        let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
            for case let address as NSData in addresses {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(address.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(address.length), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    return String(cString: hostname)
                }
            }
        }
        return nil
    }
    
    // MARK: - Supabase Discovery
    
    private func startSupabaseDiscovery(completion: @escaping (String?) -> Void) {
        print("🌐 [DiscoveryService] Starting Supabase discovery")
        
        guard let url = URL(string: "\(supabaseUrl)/get-ip?uuid=\(uuid)") else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ [DiscoveryService] Supabase error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ [DiscoveryService] Invalid Supabase response")
                completion(nil)
                return
            }
            
            let ipAddress: String?
            if let dataObject = json["data"] as? [String: Any] {
                ipAddress = dataObject["ip"] as? String
            } else {
                ipAddress = json["ip"] as? String
            }
            
            completion(ipAddress)
        }
        
        task.resume()
    }
    
    deinit {
        stopDiscovery()
    }
}

// MARK: - Manual IP Management Extension

extension DiscoveryService {
    func setManualIP(_ ip: String) {
        UserDefaults.standard.set(ip, forKey: manualIPKey)
        UserDefaults.standard.set(true, forKey: useManualIPKey)
        cacheIP(ip) // Also cache it
        print("🔧 [DiscoveryService] Manual IP set: \(ip)")
    }
    
    func clearManualIP() {
        UserDefaults.standard.removeObject(forKey: manualIPKey)
        UserDefaults.standard.set(false, forKey: useManualIPKey)
        print("🗑️ [DiscoveryService] Manual IP cleared")
    }
    
    var isUsingManualIP: Bool {
        return UserDefaults.standard.bool(forKey: useManualIPKey)
    }
    
    var savedManualIP: String {
        return UserDefaults.standard.string(forKey: manualIPKey) ?? ""
    }
}