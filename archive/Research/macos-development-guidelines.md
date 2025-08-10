# macOS 应用开发规范和指南

## 系统级滚动控制 API

### 1. CGEvent 滚动 API (推荐)

#### 基本实现
```swift
import ApplicationServices

class ScrollController {
    static let shared = ScrollController()
    
    func scrollVertical(pixels: Int32) {
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: pixels,
            wheel2: 0,
            wheel3: 0
        )
        scrollEvent?.post(tap: .cghidEventTap)
    }
    
    func scrollHorizontal(pixels: Int32) {
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: pixels,
            wheel3: 0
        )
        scrollEvent?.post(tap: .cghidEventTap)
    }
}
```

#### 滚动单位选择
```swift
// .pixel - 像素单位 (推荐，精确控制)
// .line - 行单位 (适用于文本滚动)
enum CGScrollEventUnit : UInt32 {
    case pixel = 0
    case line = 1
}
```

### 2. 辅助功能权限管理

#### 权限检查
```swift
import ApplicationServices

extension ScrollController {
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return accessibilityEnabled
    }
    
    func requestAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "请在系统设置 > 隐私与安全性 > 辅助功能中启用此应用"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后设置")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
```

#### 开发期间权限处理 (2025年最佳实践)
```swift
#if DEBUG
extension ScrollController {
    func setupDevelopmentPermissions() {
        // 开发环境下自动检查并提示权限
        DispatchQueue.global(qos: .background).async {
            if !self.checkAccessibilityPermission() {
                DispatchQueue.main.async {
                    self.requestAccessibilityPermission()
                }
            }
        }
    }
}
#endif
```

### 3. 应用架构设计

#### App Delegate 设置
```swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var scrollController = ScrollController.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBarItem()
        setupWatchConnectivity()
        
        #if DEBUG
        scrollController.setupDevelopmentPermissions()
        #endif
    }
    
    func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "scroll", accessibilityDescription: "WatchScroller")
            button.action = #selector(togglePopover)
        }
    }
    
    @objc func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                showPopover()
            }
        }
    }
    
    func showPopover() {
        if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

#### 主视图控制器
```swift
import Cocoa
import SwiftUI

struct ContentView: View {
    @StateObject private var watchManager = WatchConnectivityManager()
    @State private var scrollSensitivity: Double = 1.0
    @State private var isConnected = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "applewatch")
                Text(isConnected ? "Apple Watch 已连接" : "Apple Watch 未连接")
                    .foregroundColor(isConnected ? .green : .red)
            }
            
            VStack(alignment: .leading) {
                Text("滚动灵敏度: \(scrollSensitivity, specifier: "%.1f")")
                Slider(value: $scrollSensitivity, in: 0.1...5.0)
            }
            
            HStack {
                Button("测试向上滚动") {
                    ScrollController.shared.scrollVertical(pixels: Int32(20 * scrollSensitivity))
                }
                Button("测试向下滚动") {
                    ScrollController.shared.scrollVertical(pixels: Int32(-20 * scrollSensitivity))
                }
            }
        }
        .padding()
        .frame(width: 280, height: 180)
        .onReceive(watchManager.$isConnected) { connected in
            isConnected = connected
        }
    }
}
```

### 4. WatchConnectivity 集成

#### Watch 连接管理器
```swift
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isConnected = false
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated && session.isPaired && session.isWatchAppInstalled)
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let scrollValue = message["scrollValue"] as? Double else { return }
        
        DispatchQueue.main.async {
            let pixels = Int32(scrollValue * UserDefaults.standard.double(forKey: "scrollSensitivity"))
            ScrollController.shared.scrollVertical(pixels: pixels)
        }
    }
}
```

### 5. 安全和权限最佳实践

#### 代码签名要求
```xml
<!-- Entitlements.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

#### Info.plist 配置
```xml
<key>NSAppleEventsUsageDescription</key>
<string>WatchScroller 需要控制其他应用的滚动操作</string>
<key>LSUIElement</key>
<true/>
<key>LSMinimumSystemVersion</key>
<string>12.0</string>
```

### 6. 部署和分发

#### App Store 外分发 (推荐)
- 使用 Developer ID 证书签名
- 通过公证 (Notarization) 流程
- 提供清晰的权限说明

#### 安装后首次运行流程
1. 检查辅助功能权限
2. 引导用户开启权限
3. 验证 Apple Watch 连接
4. 显示使用说明

### 7. 性能优化

#### 滚动事件节流
```swift
class ThrottledScrollController {
    private let queue = DispatchQueue(label: "scroll.throttle", qos: .userInteractive)
    private var lastScrollTime: CFAbsoluteTime = 0
    private let minimumInterval: CFAbsoluteTime = 0.016 // ~60fps
    
    func throttledScroll(pixels: Int32) {
        queue.async {
            let now = CFAbsoluteTimeGetCurrent()
            if now - self.lastScrollTime >= self.minimumInterval {
                self.lastScrollTime = now
                
                DispatchQueue.main.async {
                    ScrollController.shared.scrollVertical(pixels: pixels)
                }
            }
        }
    }
}
```

这些指南为我们的 WatchScroller 项目提供了完整的 macOS 端技术实现基础。