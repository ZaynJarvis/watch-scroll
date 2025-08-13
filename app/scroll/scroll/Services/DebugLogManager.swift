import Foundation
import Combine

class DebugLogManager: ObservableObject {
    static let shared = DebugLogManager()
    
    @Published var logs: [LogEntry] = []
    @Published var isDebugMode = false
    
    private let maxLogs = 100
    private let dateFormatter: DateFormatter
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let category: String
        let message: String
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return formatter.string(from: timestamp)
        }
        
        var icon: String {
            switch level {
            case .info: return "📱"
            case .success: return "✅"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .network: return "📡"
            case .discovery: return "🔍"
            case .connection: return "🔌"
            }
        }
    }
    
    enum LogLevel {
        case info, success, warning, error, network, discovery, connection
        
        var color: String {
            switch self {
            case .info: return "#007AFF"      // Blue
            case .success: return "#34C759"    // Green
            case .warning: return "#FF9500"    // Orange
            case .error: return "#FF3B30"      // Red
            case .network: return "#5856D6"    // Purple
            case .discovery: return "#00C7BE"  // Teal
            case .connection: return "#FF6482" // Pink
            }
        }
    }
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        
        // Load debug mode preference
        isDebugMode = UserDefaults.standard.bool(forKey: "DebugModeEnabled")
    }
    
    func log(_ message: String, level: LogLevel = .info, category: String = "System") {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.logs.insert(entry, at: 0)
            
            // Keep only recent logs
            if self.logs.count > self.maxLogs {
                self.logs = Array(self.logs.prefix(self.maxLogs))
            }
        }
        
        // Also print to console for debugging
        print("\(entry.icon) [\(category)] \(message)")
    }
    
    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
        }
    }
    
    func toggleDebugMode() {
        isDebugMode.toggle()
        UserDefaults.standard.set(isDebugMode, forKey: "DebugModeEnabled")
        
        if isDebugMode {
            log("Debug mode enabled", level: .success, category: "Debug")
        } else {
            log("Debug mode disabled", level: .info, category: "Debug")
        }
    }
}

// MARK: - Global Logging Functions

func logInfo(_ message: String, category: String = "System") {
    DebugLogManager.shared.log(message, level: .info, category: category)
}

func logSuccess(_ message: String, category: String = "System") {
    DebugLogManager.shared.log(message, level: .success, category: category)
}

func logWarning(_ message: String, category: String = "System") {
    DebugLogManager.shared.log(message, level: .warning, category: category)
}

func logError(_ message: String, category: String = "System") {
    DebugLogManager.shared.log(message, level: .error, category: category)
}

func logNetwork(_ message: String) {
    DebugLogManager.shared.log(message, level: .network, category: "Network")
}

func logDiscovery(_ message: String) {
    DebugLogManager.shared.log(message, level: .discovery, category: "Discovery")
}

func logConnection(_ message: String) {
    DebugLogManager.shared.log(message, level: .connection, category: "Connection")
}