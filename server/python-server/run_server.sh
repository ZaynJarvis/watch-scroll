#!/bin/bash

cd "$(dirname "$0")"

echo "🚀 Starting WatchScroller Python Server with PyAutoGUI support"
echo "=============================================================="

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "📦 Activating virtual environment..."
    source venv/bin/activate
    echo "✅ Virtual environment activated"
else
    echo "❌ Virtual environment not found. Run setup first:"
    echo "   python3 -m venv venv && source venv/bin/activate && pip install pyautogui"
    exit 1
fi

# Check if required packages are available
python3 -c "import pyautogui" 2>/dev/null || {
    echo "❌ PyAutoGUI not available. Installing..."
    pip install pyautogui
}

python3 -c "import requests" 2>/dev/null || {
    echo "❌ Requests not available. Installing..."
    pip install requests
}

echo ""
echo "🎯 Server will:"
echo "   • Listen on 0.0.0.0:8888 for iPhone connections"
echo "   • Parse both newline-delimited and concatenated JSON messages"
echo "   • Convert Watch scroll commands to Mac scrolling via PyAutoGUI"
echo ""

# Start the server
python3 tcp_server.py