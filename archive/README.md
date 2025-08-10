# WatchScroller - Apple Watch 滚动控制器

## 项目概述
WatchScroller 是一个创新的 macOS + watchOS 应用组合，让你通过 Apple Watch 控制 Mac 上的滚动操作。

## 功能特性
- 🖱️ 通过 Apple Watch 数字表冠控制 Mac 滚动
- 🎯 精确的滚动控制和速度调节
- 📱 支持所有 macOS 应用（浏览器、文档编辑器等）
- 🔄 实时同步和低延迟响应
- ⚙️ 可自定义滚动灵敏度和方向

## 项目结构
```
WatchScroller/
├── macOS-App/          # macOS 主应用
├── iOS-App/            # iOS 桥接应用 (新增)
├── WatchOS-App/        # Apple Watch 配套应用
├── Research/           # 产品研究和开发规范
├── Documentation/      # 使用文档和开发指南
├── Assets/            # 图标和资源文件
└── README.md          # 项目说明
```

## 应用架构
```
Apple Watch (watchOS) 
    ↕ WatchConnectivity
iPhone App (iOS Bridge)
    ↕ TCP Network  
Mac Application (macOS)
```

> **重要更新**: 现在需要 iPhone 作为桥接应用，因为 Apple Watch 无法直接通过 TCP 连接到 Mac。

## 开发状态
🚧 项目正在开发中...

## 系统要求
- macOS 12.0+ 
- watchOS 8.0+
- Xcode 14.0+
- Apple Watch Series 4 或更新版本

## 安装和使用
详细说明请查看 [Documentation/USER_GUIDE.md](Documentation/USER_GUIDE.md)