#!/bin/bash

echo "🔍 WatchScroller 网络诊断"
echo "========================"
echo ""

# Check if Mac app is running
echo "📋 检查Mac应用状态..."
MAC_PROCESS=$(ps aux | grep WatchScroller.app | grep -v grep)
if [ -n "$MAC_PROCESS" ]; then
    echo "✅ Mac应用正在运行"
    echo "   进程: $(echo $MAC_PROCESS | awk '{print $2}')"
else
    echo "❌ Mac应用未运行"
    echo "   请先启动Mac应用: open macOS-App/WatchScroller.xcodeproj"
fi

echo ""

# Check if port 8888 is listening
echo "🔍 检查端口8888监听状态..."
PORT_CHECK=$(netstat -an | grep :8888 | grep LISTEN)
if [ -n "$PORT_CHECK" ]; then
    echo "✅ 端口8888正在监听"
    echo "   $PORT_CHECK"
else
    echo "❌ 端口8888未监听"
    echo "   Mac应用可能未正确启动网络监听器"
fi

echo ""

# Get Mac's IP addresses
echo "🌐 Mac的网络地址："
echo "---------------------"
ifconfig | grep "inet " | while read line; do
    IP=$(echo $line | awk '{print $2}')
    INTERFACE=$(echo $line | sed 's/.*inet //' | sed 's/ .*//')
    if [[ $IP =~ ^192\.168\. ]] || [[ $IP =~ ^10\. ]] || [[ $IP =~ ^172\. ]]; then
        echo "📍 局域网IP: $IP (推荐用于iPhone连接)"
    elif [ "$IP" = "127.0.0.1" ]; then
        echo "🔄 本地回环: $IP (仅本机可用)"
    else
        echo "🌍 其他地址: $IP"
    fi
done

echo ""

# Test network connectivity
echo "🔌 测试网络连接..."
LAN_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [ -n "$LAN_IP" ]; then
    echo "测试连接到 $LAN_IP:8888..."
    if nc -z "$LAN_IP" 8888 2>/dev/null; then
        echo "✅ 可以连接到 $LAN_IP:8888"
    else
        echo "❌ 无法连接到 $LAN_IP:8888"
    fi
    
    echo "测试连接到 localhost:8888..."
    if nc -z localhost 8888 2>/dev/null; then
        echo "✅ 可以连接到 localhost:8888"
    else
        echo "❌ 无法连接到 localhost:8888"
    fi
else
    echo "❌ 无法获取局域网IP地址"
fi

echo ""
echo "📱 iPhone应用设置建议："
echo "====================="
if [ -n "$LAN_IP" ]; then
    echo "1. 在iPhone应用中点击'设置IP'按钮"
    echo "2. 输入Mac的IP地址: $LAN_IP" 
    echo "3. 点击'连接'进行连接"
else
    echo "❌ 请检查Mac的网络连接"
fi

echo ""
echo "🔧 故障排除步骤："
echo "================"
echo "1. 确保Mac应用正在运行并显示'Network listener ready'"
echo "2. 确保Mac和iPhone连接到同一WiFi网络"
echo "3. 在iPhone应用中设置正确的Mac IP地址"
echo "4. 如果仍无法连接，请检查防火墙设置"
echo "5. 重启所有应用并按以下顺序启动:"
echo "   a) Mac应用 → b) iPhone桥接应用 → c) Apple Watch应用"