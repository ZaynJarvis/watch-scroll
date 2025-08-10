#!/bin/bash

echo "🚀 WatchScroller - Running All Apps"
echo "====================================="
echo ""

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 - SUCCESS"
    else
        echo "❌ $1 - FAILED"
        exit 1
    fi
}

echo "📋 Build Status Check:"
echo "---------------------"

# Build Mac App
echo "🖥️  Building Mac App..."
cd macOS-App
xcodebuild -project WatchScroller.xcodeproj -scheme WatchScroller -configuration Debug build > /dev/null 2>&1
check_status "Mac App Build"

# Build Watch App
echo "⌚ Building Watch App..."
cd ../WatchOS-App
xcodebuild -project WatchScrollerWatch.xcodeproj -scheme WatchScrollerWatch -configuration Debug -sdk watchsimulator build > /dev/null 2>&1
check_status "Watch App Build"

# Build iOS Bridge App
echo "📱 Building iOS Bridge App..."
cd ../iOS-App
xcodebuild -project WatchScrollerBridge.xcodeproj -scheme WatchScrollerBridge -configuration Debug -sdk iphonesimulator build > /dev/null 2>&1
check_status "iOS Bridge App Build"

cd ..

echo ""
echo "🎉 All Apps Built Successfully!"
echo ""
echo "📖 How to Run:"
echo "=============="
echo ""
echo "1️⃣  START MAC APP:"
echo "   cd macOS-App"
echo "   open WatchScroller.xcodeproj"
echo "   # Run in Xcode or build and run the .app"
echo ""
echo "2️⃣  START iOS BRIDGE APP:"
echo "   cd iOS-App" 
echo "   open WatchScrollerBridge.xcodeproj"
echo "   # IMPORTANT: Run on REAL iPhone device (not simulator)"
echo "   # WatchConnectivity requires real hardware"
echo ""
echo "3️⃣  START WATCH APP:"
echo "   cd WatchOS-App"
echo "   open WatchScrollerWatch.xcodeproj" 
echo "   # Run on real Apple Watch or Watch Simulator"
echo ""
echo "📡 Connection Flow:"
echo "=================="
echo "Apple Watch 🔄 iPhone Bridge 🔄 Mac App"
echo ""
echo "🔍 Status Indicators:"
echo "• Mac App: Should show 'Network listener ready on port 8888'"
echo "• iPhone App: Shows connection status with green/red dots"
echo "• Watch App: Shows '已连接' when connected to iPhone"
echo ""
echo "🐛 Troubleshooting:"
echo "• Watch ↔ iPhone: Ensure devices are paired and WatchConnectivity is working"
echo "• iPhone ↔ Mac: Ensure both on same WiFi network and Mac app is running"
echo "• Use real devices (not simulators) for WatchConnectivity"
echo ""
echo "🎮 Usage:"
echo "Once all apps show connected status, use the Digital Crown on your"
echo "Apple Watch to control scrolling on your Mac!"