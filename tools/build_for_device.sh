#!/bin/bash

echo "🏗️  Building WatchScroller for Device Installation"
echo "================================================="

# Set build configuration
PROJECT_NAME="scroll"
SCHEME_NAME="scroll"
BUILD_CONFIG="Release"
ARCHIVE_PATH="./build/WatchScroller.xcarchive"
IPA_PATH="./build/WatchScroller.ipa"

# Create build directory
mkdir -p build

echo "📱 Step 1: Clean previous builds"
xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME"

echo "📱 Step 2: Building for device (Archive)"
xcodebuild archive \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "$BUILD_CONFIG" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

if [ $? -eq 0 ]; then
    echo "✅ Archive created successfully!"
    
    echo "📱 Step 3: Exporting IPA for Ad Hoc Distribution"
    
    # Create export options plist
    cat > build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string></string>
</dict>
</plist>
EOF

    # Export IPA
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "./build" \
        -exportOptionsPlist "./build/ExportOptions.plist"

    if [ $? -eq 0 ]; then
        echo "✅ IPA exported successfully!"
        echo "📦 Build artifacts:"
        ls -la build/
        echo ""
        echo "🎉 Installation Instructions:"
        echo "1. Connect your iPhone to your Mac"
        echo "2. Open Finder, select your iPhone"
        echo "3. Drag the .ipa file to your iPhone in Finder"
        echo "4. Or use: Applications > Apple Configurator 2 to install"
        echo ""
        echo "⌚ Watch App will install automatically when iPhone app is installed"
    else
        echo "❌ Failed to export IPA"
    fi
else
    echo "❌ Archive failed!"
    echo ""
    echo "📝 Common fixes:"
    echo "1. Make sure you have a valid Apple Developer account"
    echo "2. Configure signing in Xcode project settings"
    echo "3. Select your development team"
fi