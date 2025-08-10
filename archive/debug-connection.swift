#!/usr/bin/env swift

import Foundation
import WatchConnectivity

// Simple test to check WatchConnectivity status
class ConnectionDebugger: NSObject, WCSessionDelegate {
    
    override init() {
        super.init()
        setupSession()
    }
    
    func setupSession() {
        print("🔍 WatchConnectivity Debug")
        print("========================")
        
        guard WCSession.isSupported() else {
            print("❌ WatchConnectivity not supported")
            return
        }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
        
        print("✅ Session activation requested")
        print("📱 Current state:")
        print("   - Supported: \(WCSession.isSupported())")
        print("   - Activation state: \(session.activationState.rawValue)")
        
        // Check after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("\n📊 After 3 seconds:")
            print("   - Activation state: \(session.activationState.rawValue)")
            print("   - Is paired: \(session.isPaired)")
            print("   - Is reachable: \(session.isReachable)")
            print("   - Watch app installed: \(session.isWatchAppInstalled)")
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("🎯 Session activation completed!")
        print("   - State: \(activationState.rawValue)")
        if let error = error {
            print("   - Error: \(error)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️  Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️  Session deactivated")
    }
}

let debugger = ConnectionDebugger()
RunLoop.main.run()