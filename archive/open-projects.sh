#!/bin/bash

echo "🚀 Opening WatchScroller Projects in Xcode..."

# Open all three projects
echo "📱 Opening iOS Bridge Project..."
open iOS-App/WatchScrollerBridge.xcodeproj

echo "⌚ Opening Watch Project..."
open WatchOS-App/WatchScrollerWatch.xcodeproj

echo "🖥️  Opening Mac Project..."
open macOS-App/WatchScroller.xcodeproj

echo ""
echo "✅ All projects opened in Xcode!"
echo ""
echo "🎯 Next Steps:"
echo "1. Build and run Mac app first"
echo "2. Build and run iOS Bridge app on real iPhone"  
echo "3. Build and run Watch app on real Apple Watch"
echo ""
echo "📊 Monitor connection status in each app's UI"