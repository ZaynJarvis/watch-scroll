# WatchScroller 构建指南

## 开发环境要求

### 系统要求
- **macOS**: 13.0 或更高版本
- **Xcode**: 15.0 或更高版本
- **iOS**: 16.0+ （用于 iPhone 配套应用）
- **watchOS**: 8.0+ （目标设备）

### 开发者账户
- Apple Developer Account（用于设备测试和分发）
- 代码签名证书
- Provisioning Profiles

## 项目结构

```
WatchScroller/
├── macOS-App/                 # macOS 主应用
│   └── WatchScroller.xcodeproj
├── WatchOS-App/               # Apple Watch 应用
│   └── WatchScrollerWatch.xcodeproj
├── Research/                  # 研究文档
├── Documentation/             # 使用文档
└── Assets/                   # 共享资源
```

## 构建步骤

### 1. 准备工作

#### 克隆项目
```bash
git clone https://github.com/yourname/WatchScroller.git
cd WatchScroller
```

#### 配置开发者设置
1. 在 Xcode 中登录你的 Apple Developer Account
2. 配置 Team ID 和 Bundle Identifier
3. 确保有效的 Provisioning Profiles

### 2. 构建 macOS 应用

```bash
# 进入 macOS 项目目录
cd macOS-App

# 在 Xcode 中打开项目
open WatchScroller.xcodeproj
```

#### Xcode 构建配置
1. **Target Settings**
   - Bundle Identifier: `com.yourname.WatchScroller`
   - Deployment Target: macOS 12.0
   - Code Signing: Automatic

2. **Entitlements 配置**
   - `com.apple.security.automation.apple-events`: `true`

3. **Build Settings**
   - Architecture: Universal (Apple Silicon + Intel)
   - Optimization Level: `-O` (Release), `-Onone` (Debug)

#### 构建命令
```bash
# 清理项目
xcodebuild clean -project WatchScroller.xcodeproj -scheme WatchScroller

# Debug 构建
xcodebuild build -project WatchScroller.xcodeproj -scheme WatchScroller -configuration Debug

# Release 构建  
xcodebuild build -project WatchScroller.xcodeproj -scheme WatchScroller -configuration Release

# 创建 Archive
xcodebuild archive -project WatchScroller.xcodeproj -scheme WatchScroller -archivePath WatchScroller.xcarchive
```

### 3. 构建 Apple Watch 应用

```bash
# 进入 watchOS 项目目录
cd ../WatchOS-App

# 在 Xcode 中打开项目
open WatchScrollerWatch.xcodeproj
```

#### Watch 应用配置
1. **Target Settings**
   - Bundle Identifier: `com.yourname.WatchScroller.watchkitapp`
   - Deployment Target: watchOS 8.0
   - WKCompanionAppBundleIdentifier: `com.yourname.WatchScroller`

2. **构建设置**
   - Watch App Only: `true`
   - Supported Interface Orientations: Portrait

#### 构建命令
```bash
# 清理项目
xcodebuild clean -project WatchScrollerWatch.xcodeproj -scheme WatchScrollerWatch

# 构建 Watch 应用
xcodebuild build -project WatchScrollerWatch.xcodeproj -scheme WatchScrollerWatch -configuration Release -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

# 真机构建（需要配对的设备）
xcodebuild build -project WatchScrollerWatch.xcodeproj -scheme WatchScrollerWatch -configuration Release -destination 'platform=watchOS,name=你的Apple Watch名称'
```

### 4. 统一构建脚本

创建 `build.sh` 自动化构建脚本：

```bash
#!/bin/bash

# WatchScroller 统一构建脚本

set -e  # 遇到错误时退出

echo "🚀 开始构建 WatchScroller..."

# 配置变量
MAC_PROJECT="macOS-App/WatchScroller.xcodeproj"
WATCH_PROJECT="WatchOS-App/WatchScrollerWatch.xcodeproj"
SCHEME_MAC="WatchScroller"
SCHEME_WATCH="WatchScrollerWatch"
CONFIGURATION="Release"
BUILD_DIR="build"

# 清理构建目录
echo "🧹 清理构建目录..."
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

# 构建 macOS 应用
echo "🖥️ 构建 macOS 应用..."
xcodebuild clean -project $MAC_PROJECT -scheme $SCHEME_MAC
xcodebuild build -project $MAC_PROJECT -scheme $SCHEME_MAC -configuration $CONFIGURATION -derivedDataPath $BUILD_DIR/mac

# 构建 Watch 应用  
echo "⌚ 构建 Apple Watch 应用..."
xcodebuild clean -project $WATCH_PROJECT -scheme $SCHEME_WATCH
xcodebuild build -project $WATCH_PROJECT -scheme $SCHEME_WATCH -configuration $CONFIGURATION -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -derivedDataPath $BUILD_DIR/watch

echo "✅ 构建完成！"
echo "📦 构建产物位于: $BUILD_DIR"
```

