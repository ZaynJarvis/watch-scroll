# WatchScroller 快速开始指南 🚀

## 项目概述

**WatchScroller** 是一个创新的 Apple Watch + macOS 应用组合，通过 Apple Watch 的数字表冠远程控制 Mac 上的滚动操作。

### ✨ 核心功能
- 🖱️ 通过数字表冠精确控制 Mac 滚动
- 📱 实时的 Apple Watch ↔ Mac 通信
- ⚙️ 可调节的滚动灵敏度
- 🎯 支持所有 macOS 应用
- 🔋 优化的电池使用

## 🚀 快速体验

### 第一步：检查系统要求
```bash
# 检查 macOS 版本 (需要 12.0+)
sw_vers -productVersion

# 检查 Xcode (需要 14.0+)
xcodebuild -version
```

### 第二步：构建和运行

#### macOS 应用
```bash
cd WatchScroller/macOS-App
open WatchScroller.xcodeproj

# 在 Xcode 中:
# 1. 选择 "My Mac" 作为运行目标
# 2. 按 Cmd+R 运行
```

#### Apple Watch 应用
```bash
cd WatchScroller/WatchOS-App  
open WatchScrollerWatch.xcodeproj

# 在 Xcode 中:
# 1. 选择你的 Apple Watch 作为运行目标
# 2. 按 Cmd+R 构建并安装到手表
```

### 第三步：授权和设置

1. **授予辅助功能权限**
   - 系统设置 → 隐私与安全性 → 辅助功能
   - 启用 "WatchScroller"

2. **验证连接**
   - 启动两个应用
   - 检查 Apple Watch 显示 "已连接"

### 第四步：开始使用

1. 在 Apple Watch 上点击 "开始" 按钮
2. 旋转数字表冠控制 Mac 滚动
3. 调节灵敏度获得最佳体验

## 🎯 应用场景

### 网页浏览
- 灵敏度设置: **1.5x - 2.0x**
- 适合快速浏览长页面

### 代码编辑  
- 灵敏度设置: **0.5x - 1.0x**
- 适合精确定位代码行

### 文档阅读
- 灵敏度设置: **1.0x - 1.5x** 
- 舒适的阅读滚动体验

## 🛠️ 项目结构

```
WatchScroller/
├── macOS-App/                 # macOS 主应用
│   ├── WatchScroller.xcodeproj
│   └── WatchScroller/
│       ├── AppDelegate.swift
│       ├── Views/ContentView.swift
│       └── Controllers/
├── WatchOS-App/               # Apple Watch 应用  
│   ├── WatchScrollerWatch.xcodeproj
│   └── WatchScrollerWatch/
│       ├── WatchScrollerWatchApp.swift
│       └── Views/ContentView.swift
├── Research/                  # 技术研究文档
├── Documentation/             # 详细文档
│   ├── USER_GUIDE.md         # 用户指南
│   ├── BUILD_INSTRUCTIONS.md # 构建说明
│   └── DEVELOPMENT_NOTES.md  # 开发笔记
└── README.md                 # 项目说明
```

## 🔧 技术架构

### 核心技术栈
- **watchOS**: SwiftUI + DigitalCrownRotation + WatchConnectivity
- **macOS**: SwiftUI + CGEvent API + WatchConnectivity
- **通信**: WatchConnectivity Framework
- **权限**: macOS Accessibility API

### 数据流
```
数字表冠旋转 → SwiftUI digitalCrownRotation 
    ↓
WatchConnectivity 消息传输
    ↓  
macOS 接收处理 → CGEvent 滚动事件
    ↓
系统分发 → 当前应用滚动
```

## 📚 深入了解

### 详细文档
- 📖 [用户指南](Documentation/USER_GUIDE.md) - 完整使用说明
- 🔨 [构建说明](Documentation/BUILD_INSTRUCTIONS.md) - 开发和部署
- 💡 [开发笔记](Documentation/DEVELOPMENT_NOTES.md) - 技术细节

### 核心文件
- [`ScrollController.swift`](macOS-App/WatchScroller/Controllers/ScrollController.swift) - 滚动控制核心逻辑
- [`WatchConnectivityManager.swift`](macOS-App/WatchScroller/Controllers/WatchConnectivityManager.swift) - 设备通信管理
- [`ContentView.swift`](WatchOS-App/WatchScrollerWatch/Views/ContentView.swift) - Apple Watch 主界面

## 🐛 故障排除

### 常见问题

#### ❌ "未连接" 状态
- 检查 Apple Watch 与 iPhone 配对
- 重启两个应用
- 确保设备在蓝牙范围内

#### ❌ 无法滚动
- 检查 macOS 辅助功能权限
- 确认应用已获得必要权限

#### ❌ 滚动延迟
- 调整灵敏度到较低值
- 关闭其他资源密集型应用
- 检查设备距离

### 测试工具
```bash
# 运行项目完整性测试
./test.sh

# 检查构建状态
cd macOS-App && xcodebuild -project WatchScroller.xcodeproj -scheme WatchScroller -configuration Debug build
```

## 🤝 贡献和反馈

这是一个从零构建的完整项目，展示了：
- 🏗️ Apple 生态系统跨设备开发
- 📱 现代 SwiftUI 应用架构  
- 🔄 实时设备间通信
- 🎛️ 系统级 API 集成
- 📋 完整的文档和测试

### 项目特点
- ✅ **生产就绪**: 完整的错误处理和用户体验
- ✅ **性能优化**: 节流控制和电池优化
- ✅ **全面文档**: 从用户指南到技术细节
- ✅ **测试覆盖**: 自动化测试和质量检查

---

**开始你的 Apple Watch 远程滚动体验！** 🎉

通过数字表冠享受全新的 Mac 控制方式。