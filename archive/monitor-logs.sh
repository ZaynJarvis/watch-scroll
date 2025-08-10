#!/bin/bash

echo "📊 Monitoring Mac App Logs"
echo "=========================="
echo ""
echo "Watching for WatchScroller logs..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Start log streaming in background and filter for our app
log stream --predicate 'processImagePath CONTAINS "WatchScroller" OR messageText CONTAINS "WatchScroller"' --style compact &
LOG_PID=$!

# Also monitor Console.app logs
echo "Also monitoring Console logs..."
tail -f /var/log/system.log 2>/dev/null | grep -i watchscroller &
TAIL_PID=$!

# Wait for user to press Ctrl+C
trap "kill $LOG_PID $TAIL_PID 2>/dev/null; exit" INT

# Show recent logs first
echo "📋 Recent logs from last 2 minutes:"
echo "-----------------------------------"
log show --predicate 'processImagePath CONTAINS "WatchScroller" OR messageText CONTAINS "WatchScroller"' --last 2m --style compact 2>/dev/null

echo ""
echo "📡 Now monitoring live logs..."
echo "-----------------------------"

wait