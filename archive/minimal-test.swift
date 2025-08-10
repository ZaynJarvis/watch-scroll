#!/usr/bin/env swift

import Foundation
import Cocoa

// Simple test to verify we can run GUI apps
class TestApp: NSApplication {
    override func finishLaunching() {
        super.finishLaunching()
        print("🎉 Minimal test app launched successfully!")
        
        // Create a simple status bar item like our main app
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Test"
        }
        
        print("✅ Status bar item created")
        
        // Test NSLog
        NSLog("📊 NSLog test message from minimal app")
        
        // Exit after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("🏁 Test completed, exiting...")
            NSApp.terminate(nil)
        }
    }
}

// Set up the app
NSApp = TestApp.shared
NSApp.setActivationPolicy(.accessory)
NSApp.finishLaunching()
RunLoop.main.run()