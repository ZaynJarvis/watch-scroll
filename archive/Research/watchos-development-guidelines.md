# watchOS 开发规范和指南

## 数字表冠 API 开发指南 (2025)

### 核心 API 组件

#### 1. WKCrownSequencer (watchOS 3+)
```swift
// 报告数字表冠状态（如旋转速度）
let crownSequencer = WKCrownSequencer()
crownSequencer.delegate = self
crownSequencer.focus()
```

#### 2. SwiftUI 数字表冠集成
```swift
@State private var crownValue = 0.0

var body: some View {
    VStack {
        Text("Scroll Value: \(crownValue)")
        ScrollView {
            // 内容
        }
        .digitalCrownRotation($crownValue)
    }
}
```

### 设计原则 (watchOS 10+)

#### 1. Crown-First 设计哲学
- **主导航**: 数字表冠是 watchOS 10+ 的主要导航方式
- **精确输入**: 不遮挡屏幕的精确输入设备
- **备用触控**: 始终提供触控替代方案确保可访问性

#### 2. 垂直分页设计
```swift
TabView(selection: $selectedTab) {
    ForEach(tabs, id: \.self) { tab in
        TabContentView(tab: tab)
    }
}
.tabViewStyle(.verticalPage)
.digitalCrownRotation($selectedTab)
```

#### 3. 智能堆栈 (Smart Stack) 集成
- 通过数字表冠启动和导航
- 智能排序的小组件堆栈
- 一眼可见的内容展示

### 导航架构推荐

#### 1. NavigationSplitView
```swift
NavigationSplitView {
    // 侧边栏内容
    SidebarView()
} detail: {
    // 详细内容
    DetailView()
}
```

#### 2. NavigationStack
```swift
NavigationStack {
    ContentView()
        .navigationDestination(for: String.self) { value in
            DetailView(content: value)
        }
}
```

#### 3. TabView + 数字表冠
```swift
TabView {
    ForEach(items, id: \.self) { item in
        ItemView(item: item)
    }
}
.digitalCrownRotation($selectedIndex)
```

### 用户体验原则

#### 1. 一眼可见 (Glanceable)
- 专注于当前时刻相关的信息片段
- 快速获取关键信息
- 避免复杂的深层导航

#### 2. 响应式设计
```swift
@State private var scrollOffset = 0.0

ScrollView {
    LazyVStack {
        // 内容
    }
}
.digitalCrownRotation(
    $scrollOffset,
    from: 0,
    through: maxScrollValue,
    by: 1.0,
    sensitivity: .high
)
```

#### 3. 动画和过渡
```swift
struct AnimatedCrownView: View {
    @State private var crownValue = 0.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .scaleEffect(1 + crownValue * 0.1)
            .animation(.easeInOut, value: crownValue)
            .digitalCrownRotation($crownValue)
    }
}
```

### 技术实现要点

#### 1. 数字表冠敏感度设置
```swift
.digitalCrownRotation(
    $value,
    from: minValue,
    through: maxValue,
    by: stepSize,
    sensitivity: .high, // .low, .medium, .high
    isContinuous: true
)
```

#### 2. 多设备通信 (WatchConnectivity)
```swift
import WatchConnectivity

class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func sendScrollData(_ data: [String: Any]) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(data, replyHandler: nil)
        }
    }
}
```

### 最佳实践

#### 1. 性能优化
- 使用 `lazy` 视图减少内存占用
- 实现增量更新避免过度渲染
- 合理使用动画减少电池消耗

#### 2. 用户反馈
- 提供触觉反馈确认操作
- 使用进度指示器显示状态
- 实现错误恢复机制

#### 3. 可访问性
- 支持 VoiceOver 导航
- 提供备用触控操作
- 考虑不同用户的操作习惯

### 项目应用建议

对于我们的 WatchScroller 项目：

1. **使用 SwiftUI + digitalCrownRotation** 实现核心滚动控制
2. **WatchConnectivity** 实现与 Mac 的实时通信
3. **Crown-First 设计** 确保用户体验符合 watchOS 标准
4. **提供触控备选** 确保完整的可访问性支持