#!/bin/bash

echo "🔧 Creating Unified iOS + Watch App"
echo "=================================="

# Navigate to project directory
cd /Users/bytedance/code/void/WatchScroller

# Create the unified project directory structure
mkdir -p UnifiedApp/WatchScrollerUnified
mkdir -p UnifiedApp/WatchScrollerUnified/iOS
mkdir -p UnifiedApp/WatchScrollerUnified/WatchExtension
mkdir -p UnifiedApp/WatchScrollerUnified/Shared

echo "✅ Created project structure"

# Copy iPhone bridge code to iOS target
cp -r iOS-App/WatchScrollerBridge/Controllers UnifiedApp/WatchScrollerUnified/iOS/
cp -r iOS-App/WatchScrollerBridge/Views UnifiedApp/WatchScrollerUnified/iOS/
cp iOS-App/WatchScrollerBridge/WatchScrollerBridgeApp.swift UnifiedApp/WatchScrollerUnified/iOS/WatchScrollerApp.swift

# Copy Watch code to Watch extension
cp -r WatchOS-App/WatchScrollerWatch/Controllers UnifiedApp/WatchScrollerUnified/WatchExtension/
cp -r WatchOS-App/WatchScrollerWatch/Views UnifiedApp/WatchScrollerUnified/WatchExtension/
cp WatchOS-App/WatchScrollerWatch/WatchScrollerWatchApp.swift UnifiedApp/WatchScrollerUnified/WatchExtension/

echo "✅ Copied source files"

# Create shared Info.plist files
cat > UnifiedApp/WatchScrollerUnified/iOS/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>WatchScroller</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
</dict>
</plist>
EOF

cat > UnifiedApp/WatchScrollerUnified/WatchExtension/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>WatchScroller</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>WKAppBundleIdentifier</key>
            <string>com.watchscroller.unified.watchkitapp</string>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.watchkit</string>
    </dict>
    <key>WKWatchOnly</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ Created Info.plist files"
echo ""
echo "🎯 Next Steps:"
echo "1. Open Xcode"
echo "2. Create New Project → iOS → App"
echo "3. Add Watch target"
echo "4. Copy the files from UnifiedApp/WatchScrollerUnified/"
echo "5. Configure bundle IDs correctly"

echo ""
echo "📁 Files ready at: UnifiedApp/WatchScrollerUnified/"