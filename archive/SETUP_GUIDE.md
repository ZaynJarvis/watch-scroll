# WatchScroller 安装配置指南

## 问题解决方案

你的原始应用尝试在 Apple Watch 和 Mac 之间建立直接 TCP 连接，但这在 watchOS 中是不被允许的。我已经重构了架构，现在使用 iPhone 作为桥接应用。

## 新架构

```
Apple Watch (watchOS) 
    ↕ WatchConnectivity Framework
iPhone App (iOS Bridge)
    ↕ TCP Socket (Port 8888)
Mac Application (macOS)
```

## 安装步骤

### 1. 设置 Mac 应用

Mac 应用保持不变，继续监听端口 8888。

```bash
cd macOS-App
open WatchScroller.xcodeproj
# 构建并运行
```

### 2. 创建 iOS 桥接应用

**方式 1: 使用 Xcode 手动创建**

1. 打开 Xcode
2. 创建新的 iOS 项目
3. 项目名称: `WatchScrollerBridge`
4. Bundle ID: `com.yourname.WatchScrollerBridge`
5. 选择 SwiftUI 和 iOS 15+
6. 将以下文件复制到项目中:
   - `iOS-App/WatchScrollerBridge/WatchScrollerBridgeApp.swift`
   - `iOS-App/WatchScrollerBridge/Controllers/WatchConnectivityBridge.swift`
   - `iOS-App/WatchScrollerBridge/Views/ContentView.swift`
   - `iOS-App/WatchScrollerBridge/Info.plist`

**方式 2: 运行设置脚本**

```bash
cd /Users/bytedance/code/void/WatchScroller
./setup-projects.sh
```

### 3. 配置 iOS 桥接应用

在 Xcode 中:

1. **添加框架依赖**:
   - 选择项目 target
   - "Frameworks, Libraries, and Embedded Content"
   - 添加 `WatchConnectivity.framework`

2. **配置权限**:
   - 确保 `Info.plist` 包含网络权限
   - 添加后台模式权限

3. **构建设置**:
   - iOS 15.0+ 部署目标
   - 启用 WatchConnectivity 能力

### 4. 更新 Watch 应用

Watch 应用已经更新为使用 WatchConnectivity。确保:

1. 打开 `WatchOS-App/WatchScrollerWatch.xcodeproj`
2. 验证更新的 `WatchConnectivityManager.swift` 文件
3. 确保添加了 `WatchConnectivity.framework`
4. 构建并安装到 Apple Watch

### 5. 测试连接

**启动顺序:**

1. **启动 Mac 应用**
   ```bash
   cd macOS-App
   # 在 Xcode 中运行或者构建后直接运行
   ```

2. **启动 iPhone 桥接应用**
   - 在真机上运行 iOS 桥接应用
   - 应该看到 "Mac 应用: 已连接" 状态

3. **启动 Apple Watch 应用**
   - 在 Apple Watch 上启动应用
   - 应该看到 "已连接" 状态

## 故障排除

### Mac 连接问题
```bash
# 检查 Mac 应用是否在监听端口 8888
netstat -an | grep 8888
```

### iPhone-Mac 连接问题
- 确保 iPhone 和 Mac 在同一网络
- 检查防火墙设置
- 尝试重启 iOS 桥接应用

### Watch-iPhone 连接问题
- 确保 Apple Watch 已配对
- 检查 WatchConnectivity 权限
- 重启 Apple Watch 应用

### 网络配置

如果 Mac 和 iPhone 不在同一网络，你可能需要:

1. **修改 iOS 桥接应用中的 Mac 地址**:
   ```swift
   // 在 WatchConnectivityBridge.swift 中修改
   private let macHost = "192.168.1.100" // Mac 的实际 IP
   ```

2. **配置端口转发** (如果需要)

## 验证连接

### 在 iPhone 桥接应用中
- 绿色圆点 = 连接成功
- 红色圆点 = 连接失败
- 查看详细错误信息

### 在 Apple Watch 应用中
- "已连接" 状态表示与 iPhone 通信正常
- 可以看到 Mac 的权限和状态信息

### 在 Mac 应用中
- 应该显示网络监听器就绪
- 接收到来自 iPhone 的连接

## 调试日志

各应用都会在控制台输出调试信息:

- **Mac**: `Network listener ready on port 8888`
- **iPhone**: `Connected to Mac app` 和 `WCSession activated successfully`
- **Watch**: `WCSession activated successfully` 和 `Received message from iPhone`

## 性能优化

- iOS 桥接应用设计为低功耗后台运行
- 消息缓存机制防止连接中断时丢失命令
- 自动重连机制处理网络波动

现在你的 Apple Watch 应该可以通过 iPhone 桥接成功控制 Mac 滚动了！