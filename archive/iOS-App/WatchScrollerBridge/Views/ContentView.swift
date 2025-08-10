import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bridge: WatchConnectivityBridge
    @State private var showingIPInput = false
    @State private var inputIP = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                Text("WatchScroller Bridge")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("连接 Apple Watch 和 Mac 应用的桥梁")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Scroll Indicator
                VStack {
                    Text("Watch Scroll Test")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(bridge.scrollCount)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(bridge.scrollCount > 0 ? .green : .gray)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(15)
                    
                    Text("Scroll messages received")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(15)
                .padding(.horizontal)
                
                // Connection Status
                VStack(spacing: 15) {
                    ConnectionStatusRow(
                        title: "Apple Watch",
                        isConnected: bridge.isWatchConnected,
                        icon: "applewatch"
                    )
                    
                    VStack(alignment: .leading, spacing: 5) {
                        ConnectionStatusRow(
                            title: "Mac 应用",
                            isConnected: bridge.isMacConnected,
                            icon: "desktopcomputer"
                        )
                        
                        Text("连接地址: \(bridge.macHostAddress):8888")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Error message
                if let error = bridge.connectionError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Connection buttons
                HStack(spacing: 15) {
                    Button("重新连接") {
                        bridge.reconnectToMac()
                    }
                    .padding()
                    .background(bridge.isMacConnected ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(bridge.isMacConnected)
                    
                    Button("设置IP") {
                        inputIP = bridge.macHostAddress
                        showingIPInput = true
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("使用说明：")
                        .font(.headline)
                    
                    Text("1. 确保 Mac 应用正在运行")
                    Text("2. 确保 Apple Watch 已配对并连接")
                    Text("3. 保持此应用在后台运行")
                    Text("4. 现在可以通过 Apple Watch 控制 Mac 滚动")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .alert("设置Mac IP地址", isPresented: $showingIPInput) {
                TextField("输入Mac的IP地址", text: $inputIP)
                    .keyboardType(.decimalPad)
                
                Button("连接") {
                    bridge.setMacIPAddress(inputIP)
                }
                .disabled(inputIP.isEmpty)
                
                Button("取消", role: .cancel) {}
            } message: {
                Text("请输入Mac的IP地址（例如: 192.168.1.72）\n\n在Mac上运行以下命令查看IP:\nifconfig | grep 'inet ' | grep -v 127.0.0.1")
            }
        }
    }
}

struct ConnectionStatusRow: View {
    let title: String
    let isConnected: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isConnected ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                
                Text(isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(isConnected ? .green : .red)
            }
            
            Spacer()
            
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityBridge.shared)
}