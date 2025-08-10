#!/usr/bin/env swift

import Foundation
import Network

print("🧪 Testing Network Framework...")

// Test 1: Simple listener
print("📋 Test 1: Basic listener creation...")
do {
    let listener = try NWListener(using: .tcp)
    print("✅ Basic NWListener created (auto port)")
    
    listener.stateUpdateHandler = { state in
        print("📡 Listener state: \(state)")
    }
    
    print("🚀 Starting basic listener...")
    listener.start(queue: .main)
    
    // Wait briefly
    usleep(100000) // 0.1 second
    
    listener.cancel()
} catch {
    print("❌ Failed to create basic listener: \(error)")
}

print("\n📋 Test 2: Listener on specific port...")
do {
    let parameters = NWParameters.tcp
    let port = NWEndpoint.Port(rawValue: 9999)!
    let listener = try NWListener(using: parameters, on: port)
    print("✅ Port-specific NWListener created")
    
    listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
            print("🎉 Listener ready on port 9999!")
            // Check if we can see it with lsof
            let task = Process()
            task.launchPath = "/usr/sbin/lsof"
            task.arguments = ["-i", ":9999"]
            task.launch()
            task.waitUntilExit()
        case .failed(let error):
            print("❌ Listener failed: \(error)")
        default:
            print("🔄 Listener state: \(state)")
        }
    }
    
    listener.start(queue: .main)
    
    // Wait 2 seconds
    RunLoop.current.run(until: Date().addingTimeInterval(2))
    
    listener.cancel()
} catch {
    print("❌ Failed to create port-specific listener: \(error)")
}