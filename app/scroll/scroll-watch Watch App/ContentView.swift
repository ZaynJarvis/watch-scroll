import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var crownValue = 0.0
    @State private var lastCrownValue = 0.0
    @State private var crownAccumulator = 0.0
    @State private var lastSendTime = Date()
    @State private var sendTimer: Timer?
    @State private var isScrolling = false
    @State private var animationTimer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !connectivityManager.isConnected {
                    ConnectionStatusIndicator()
                        .environmentObject(connectivityManager)
                }
                
                Spacer()
                
                // 极简主界面
                Circle()
                    .stroke(lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .foregroundColor(connectivityManager.isConnected ? Color(red: 0.8, green: 0.6, blue: 0.2) : .gray)
                    .opacity(isScrolling && connectivityManager.isConnected ? 0.4 : 1.0)
                    .scaleEffect(isScrolling && connectivityManager.isConnected ? 1.1 : 1.0)
                    .animation(
                        isScrolling ? 
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                            .easeOut(duration: 0.3), 
                        value: isScrolling
                    )
                
                Spacer()
            }
            .focusable()
            .digitalCrownRotation(
                $crownValue,
                from: -1000,
                through: 1000,
                by: 1.0,
                sensitivity: .high,
                isContinuous: true,
                isHapticFeedbackEnabled: false
            )
            .onChange(of: crownValue) { oldValue, newValue in
                handleCrownRotation(newValue)
            }
            .navigationBarHidden(true)
        }
    }
    
    
    private func handleCrownRotation(_ newValue: Double) {
        // Remove guard - always try to send, let WatchConnectivityManager handle the session check
        
        // 启动呼吸动画
        if !isScrolling {
            isScrolling = true
        }
        
        // 重置停止动画的计时器
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            isScrolling = false
        }
        
        // 计算滚动差值
        let delta = newValue - lastCrownValue
        lastCrownValue = newValue
        
        // 累积变化
        crownAccumulator += delta
        
        // Throttle messages - send at most every 100ms for battery optimization
        let now = Date()
        let timeSinceLastSend = now.timeIntervalSince(lastSendTime)
        
        if timeSinceLastSend >= 0.1 { // 100ms = 10 FPS
            sendScrollMessage()
        } else {
            // Schedule delayed send if not already scheduled
            sendTimer?.invalidate()
            sendTimer = Timer.scheduledTimer(withTimeInterval: 0.1 - timeSinceLastSend, repeats: false) { _ in
                sendScrollMessage()
            }
        }
    }
    
    private func sendScrollMessage() {
        guard abs(crownAccumulator) > 0.05 else { return } // Lower threshold for ultra-sensitivity
        
        let scrollPixels = crownAccumulator * 40 // Optimized for trackpad-like feel
        
        // Add subtle haptic feedback when sending scroll commands
        WKInterfaceDevice.current().play(.click)
        
        // 发送滚动命令
        connectivityManager.sendScrollCommand(pixels: scrollPixels)
        
        // 重置累积器和时间
        crownAccumulator = 0
        lastSendTime = Date()
        sendTimer?.invalidate()
        sendTimer = nil
    }
}

struct ConnectionStatusIndicator: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text("未连接")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}
