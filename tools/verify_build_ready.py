#!/usr/bin/env python3
import os
import json

def verify_build_ready():
    """Verify the project is ready for production build"""
    print("🔍 Verifying WatchScroller Build Readiness")
    print("==========================================")
    
    checks_passed = 0
    total_checks = 0
    
    # Check 1: iOS App Icons
    total_checks += 1
    ios_icon_dir = "scroll/Assets.xcassets/AppIcon.appiconset"
    ios_required_icons = [
        "icon_40x40.png", "icon_60x60.png", "icon_29x29.png", "icon_58x58.png",
        "icon_87x87.png", "icon_80x80.png", "icon_120x120.png", "icon_180x180.png",
        "icon_1024x1024.png"
    ]
    
    missing_ios = []
    for icon in ios_required_icons:
        if not os.path.exists(os.path.join(ios_icon_dir, icon)):
            missing_ios.append(icon)
    
    if not missing_ios:
        print("✅ iOS App Icons: All required icons present")
        checks_passed += 1
    else:
        print(f"❌ iOS App Icons: Missing {missing_ios}")
    
    # Check 2: Watch App Icons
    total_checks += 1
    watch_icon_dir = "scroll-watch Watch App/Assets.xcassets/AppIcon.appiconset"
    watch_required_icons = [
        "icon_48x48.png", "icon_55x55.png", "icon_58x58.png", "icon_88x88.png",
        "icon_100x100.png", "icon_172x172.png", "icon_196x196.png", "icon_216x216.png",
        "icon_1024x1024.png"
    ]
    
    missing_watch = []
    for icon in watch_required_icons:
        if not os.path.exists(os.path.join(watch_icon_dir, icon)):
            missing_watch.append(icon)
    
    if not missing_watch:
        print("✅ Watch App Icons: All required icons present")  
        checks_passed += 1
    else:
        print(f"❌ Watch App Icons: Missing {missing_watch}")
    
    # Check 3: Contents.json files
    total_checks += 1
    ios_contents = os.path.join(ios_icon_dir, "Contents.json")
    watch_contents = os.path.join(watch_icon_dir, "Contents.json")
    
    if os.path.exists(ios_contents) and os.path.exists(watch_contents):
        print("✅ Contents.json: Both iOS and Watch configurations present")
        checks_passed += 1
    else:
        print("❌ Contents.json: Missing configuration files")
    
    # Check 4: Source code files
    total_checks += 1
    key_files = [
        "scroll/ContentView.swift",
        "scroll/WatchConnectivityBridge.swift", 
        "scroll-watch Watch App/ContentView.swift",
        "scroll-watch Watch App/WatchConnectivityManager.swift"
    ]
    
    missing_files = []
    for file in key_files:
        if not os.path.exists(file):
            missing_files.append(file)
    
    if not missing_files:
        print("✅ Source Code: All key source files present")
        checks_passed += 1
    else:
        print(f"❌ Source Code: Missing {missing_files}")
    
    # Check 5: Build scripts
    total_checks += 1
    build_script = "build_for_device.sh"
    if os.path.exists(build_script) and os.access(build_script, os.X_OK):
        print("✅ Build Script: Ready for execution")
        checks_passed += 1
    else:
        print("❌ Build Script: Missing or not executable")
    
    # Check 6: Python Server
    total_checks += 1
    server_files = [
        "../python-server/tcp_server.py",
        "../python-server/run_server.sh",
        "../python-server/venv"
    ]
    
    missing_server = []
    for file in server_files:
        if not os.path.exists(file):
            missing_server.append(file)
    
    if not missing_server:
        print("✅ Python Server: All components ready")
        checks_passed += 1  
    else:
        print(f"❌ Python Server: Missing {missing_server}")
    
    print("\n" + "="*50)
    print(f"📊 Build Readiness: {checks_passed}/{total_checks} checks passed")
    
    if checks_passed == total_checks:
        print("🎉 BUILD READY! You can now:")
        print("   1. Open scroll.xcodeproj in Xcode")
        print("   2. Configure signing (select your team)")
        print("   3. Build and run on your devices")
        print("   4. Or run ./build_for_device.sh for IPA")
        return True
    else:
        print("⚠️  Some components need attention before building")
        return False

if __name__ == "__main__":
    os.chdir("/Users/bytedance/code/void/WatchScroller/scroll")
    verify_build_ready()