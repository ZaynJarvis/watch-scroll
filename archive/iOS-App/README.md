# WatchScroller iOS Bridge App

This iOS app acts as a bridge between the Apple Watch and Mac applications, enabling proper communication through Apple's WatchConnectivity framework.

## Architecture

```
Apple Watch (watchOS) 
    ↕ WatchConnectivity
iPhone App (iOS Bridge)
    ↕ TCP Network  
Mac Application (macOS)
```

## Why This Bridge is Needed

Apple Watch cannot directly connect to Mac applications via TCP/Network sockets due to security restrictions in watchOS. The Apple Watch can only communicate reliably with its paired iPhone through the WatchConnectivity framework.

## How It Works

1. **Watch → iPhone**: Apple Watch sends scroll commands via WatchConnectivity
2. **iPhone → Mac**: iPhone bridge forwards commands to Mac via TCP connection
3. **Mac → iPhone**: Mac sends status updates back to iPhone
4. **iPhone → Watch**: iPhone forwards status updates to Apple Watch

## Usage

1. Build and install this iOS app on your iPhone
2. Ensure your Apple Watch is paired with the iPhone
3. Run the Mac application
4. Launch this iOS bridge app
5. The bridge will automatically connect to both Watch and Mac
6. Keep the iOS app running in the background

## Files

- `WatchScrollerBridgeApp.swift` - Main app entry point
- `Controllers/WatchConnectivityBridge.swift` - Core bridge logic
- `Views/ContentView.swift` - Simple status UI

## Connection Status

The app shows real-time connection status for both:
- Apple Watch connection (via WatchConnectivity)
- Mac application connection (via TCP on port 8888)

## Troubleshooting

- Ensure Mac app is running and listening on port 8888
- Check that Apple Watch is paired and connected to iPhone
- Verify iPhone and Mac are on the same network (if using network connection)
- Keep iOS bridge app running in foreground or background