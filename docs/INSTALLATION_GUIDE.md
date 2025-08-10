# 📱 WatchScroller Installation Guide

## 🎯 **Easy Installation Method (Recommended)**

### **Method 1: Direct Installation via Xcode**

1. **Connect your iPhone and Apple Watch to your Mac**
   ```bash
   # Make sure both devices are connected and trusted
   ```

2. **Open the project in Xcode**
   ```bash
   open scroll.xcodeproj
   ```

3. **Configure signing (one-time setup):**
   - Select `scroll` project in the navigator
   - Go to **Signing & Capabilities** tab
   - For **scroll** target: Select your **Team** (Apple ID)
   - For **scroll-watch Watch App** target: Select your **Team** (Apple ID)
   - Xcode will automatically handle provisioning profiles

4. **Build and install to iPhone:**
   - Select **scroll** scheme at the top
   - Choose your **iPhone** as the destination
   - Click **Run** (▶️) or press **Cmd+R**
   - iPhone app will install and launch

5. **Install Watch app:**
   - Select **scroll-watch Watch App** scheme
   - Choose your **Apple Watch** as the destination  
   - Click **Run** (▶️) or press **Cmd+R**
   - Watch app will install

### **Method 2: Archive and Distribute**

1. **Create Archive:**
   ```bash
   # In Terminal, from the scroll project directory:
   ./build_for_device.sh
   ```

2. **Install via Finder:**
   - Connect iPhone to Mac
   - Open Finder, select your iPhone
   - Drag the generated `.ipa` file to your iPhone
   - Watch app installs automatically

---

## 🔧 **Build Configuration**

Your app is now configured with:

### **✅ App Icons:**
- 📱 **iPhone**: All required sizes (20pt-1024pt)
- ⌚ **Watch**: All required sizes (24mm-1024pt)  
- 🎨 **Icon**: Custom circular design with gradient

### **✅ Features:**
- 📡 **Real-time scrolling**: Watch crown → Mac browser
- ⚡ **Optimized performance**: Throttled messages (50ms/30ms)
- 🔄 **Slower scroll steps**: More precise control  
- 📳 **Haptic feedback**: Crown rotation + scroll commands
- 🌐 **Python server**: Direct Mac scrolling via PyAutoGUI

---

## 🚀 **Usage After Installation**

### **1. Start Python Server:**
```bash
cd /Users/bytedance/code/void/WatchScroller/python-server
./run_server.sh
```

### **2. Launch iPhone App:**
- Open **WatchScroller** on iPhone
- App will show connection status
- Counter shows scroll commands received

### **3. Launch Watch App:**  
- Open **WatchScroller** on Watch
- Tap **测试连接** to test connectivity
- Rotate **Digital Crown** to scroll Mac browser

---

## 🎯 **Expected Result:**

```
Watch Crown Rotation → iPhone Bridge → Python Server → Mac Browser Scrolling
     (with haptics)      (throttled)     (slower steps)    (real-time)
```

---

## 🔍 **Troubleshooting:**

### **Code Signing Issues:**
- Make sure you have an Apple ID signed into Xcode
- Go to **Xcode > Preferences > Accounts** to add your Apple ID
- Free Apple IDs work for personal device installation

### **Device Not Recognized:**
- Trust the computer on iPhone/Watch
- Make sure devices are unlocked during installation

### **Watch App Not Installing:**
- Install iPhone app first
- Watch app installs automatically as a companion
- Check Apple Watch app on iPhone for manual installation

---

## 📦 **Build Artifacts:**

After running `./build_for_device.sh`, you'll find:
- `build/WatchScroller.xcarchive` - Archive file
- `build/WatchScroller.ipa` - Installable app package
- App icons in both iOS and watchOS formats

---

## 🎉 **You're Ready!**

Your WatchScroller app with custom icon is ready for installation! 

The app provides seamless Watch-to-Mac browser scrolling with optimized performance and haptic feedback. 🚀