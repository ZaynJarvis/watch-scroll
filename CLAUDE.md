# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WatchScroller is a real-time Apple Watch to Mac browser scrolling application that transforms the Digital Crown into a wireless trackpad with sub-20ms latency. The system uses a 3-tier architecture: Watch → iPhone Bridge → Python Server → Mac.

## Architecture & Key Components

### Core Architecture Pattern
The application follows a message-passing architecture with performance optimizations at each layer:

1. **Watch App** (`app/scroll/scroll-watch Watch App/`): Captures Digital Crown input with 100ms throttling and haptic feedback
2. **iPhone Bridge** (`app/scroll/scroll/`): Relays messages at 60 FPS (16ms intervals) using WatchConnectivity framework
3. **Python Server** (`server/python-server/`): TCP server that converts messages to Mac scroll events via PyAutoGUI

### Ultra-Minimal Protocol
The system uses an optimized JSON protocol for performance:
```json
// Standard format: 95 bytes
{"action":"scroll","pixels":125.45,"direction":"vertical","timestamp":1754855338.01705}

// Optimized format: 15 bytes (84% reduction)
{"a":1,"p":125}
```

Action codes: `a:1` = scroll, `a:2` = status request, `a:3` = ping

### Key Classes & Responsibilities

**WatchConnectivityBridge** (iPhone): 
- Manages WCSession for Watch communication
- Implements message throttling with queue management (latest-message-wins)
- Handles TCP connection to Python server with retry logic
- Uses newline delimiters to prevent message concatenation

**WatchConnectivityManager** (Watch):
- Simplified manager focused on sending scroll commands
- Minimal error handling to preserve battery
- Ultra-minimal JSON generation

**WatchScrollerServer** (Python):
- Multi-threaded TCP server supporting concurrent connections
- Parses both concatenated and newline-delimited JSON messages
- Converts scroll pixels to trackpad-like units (pixels/60, max 3 units)
- Direct system integration via PyAutoGUI

## Development Commands

### Building the iOS + Watch App
```bash
cd app/scroll
open scroll.xcodeproj
# Configure code signing in Xcode, then build & run on devices
```

### Production Build
```bash
cd tools
./build_for_device.sh  # Creates .ipa for distribution
python3 verify_build_ready.py  # Validates build components
```

### Server Development
```bash
cd server/python-server
./run_server.sh  # Starts server with virtual environment
# Server runs on 0.0.0.0:8888, uses PyAutoGUI for Mac scrolling
```

### Icon Generation
```bash
cd tools
python3 create_app_icons.py  # Generates all required icon sizes
python3 fix_watch_icons.py   # Creates missing Watch icons
```

## Performance Considerations

### Real-time Message Flow
- **Watch**: 100ms throttling (10 FPS) for battery optimization
- **iPhone**: 16ms intervals (60 FPS) for ultra-smooth relay
- **Python**: Immediate processing with trackpad-like conversion

### Optimization Patterns
- **Message Throttling**: Different rates at each layer to balance performance and efficiency
- **Queue Management**: Latest-message-wins prevents lag accumulation
- **Data Minimization**: Ultra-minimal JSON format reduces network overhead
- **Silent Operation**: Minimal logging in production for maximum performance

## Key Development Principles

Based on lessons learned during development:

1. **Research platform constraints before architecture decisions** - Apple's security model prevents direct Watch network access
2. **Finalize technology stack before implementation** - Don't let AI choose frameworks during coding
3. **Generate scaffolding before detailed implementation** - Create skeleton classes and method signatures first

## Common Issues & Solutions

### WatchConnectivity Problems
- **"Companion app not installed"**: Ensure Watch and iPhone apps are in unified Xcode project
- **Session not reachable**: Use `session.isActivated` rather than `isReachable` for connection status
- **Message concatenation**: Use newline delimiters and robust JSON parsing

### Digital Crown Issues
- **Crown not responding**: Ensure proper SwiftUI hierarchy with NavigationView and `.focusable()`
- **"Crown Sequencer error"**: Add `.focusable()` modifier to the view containing `digitalCrownRotation`

### Performance Tuning
- **High latency**: Check message throttling rates and JSON payload size
- **Battery drain**: Verify Watch-side throttling is enabled (100ms minimum)
- **Choppy scrolling**: Ensure Python server uses trackpad-like units (pixels/60)

## Testing the Full System

1. Start Python server: `cd server/python-server && ./run_server.sh`
2. Build and install iOS + Watch apps via Xcode
3. Launch both apps and verify "已连接" status on Watch
4. Rotate Digital Crown - should see smooth Mac browser scrolling with sub-20ms latency

The system achieves trackpad-like smoothness through careful optimization at each layer of the message-passing architecture.