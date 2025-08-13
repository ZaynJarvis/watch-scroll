import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bridge: WatchConnectivityBridgeV2
    @StateObject private var debugLog = DebugLogManager.shared
    @State private var showingIPInput = false
    @State private var inputIP = ""
    @State private var showDebugLogs = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                Text("WatchScroller")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("连接 Apple Watch 和 Mac 应用的桥梁")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Connection Status
                VStack(spacing: 20) {
                    ConnectionStatusRow(
                        title: "Apple Watch",
                        isConnected: bridge.isWatchConnected,
                        icon: "applewatch"
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ConnectionStatusRow(
                            title: "Mac 应用",
                            isConnected: bridge.isMacConnected,
                            icon: "desktopcomputer"
                        )
                        
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .font(.title2)
                                .foregroundColor(.clear) // Invisible but maintains alignment
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("连接地址: \(bridge.macHostAddress):8888")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Text("模式: \(bridge.currentIPSource)")
                                        .font(.caption2)
                                        .foregroundColor(getSourceColor(bridge.currentIPSource))
                                    
                                    if bridge.currentIPSource.contains("重连中") {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
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
                HStack(spacing: 10) {
                    Button(bridge.isUsingManualIP ? "重新连接" : "重新搜索") {
                        bridge.reconnectToMac()
                    }
                    .padding()
                    .background(bridge.isMacConnected ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(bridge.isMacConnected)
                    
                    Button("设置IP") {
                        inputIP = bridge.savedIPAddress.isEmpty ? bridge.macHostAddress == "等待自动发现..." ? "" : bridge.macHostAddress : bridge.savedIPAddress
                        showingIPInput = true
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    if bridge.isUsingManualIP {
                        Button("自动发现") {
                            bridge.clearManualIPAndUseBonjour()
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(bridge.isMacConnected)
                    }
                }
                
                // Debug Section
                VStack(spacing: 10) {
                    Button(action: {
                        withAnimation {
                            showDebugLogs.toggle()
                        }
                    }) {
                        HStack {
                            Text("调试日志")
                                .font(.headline)
                            Spacer()
                            Image(systemName: showDebugLogs ? "chevron.down" : "chevron.right")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    if showDebugLogs {
                        VStack {
                            HStack {
                                Text("最近日志 (\(debugLog.logs.count))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("清除") {
                                    debugLog.clearLogs()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(debugLog.logs.prefix(20)) { log in
                                        HStack(alignment: .top, spacing: 6) {
                                            Text(log.icon)
                                                .font(.caption)
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                HStack {
                                                    Text(log.formattedTime)
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundColor(.secondary)
                                                    Text("[\(log.category)]")
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundColor(.blue)
                                                }
                                                Text(log.message)
                                                    .font(.system(size: 11))
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            .frame(height: 200)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }
                }
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
                if bridge.isUsingManualIP {
                    Text("当前使用手动IP: \(bridge.macHostAddress)\n\n输入新IP地址会保存并在应用重启后继续使用。如要改回自动发现，请点击\"自动发现\"按钮。")
                } else if !bridge.savedIPAddress.isEmpty {
                    Text("应用会自动发现 Mac，通常不需要手动设置。\n\n已保存IP: \(bridge.savedIPAddress)\n手动设置的IP会被保存，应用重启后自动使用。")
                } else {
                    Text("应用会自动发现 Mac，通常不需要手动设置。\n\n手动设置的IP会被保存，应用重启后自动使用。")
                }
            }
        }
    }
    
    private func getSourceColor(_ source: String) -> Color {
        switch source {
        case "手动设置":
            return .orange
        case "自动发现":
            return .green
        case "未连接":
            return .gray
        case let str where str.contains("重连中"):
            return .orange
        case let str where str.contains("重新发现"):
            return .blue
        default:
            return .secondary
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
        .environmentObject(WatchConnectivityBridgeV2.shared)
}
