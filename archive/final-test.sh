#!/bin/bash

echo "🎯 Final Connection Test"
echo "======================="
echo ""

echo "📋 Step 1: Build all apps"
echo "------------------------"

# Build Mac App
echo "🖥️  Building Mac app..."
cd macOS-App
xcodebuild -project WatchScroller.xcodeproj -scheme WatchScroller -configuration Debug build > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Mac app built successfully"
else 
    echo "❌ Mac app build failed"
    exit 1
fi

# Build iPhone App
echo "📱 Building iPhone app..."
cd ../iOS-App
xcodebuild -project WatchScrollerBridge.xcodeproj -scheme WatchScrollerBridge -configuration Debug -sdk iphonesimulator build > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ iPhone app built successfully"
else
    echo "❌ iPhone app build failed"  
    exit 1
fi

# Build Watch App
echo "⌚ Building Watch app..."
cd ../WatchOS-App
xcodebuild -project WatchScrollerWatch.xcodeproj -scheme WatchScrollerWatch -configuration Debug -sdk watchsimulator build > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Watch app built successfully"
else
    echo "❌ Watch app build failed"
    exit 1
fi

cd ..

echo ""
echo "📋 Step 2: Check network status"
echo "------------------------------"
./diagnose-network.sh

echo ""
echo "🎉 READY TO TEST!"
echo "================"
echo ""
echo "Next steps:"
echo "1. 🖥️  Start Mac app (it should show network listener ready)"
echo "2. 📱 Run iPhone bridge app on real device"  
echo "3. ⌚ Run Watch app on paired Apple Watch"
echo "4. 🎮 Test scrolling with Digital Crown"
echo ""
echo "Expected results:"
echo "• Mac app: Shows 'Network listener ready on port XXXX'"
echo "• iPhone app: Shows green connection status for both Watch and Mac"
echo "• Watch app: Shows '已连接' status"
echo ""
echo "Use iPhone app's 'IP设置' button to configure Mac's IP: $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"