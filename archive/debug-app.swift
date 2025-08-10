#!/usr/bin/env swift

import Foundation
import Network
import Cocoa

print("🧪 Debug WatchScroller Network Test")
print("===================================")

// Test 1: Basic Network Framework
print("\n📋 Test 1: Network Framework Basic Test")
do {
    let listener = try NWListener(using: .tcp)
    print("✅ Basic NWListener created")
    
    var listenerStarted = false
    listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
            if let port = listener.port {
                print("🎉 Listener ready on auto-assigned port: \(port)")
            } else {
                print("🎉 Listener ready (no port info)")
            }
            listenerStarted = true
        case .failed(let error):
            print("❌ Listener failed: \(error)")
            listenerStarted = true
        default:
            print("🔄 Listener state: \(state)")
        }
    }
    
    listener.start(queue: .main)
    
    // Wait for listener to start
    var timeout = 0
    while !listenerStarted && timeout < 50 {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        timeout += 1
    }
    
    if !listenerStarted {
        print("⚠️ Listener did not start within timeout")
    }
    
    listener.cancel()
    
} catch {
    print("❌ Failed to create basic listener: \(error)")
}

// Test 2: Specific Port
print("\n📋 Test 2: Specific Port Test (8888)")
do {
    let parameters = NWParameters.tcp
    let port = NWEndpoint.Port(rawValue: 8888)!
    let listener = try NWListener(using: parameters, on: port)
    print("✅ Port-specific listener created")
    
    var specificListenerStarted = false
    listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
            print("🎉 Listener ready on port 8888!")
            specificListenerStarted = true
        case .failed(let error):
            print("❌ Listener failed on port 8888: \(error)")
            specificListenerStarted = true
        default:
            print("🔄 Listener state: \(state)")
        }
    }
    
    listener.start(queue: .main)
    
    // Wait for listener to start
    var timeout = 0
    while !specificListenerStarted && timeout < 50 {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        timeout += 1
    }
    
    if !specificListenerStarted {
        print("⚠️ Port 8888 listener did not start within timeout")
    }
    
    listener.cancel()
    
} catch {
    print("❌ Failed to create port 8888 listener: \(error)")
}

print("\n🏁 Debug test completed")