运行构建脚本：
```bash
chmod +x build.sh
./build.sh
```

## 代码签名和分发

### 1. 开发测试

#### macOS 应用测试
```bash
# 在设备上安装和测试
sudo cp -R build/mac/Build/Products/Release/WatchScroller.app /Applications/

# 授予辅助功能权限
# 系统设置 > 隐私与安全性 > 辅助功能 > 添加 WatchScroller
```

#### Watch 应用测试  
```bash
# 通过 Xcode 直接安装到配对的 Apple Watch
# 或使用 iPhone 的 Watch 应用进行管理
```

### 2. 分发准备

#### App Store 分发
1. **创建 Archive**
```bash
xcodebuild archive -project WatchScroller.xcodeproj -scheme WatchScroller -archivePath WatchScroller.xcarchive
```

2. **上传到 App Store Connect**
```bash
xcodebuild -exportArchive -archivePath WatchScroller.xcarchive -exportPath export -exportOptionsPlist ExportOptions.plist
```

#### 企业分发
1. **代码签名**
```bash
codesign --force --deep --sign "Developer ID Application: Your Name" WatchScroller.app
```

2. **公证 (Notarization)**
```bash
# 创建 ZIP 包
ditto -c -k --keepParent WatchScroller.app WatchScroller.zip

# 上传公证
xcrun altool --notarize-app --primary-bundle-id com.yourname.WatchScroller --username "your@email.com" --password "app-specific-password" --file WatchScroller.zip

# 检查公证状态
xcrun altool --notarization-info <RequestUUID> --username "your@email.com" --password "app-specific-password"

# 装订公证票据
xcrun stapler staple WatchScroller.app
```

## 故障排除

### 常见构建问题

#### 1. 代码签名失败
```bash
# 错误: Code signing failed
# 解决: 检查证书和 Provisioning Profile
security find-identity -v -p codesigning
```

#### 2. Watch 应用无法安装
```bash
# 错误: Failed to install watch app
# 解决: 检查 Bundle Identifier 匹配关系
# Mac 应用: com.yourname.WatchScroller
# Watch 应用: com.yourname.WatchScroller.watchkitapp
```

#### 3. 权限相关错误
```bash
# 错误: Accessibility permission required
# 解决: 在 macOS 系统设置中手动授权
```

### 调试技巧

#### 1. 查看详细构建日志
```bash
xcodebuild -verbose build -project WatchScroller.xcodeproj -scheme WatchScroller
```

#### 2. 检查应用签名
```bash
codesign -dv --verbose=4 WatchScroller.app
```

#### 3. 验证 Watch 连接
```bash
# 在 Xcode 中查看 Device and Simulator 窗口
# Window > Devices and Simulators
```

## 持续集成

### GitHub Actions 配置

创建 `.github/workflows/build.yml`:

```yaml
name: Build WatchScroller

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
      
    - name: Build macOS App
      run: |
        cd macOS-App
        xcodebuild clean build -project WatchScroller.xcodeproj -scheme WatchScroller -configuration Release
        
    - name: Build Watch App
      run: |
        cd WatchOS-App  
        xcodebuild clean build -project WatchScrollerWatch.xcodeproj -scheme WatchScrollerWatch -configuration Release -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

## 性能优化

### 构建优化
```bash
# 启用并行构建
xcodebuild -parallelizeTargets build

# 使用派生数据缓存
xcodebuild -derivedDataPath ~/Library/Developer/Xcode/DerivedData build

# 仅构建活跃架构 (Debug)
xcodebuild ONLY_ACTIVE_ARCH=YES build
```

### 代码优化
1. **编译器优化**: Release 模式使用 `-O` 优化级别
2. **死代码消除**: 启用 `DEAD_CODE_STRIPPING = YES`
3. **符号剥离**: Release 版本剥离调试符号

## 版本管理

### 版本号管理
```bash
# 自动递增 build number
agvtool next-version -all

# 设置营销版本
agvtool new-marketing-version 1.0.0
```

### Git 标签
```bash
# 创建版本标签
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

---

现在你可以开始构建和部署 WatchScroller 了！ 🎉