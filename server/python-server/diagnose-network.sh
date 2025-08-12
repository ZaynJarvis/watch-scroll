#!/bin/bash

echo "====================================="
echo "🔍 WatchScroller 网络诊断工具"
echo "====================================="
echo ""

# 1. 检查Python服务器状态
echo "1️⃣ 检查Python服务器状态..."
if lsof -i :8888 | grep -q LISTEN; then
    echo "✅ 服务器正在端口8888运行"
    SERVER_PID=$(lsof -i :8888 | grep LISTEN | awk '{print $2}')
    echo "   进程ID: $SERVER_PID"
else
    echo "❌ 服务器未运行"
    echo "   请运行: ./run_server.sh"
fi
echo ""

# 2. 检查Bonjour服务广播
echo "2️⃣ 检查Bonjour服务广播..."
echo "   正在搜索 _watchscroller._tcp 服务 (5秒)..."
BONJOUR_RESULT=$(timeout 5 dns-sd -B _watchscroller._tcp 2>&1 | grep -c "Add.*_watchscroller._tcp")
if [ "$BONJOUR_RESULT" -gt 0 ]; then
    echo "✅ Bonjour服务正在广播"
    # 获取服务详情
    timeout 2 dns-sd -L WatchScroller _watchscroller._tcp 2>&1 | grep -E "can be reached at|primary_ip" | head -5
else
    echo "❌ 未检测到Bonjour服务"
    echo "   提示: 确保安装了zeroconf: pip install zeroconf"
fi
echo ""

# 3. 获取Mac的IP地址
echo "3️⃣ Mac网络配置..."
echo "   Wi-Fi IP地址:"
WIFI_IP=$(ifconfig en0 2>/dev/null | grep "inet " | awk '{print $2}')
if [ -n "$WIFI_IP" ]; then
    echo "   ✅ en0 (Wi-Fi): $WIFI_IP"
else
    echo "   ❌ 未找到Wi-Fi IP"
fi

# 检查其他可能的网络接口
for interface in en1 en2 en3; do
    IP=$(ifconfig $interface 2>/dev/null | grep "inet " | awk '{print $2}')
    if [ -n "$IP" ]; then
        echo "   ✅ $interface: $IP"
    fi
done

# 检查AWDL接口 (用于AirDrop/点对点)
AWDL_IP=$(ifconfig awdl0 2>/dev/null | grep "inet " | awk '{print $2}')
if [ -n "$AWDL_IP" ]; then
    echo "   ✅ awdl0 (点对点): $AWDL_IP"
else
    echo "   ⚠️  AWDL未激活 (正常情况，需要时会自动激活)"
fi
echo ""

# 4. 检查防火墙
echo "4️⃣ 防火墙状态..."
FW_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1)
if echo "$FW_STATE" | grep -q "disabled"; then
    echo "✅ 防火墙已禁用"
elif echo "$FW_STATE" | grep -q "enabled"; then
    echo "⚠️  防火墙已启用"
    echo "   检查Python是否在允许列表..."
    if /usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null | grep -q "python"; then
        echo "   ✅ 找到Python规则"
    else
        echo "   ❌ Python可能被阻止"
        echo "   解决方案: 系统设置 > 安全性与隐私 > 防火墙 > 防火墙选项"
        echo "   添加Python或暂时关闭防火墙"
    fi
else
    echo "⚠️  无法确定防火墙状态 (需要管理员权限)"
fi
echo ""

# 5. 测试网络连通性
echo "5️⃣ 测试本地网络..."
# 测试localhost
if nc -zv 127.0.0.1 8888 2>&1 | grep -q "succeeded"; then
    echo "✅ localhost:8888 可访问"
else
    echo "❌ localhost:8888 不可访问"
fi

# 测试实际IP
if [ -n "$WIFI_IP" ]; then
    if nc -zv "$WIFI_IP" 8888 2>&1 | grep -q "succeeded"; then
        echo "✅ $WIFI_IP:8888 可访问"
    else
        echo "❌ $WIFI_IP:8888 不可访问"
    fi
fi
echo ""

# 6. iOS应用诊断提示
echo "6️⃣ iPhone应用检查清单..."
echo "   请在iPhone上确认:"
echo "   □ 设置 > 隐私与安全性 > 本地网络 > 启用 'scroll' 应用"
echo "   □ iPhone和Mac连接同一Wi-Fi网络"
echo "   □ Wi-Fi路由器未启用AP隔离"
echo "   □ 在应用中手动输入IP: ${WIFI_IP:-[未找到IP]}"
echo ""

# 7. 建议的解决步骤
echo "7️⃣ 推荐解决方案..."
echo "   方案A: 使用手动IP连接"
echo "   1. 在iPhone应用中输入: ${WIFI_IP:-[获取Mac IP失败]}"
echo "   2. 点击'使用手动IP'按钮"
echo ""
echo "   方案B: 修复Bonjour发现"
echo "   1. 重启Python服务器: ./run_server.sh"
echo "   2. 确保iPhone应用有本地网络权限"
echo "   3. 重启iPhone应用"
echo ""
echo "   方案C: 使用点对点连接 (类似AirDrop)"
echo "   1. 确保Mac和iPhone的蓝牙都开启"
echo "   2. 两设备物理距离保持在10米内"
echo "   3. 重启两端应用"
echo ""

# 8. 生成连接命令
echo "8️⃣ 快速测试命令..."
echo "   在iPhone终端应用(如Termius)中测试:"
if [ -n "$WIFI_IP" ]; then
    echo "   nc -zv $WIFI_IP 8888"
    echo "   或使用curl测试:"
    echo "   curl http://$WIFI_IP:8888"
fi
echo ""

echo "====================================="
echo "诊断完成！如果问题持续，请尝试:"
echo "1. 重启Wi-Fi路由器"
echo "2. 在Mac上暂时关闭防火墙测试"
echo "3. 使用个人热点连接测试"
echo "====================================="