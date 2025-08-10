#!/bin/bash

echo "🔧 Setting up Mac Scroll Control"
echo "==============================="

# Install PyAutoGUI for better scroll control
echo "📦 Installing PyAutoGUI..."
pip3 install pyautogui

# Check if installation was successful
python3 -c "import pyautogui; print('✅ PyAutoGUI installed successfully')" 2>/dev/null || echo "❌ PyAutoGUI installation failed"

echo ""
echo "🎯 Mac Scroll Control Setup Complete!"
echo ""
echo "📋 How it works:"
echo "1. Watch rotates Digital Crown"
echo "2. iPhone receives scroll messages"  
echo "3. iPhone forwards to Python server (port 8888)"
echo "4. Python server directly scrolls Mac browser"
echo ""
echo "🚀 Start server with: python3 tcp_server.py"
echo "🧪 Test by rotating Digital Crown on Watch"