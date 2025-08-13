# iPhone-Mac Connection Improvement Plan

## Analysis Summary
The current implementation has complex, intertwined logic with multiple timers, state flags, and discovery methods that can conflict. The code spans 1467 lines with numerous edge cases and redundant paths.

## Proposed Improvements

### 1. **Separate Concerns Architecture**
- **Discovery Service**: Handle IP discovery (Bonjour, Supabase, manual)  
- **Connection Manager**: Handle TCP connection lifecycle
- **Network Monitor**: Handle network change detection
- **State Manager**: Centralize connection state

### 2. **Simplified Discovery Logic**
- Use priority-based discovery: Cached IP → Manual IP → Bonjour → Supabase
- Implement intelligent caching to avoid redundant discoveries
- Single timeout strategy across all discovery methods

### 3. **Robust Connection Management**
- Exponential backoff for connection retries instead of fixed intervals
- Single heartbeat mechanism for connection monitoring
- Graceful degradation when services are unavailable

### 4. **Streamlined Error Handling**
- Unified error categorization (network vs server vs permission errors)
- Consistent retry strategies based on error type
- Prevent timer/resource leaks with proper cleanup

### 5. **Implementation Steps**
1. Create modular service classes while preserving existing API
2. Refactor discovery logic with priority-based approach
3. Implement exponential backoff connection manager
4. Add centralized connection health monitoring
5. Simplify state management with unified coordinator
6. **Ensure iPhone app builds successfully** - validate Xcode project compiles
7. Verify reduced complexity (~800 lines vs current 1467)

## Final Improved Architecture Sequence Diagram

```mermaid
sequenceDiagram
    participant UI as iPhone UI
    participant SM as StateManager
    participant DS as DiscoveryService
    participant CM as ConnectionManager
    participant NM as NetworkMonitor
    participant Mac as Mac Server
    
    Note over UI,Mac: Initialization Phase
    UI->>SM: Initialize
    SM->>DS: Start discovery
    SM->>CM: Initialize connection manager
    SM->>NM: Start network monitoring
    
    Note over DS,Mac: Priority-Based Discovery
    DS->>DS: 1. Check cached IP (if recent)
    alt Cached IP available
        DS-->>SM: Use cached IP
    else No cache
        DS->>DS: 2. Check manual IP setting
        alt Manual IP set
            DS-->>SM: Use manual IP
        else No manual IP
            DS->>DS: 3. Start Bonjour discovery
            alt Bonjour succeeds
                DS-->>SM: Bonjour IP discovered
            else Bonjour fails
                DS->>DS: 4. Try Supabase fallback
                DS-->>SM: Supabase IP or failure
            end
        end
    end
    
    Note over SM,Mac: Connection Management
    SM->>CM: Connect to IP
    CM->>Mac: TCP connection attempt
    
    alt Connection Success
        Mac-->>CM: Connection established
        CM-->>SM: Connected
        SM-->>UI: Update connection status
        CM->>CM: Start heartbeat monitoring
    else Connection Failed
        Mac-->>CM: Connection failed
        CM->>CM: Exponential backoff delay
        alt Retry limit not reached
            CM->>Mac: Retry connection
        else Max retries reached
            CM-->>SM: Connection failed
            SM->>DS: Request fresh discovery
        end
    end
    
    Note over UI,Mac: Runtime Operation
    loop Normal Operation
        UI->>SM: Send scroll message
        SM->>CM: Forward message
        CM->>Mac: TCP message
        CM->>CM: Monitor connection health
    end
    
    Note over NM,Mac: Error Recovery
    alt Network Change Detected
        NM-->>SM: Network changed
        SM->>CM: Cancel current connection
        SM->>DS: Clear cache and rediscover
    else Connection Lost
        CM->>CM: Detect via heartbeat failure
        CM->>CM: Immediate reconnect attempt
        alt Reconnect fails
            CM-->>SM: Connection lost
            SM->>DS: Trigger rediscovery
        end
    end
```

The goal is to improve reliability and maintainability while ensuring the app builds correctly.