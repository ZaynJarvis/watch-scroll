# 🔧 Unified iOS + Watch App Setup

## The Problem
You're right! We have separate iPhone and Watch apps, but they need to be **one unified app** with a Watch extension for proper pairing.

## Quick Solution

### 1. Create New Unified Project in Xcode

1. **Open Xcode**
2. **File → New → Project**
3. **iOS → App** 
4. **Project Name**: `WatchScrollerUnified`
5. **Bundle ID**: `com.watchscroller.unified`
6. **Check "Use SwiftUI"**
7. **Save in**: `/Users/bytedance/code/void/WatchScroller/`

### 2. Add Watch App Target

1. **Select project in navigator**
2. **Click "+" at bottom of targets**
3. **watchOS → Watch App** 
4. **Name**: `WatchScrollerWatch`
5. **Bundle ID**: `com.watchscroller.unified.watchkitapp`
6. **Click "Finish"**

### 3. Copy Our Code

**iPhone Target:**
```bash
# Copy iPhone bridge code to main iOS target
cp iOS-App/WatchScrollerBridge/Controllers/WatchConnectivityBridge.swift WatchScrollerUnified/
cp iOS-App/WatchScrollerBridge/Views/ContentView.swift WatchScrollerUnified/
```

**Watch Target:**
```bash  
# Copy Watch code to Watch target
cp WatchOS-App/WatchScrollerWatch/Controllers/WatchConnectivityManager.swift WatchScrollerWatch\ Watch\ App/
cp WatchOS-App/WatchScrollerWatch/Views/ContentView.swift WatchScrollerWatch\ Watch\ App/
```

### 4. Important: Bundle ID Configuration

**Make sure Bundle IDs follow this pattern:**
- **iPhone app**: `com.watchscroller.unified`
- **Watch app**: `com.watchscroller.unified.watchkitapp`

The Watch app MUST be a **child** of the iPhone app's bundle ID!

### 5. Test the Unified App

1. **Run iPhone target** first
2. **Run Watch target** - should auto-pair
3. **Test "测试" button** - iPhone counter should increment
4. **Rotate Digital Crown** - iPhone counter should increment

## Why This Works

- ✅ **Single Xcode project** with iPhone + Watch targets
- ✅ **Proper bundle ID hierarchy** allows auto-pairing  
- ✅ **WatchConnectivity works** between paired apps
- ✅ **No manual pairing required** in Watch app

Once you create this unified project structure, the "Companion app is not installed" error will disappear! 🎯