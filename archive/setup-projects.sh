#!/bin/bash

echo "🔧 Setting up WatchScroller projects..."

# Create iOS project
echo "📱 Setting up iOS Bridge project..."
cd iOS-App
mkdir -p WatchScrollerBridge.xcodeproj

# Create basic project structure
mkdir -p WatchScrollerBridge/Controllers
mkdir -p WatchScrollerBridge/Views
mkdir -p WatchScrollerBridge/Assets.xcassets/AppIcon.appiconset

# Create Contents.json for assets
cat > WatchScrollerBridge/Assets.xcassets/Contents.json << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > WatchScrollerBridge/Assets.xcassets/AppIcon.appiconset/Contents.json << 'EOF'
{
  "images" : [
    {
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ iOS Bridge project structure created"

cd ..

echo "🎯 Next steps:"
echo "1. Open WatchOS-App/WatchScrollerWatch.xcodeproj in Xcode"
echo "2. Create a new iOS project in iOS-App/ with the existing files"
echo "3. Make sure to add WatchConnectivity framework to both projects"
echo "4. Build and run all three apps (Mac, iOS Bridge, Watch)"
echo "5. The connection should now work through the iPhone bridge"

echo ""
echo "📝 Architecture:"
echo "   Apple Watch ↔ (WatchConnectivity) ↔ iPhone Bridge ↔ (TCP) ↔ Mac App"
echo ""
echo "🔧 If you need help creating the Xcode projects, run:"
echo "   open WatchOS-App/WatchScrollerWatch.xcodeproj"
echo "   # Then manually create iOS project using existing iOS-App files"