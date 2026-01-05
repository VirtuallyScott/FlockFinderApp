# Feature: iOS Configuration Management

**Branch:** `feature/ios-config-management`  
**Status:** Implemented  
**Date:** January 5, 2026

---

## Overview

This feature enables the FlockFinder iOS app to manage and update detection configuration on the ESP32 device over BLE. Detection patterns (MAC prefixes, SSIDs, BLE UUIDs) are now managed dynamically through the iOS app, allowing updates without reflashing the ESP32 firmware.

---

## Implementation Summary

### Completed Components

#### ESP32 Firmware (flock-you)
- ✅ `config_manager.h` - Dynamic configuration manager with NVS persistence
- ✅ `ble_broadcast.h` - Added CONFIG characteristic and chunked transfer support
- ✅ `main.cpp` - Refactored to use ConfigManager instead of static arrays

#### iOS App (FlockFinderApp)
- ✅ `ScanConfiguration.swift` - Configuration data model matching ESP32 structure
- ✅ `ConfigurationManager.swift` - Local persistence and sync state management
- ✅ `BLEManager.swift` - CONFIG characteristic support with chunked transfers
- ✅ `ConfigurationView.swift` - UI for managing patterns and scan settings

---

## Goals

1. **Centralized Configuration** - iOS app becomes the source of truth for detection patterns
2. **Dynamic Updates** - Push new MAC prefixes, SSIDs, and scan settings without reflashing ESP32
3. **User Customization** - Allow users to add/remove detection targets via the app
4. **Scan Control** - Adjust scan intervals, channel hop speed from iOS

---

## Architecture

### ESP32 (flock-you)
```
src/
├── main.cpp                 # Uses ConfigManager for pattern matching
├── ble_broadcast.h          # CONFIG characteristic (beb5483e-...-26ab)
└── config_manager.h         # NVS persistence, pattern vectors, JSON serialization
```

### iOS App (FlockFinderApp)
```
FlockFinder/
├── Models/
│   └── ScanConfiguration.swift      # Config data model with Codable
├── Managers/
│   ├── ConfigurationManager.swift   # UserDefaults persistence, sync state
│   └── BLEManager.swift             # CONFIG characteristic + callbacks
├── Views/
│   └── ConfigurationView.swift      # Pattern list UI, sync controls
└── Resources/
    └── DefaultPatterns.json         # Bundled defaults (in code)
```

---

## BLE Protocol Extensions

### Configuration Characteristic

| Property | Value |
|----------|-------|
| **UUID** | `beb5483e-36e1-4688-b7f5-ea07361b26ab` |
| **Properties** | Read, Write, Notify |
| **Purpose** | Send/receive configuration data |

### Commands (via Command Characteristic)
- `GET_CONFIG` - Request current config from ESP32
- `SAVE_CONFIG` - Persist config to ESP32 flash (NVS)
- `RESET_CONFIG` - Reset ESP32 config to factory defaults

### Chunked Transfer Protocol
For configurations larger than BLE MTU (~512 bytes):
1. Send `CONFIG_START` marker
2. Send JSON data in ~480 byte chunks
3. Send `CONFIG_END` marker

### Configuration JSON Format

```json
{
  "v": 1,
  "wsi": 5000,
  "bsi": 3000,
  "chi": 500,
  "ssid": [
    {"p": "Flock-", "t": "Flock Safety", "e": true}
  ],
  "mac": [
    {"p": "b0:b2:1c", "t": "Flock Safety", "e": true}
  ],
  "ble_n": [
    {"p": "Flock", "t": "Flock Safety", "e": true}
  ],
  "ble_u": [
    {"p": "7b183224-9168-443e-a927-7aeea07e8105", "t": "Raven", "e": true}
  ]
}
```

| Field | Description |
|-------|-------------|
| `v` | Version number |
| `wsi` | WiFi scan interval (ms) |
| `bsi` | BLE scan interval (ms) |
| `chi` | Channel hop interval (ms) |
| `ssid` | SSID pattern array |
| `mac` | MAC prefix array |
| `ble_n` | BLE name pattern array |
| `ble_u` | BLE UUID pattern array |
| `p` | Pattern string |
| `t` | Device type |
| `e` | Enabled flag |

---

## Default Patterns

The following patterns are built into both ESP32 and iOS apps:

### SSID Patterns
| Pattern | Device Type |
|---------|-------------|
| `Flock-` | Flock Safety |
| `FS-` | Flock Safety |
| `FlockSafety` | Flock Safety |
| `ALPRCam` | Flock Safety |
| `Penguin-` | Penguin |
| `Pigvision` | Pigvision |
| `L5Q` | Motorola |
| `M500` | Motorola |

### MAC Prefixes
| Prefix | Device Type |
|--------|-------------|
| `b0:b2:1c` | Flock Safety |
| `34:94:54` | Flock Safety |
| `00:e0:4c` | Flock Safety |
| `a4:e5:7c` | Quectel |
| `00:60:35` | Raven |
| `00:14:3e` | Sierra Wireless |

### BLE UUIDs (Raven Gunshot Detectors)
| UUID | Description |
|------|-------------|
| `7b183224-9168-443e-a927-7aeea07e8105` | Raven Device Info |
| `0000180a-0000-1000-8000-00805f9b34fb` | Standard Device Info |
| `0000affe-0000-1000-8000-00805f9b34fb` | Raven GPS Service |
| `0000b007-0000-1000-8000-00805f9b34fb` | Raven Power Service |

---

## Usage

### iOS App
1. Connect to FlockFinder ESP32
2. Navigate to Configuration tab
3. View/edit patterns and scan intervals
4. Tap "Sync" to push changes to ESP32
5. Tap "Save to ESP32 Flash" for persistence across reboots

### Adding Custom Patterns
1. Tap + button in Configuration view
2. Select pattern type (SSID, MAC, BLE Name, UUID)
3. Enter pattern and select device type
4. Pattern is immediately added locally
5. Sync to push to ESP32

---

## Testing Checklist

- [ ] Connect iOS app to ESP32
- [ ] Fetch configuration from ESP32
- [ ] Add new SSID pattern
- [ ] Toggle pattern enabled/disabled
- [ ] Change scan intervals
- [ ] Push config to ESP32
- [ ] Save config to ESP32 flash
- [ ] Reset to defaults
- [ ] Verify detection with new pattern
- [ ] Reboot ESP32 and verify persistence
      {"pattern": "FS Ext Battery", "enabled": true, "deviceType": "FS Ext Battery"}
    ],
    "bleServiceUuids": [
      {"uuid": "00003100-0000-1000-8000-00805f9b34fb", "enabled": true, "deviceType": "Raven"}
    ]
  }
}
```

### Command Extensions

| Command | Direction | Description |
|---------|-----------|-------------|
| `GET_CONFIG` | iOS → ESP32 | Request current configuration |
| `SET_CONFIG:{json}` | iOS → ESP32 | Push new configuration |
| `SAVE_CONFIG` | iOS → ESP32 | Persist config to ESP32 flash |
| `RESET_CONFIG` | iOS → ESP32 | Reset to firmware defaults |
| `CONFIG:{json}` | ESP32 → iOS | Configuration response |

---

## iOS Data Storage Options

### Recommended: SQLite + JSON Hybrid

| Data | Storage | Reason |
|------|---------|--------|
| Detection patterns | SQLite | Queryable, efficient, existing DB |
| Scan settings | UserDefaults | Simple key-value, small data |
| Bundled defaults | JSON file | Easy to update, readable |

### Schema Additions

```sql
-- New table for MAC prefixes
CREATE TABLE mac_patterns (
    id INTEGER PRIMARY KEY,
    prefix TEXT NOT NULL UNIQUE,
    device_type TEXT NOT NULL,
    enabled INTEGER DEFAULT 1,
    custom INTEGER DEFAULT 0,  -- User added vs bundled
    created_at INTEGER
);

-- New table for SSID patterns
CREATE TABLE ssid_patterns (
    id INTEGER PRIMARY KEY,
    pattern TEXT NOT NULL UNIQUE,
    device_type TEXT NOT NULL,
    enabled INTEGER DEFAULT 1,
    custom INTEGER DEFAULT 0,
    created_at INTEGER
);

-- New table for BLE patterns
CREATE TABLE ble_patterns (
    id INTEGER PRIMARY KEY,
    pattern TEXT NOT NULL,
    pattern_type TEXT NOT NULL,  -- 'name' or 'uuid'
    device_type TEXT NOT NULL,
    enabled INTEGER DEFAULT 1,
    custom INTEGER DEFAULT 0,
    created_at INTEGER
);

-- Scan configuration
CREATE TABLE scan_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER
);
```

---

## Implementation Phases

### Phase 1: Data Model & Storage (iOS)
- [ ] Create `ScanConfiguration` model
- [ ] Create `ConfigurationManager` class
- [ ] Add SQLite tables for patterns
- [ ] Bundle `DefaultPatterns.json` with known signatures
- [ ] Migrate hardcoded patterns from firmware to JSON

### Phase 2: Configuration UI (iOS)
- [ ] Create `ConfigurationView` with pattern lists
- [ ] Add/edit/delete pattern functionality
- [ ] Enable/disable individual patterns
- [ ] Scan settings controls (intervals, channels)
- [ ] Import/export configuration

### Phase 3: BLE Protocol Extension (Both)
- [ ] Add CONFIG characteristic UUID to ESP32
- [ ] Implement `GET_CONFIG` / `SET_CONFIG` commands
- [ ] Add config push to `BLEManager.swift`
- [ ] Handle chunked transfer for large configs

### Phase 4: Dynamic Configuration (ESP32)
- [ ] Create `config_manager.h` module
- [ ] Replace static arrays with dynamic vectors
- [ ] Implement config parsing from BLE
- [ ] Add NVS flash storage for persistence
- [ ] Implement config reset to defaults

### Phase 5: Sync & Validation
- [ ] Config version tracking
- [ ] Validation on both ends
- [ ] Error handling and recovery
- [ ] Sync status indicator in UI

---

## Default Pattern Data

### MAC Prefixes to Bundle

```json
{
  "macPrefixes": [
    {"prefix": "58:8e:81", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "cc:cc:cc", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "ec:1b:bd", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "90:35:ea", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "04:0d:84", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "f0:82:c0", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "1c:34:f1", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "38:5b:44", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "94:34:69", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "b4:e3:f9", "deviceType": "FS Ext Battery", "source": "wigle.net"},
    {"prefix": "70:c9:4e", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "3c:91:80", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "d8:f3:bc", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "80:30:49", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "14:5a:fc", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "74:4c:a1", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "08:3a:88", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "9c:2f:9d", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "94:08:53", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "e4:aa:ea", "deviceType": "Flock Safety", "source": "wigle.net"},
    {"prefix": "b4:1e:52", "deviceType": "Flock Safety", "source": "IEEE OUI"}
  ]
}
```

### SSID Patterns to Bundle

```json
{
  "ssidPatterns": [
    {"pattern": "flock", "deviceType": "Flock Safety", "caseSensitive": false},
    {"pattern": "Flock", "deviceType": "Flock Safety", "caseSensitive": false},
    {"pattern": "FLOCK", "deviceType": "Flock Safety", "caseSensitive": false},
    {"pattern": "FS Ext Battery", "deviceType": "FS Ext Battery", "caseSensitive": true},
    {"pattern": "Penguin", "deviceType": "Penguin", "caseSensitive": false},
    {"pattern": "Pigvision", "deviceType": "Pigvision", "caseSensitive": false}
  ]
}
```

### Raven UUIDs to Bundle

```json
{
  "bleServiceUuids": [
    {"uuid": "0000180a-0000-1000-8000-00805f9b34fb", "deviceType": "Raven", "description": "Device Info"},
    {"uuid": "00003100-0000-1000-8000-00805f9b34fb", "deviceType": "Raven", "description": "GPS Location"},
    {"uuid": "00003200-0000-1000-8000-00805f9b34fb", "deviceType": "Raven", "description": "Power/Battery"},
    {"uuid": "00003300-0000-1000-8000-00805f9b34fb", "deviceType": "Raven", "description": "Network Status"},
    {"uuid": "00003400-0000-1000-8000-00805f9b34fb", "deviceType": "Raven", "description": "Upload Stats"},
    {"uuid": "00003500-0000-1000-8000-00805f9b34fb", "deviceType": "Raven", "description": "Error Service"},
    {"uuid": "00001809-0000-1000-8000-00805f9b34fb", "deviceType": "Raven", "description": "Legacy Health"},
    {"uuid": "00001819-0000-1000-8000-00805f9b34fb", "deviceType": "Raven", "description": "Legacy Location"}
  ]
}
```

---

## Memory Considerations (ESP32)

### Current Static Allocation
- SSID patterns: ~100 bytes
- MAC prefixes: ~500 bytes  
- Device names: ~100 bytes
- Raven UUIDs: ~400 bytes
- **Total: ~1.1 KB**

### Dynamic Allocation Limits
- Maximum patterns per category: 50
- Maximum total config size: 8 KB
- NVS flash partition: 20 KB reserved

### ESP32-S3 Resources (FeatherS3)
- Flash: 16 MB
- PSRAM: 8 MB
- Plenty of headroom for configuration storage

---

## Testing Plan

### Unit Tests
- [ ] Configuration JSON parsing
- [ ] SQLite CRUD operations
- [ ] Pattern matching logic

### Integration Tests
- [ ] BLE config transfer (small payload)
- [ ] BLE config transfer (chunked)
- [ ] Config persistence across reboots
- [ ] iOS ↔ ESP32 roundtrip

### Manual Tests
- [ ] Add custom MAC prefix, verify detection
- [ ] Disable pattern, verify no detection
- [ ] Change scan interval, verify timing
- [ ] Reset to defaults, verify patterns restored

---

## Files to Create/Modify

### iOS App (FlockFinderApp)

| File | Action | Description |
|------|--------|-------------|
| `Models/ScanConfiguration.swift` | Create | Configuration data models |
| `Managers/ConfigurationManager.swift` | Create | SQLite config storage |
| `Managers/BLEManager.swift` | Modify | Add config characteristic handling |
| `Views/ConfigurationView.swift` | Create | Pattern management UI |
| `Views/ContentView.swift` | Modify | Add Configuration tab |
| `Resources/DefaultPatterns.json` | Create | Bundled default patterns |

### ESP32 (flock-you)

| File | Action | Description |
|------|--------|-------------|
| `src/config_manager.h` | Create | Dynamic config module |
| `src/ble_broadcast.h` | Modify | Add CONFIG characteristic |
| `src/main.cpp` | Modify | Use dynamic patterns |
| `platformio.ini` | Modify | Adjust partition scheme for NVS |

---

## Open Questions

1. **Chunked Transfer** - BLE MTU is typically 20-512 bytes. Large configs need chunking protocol.
2. **Conflict Resolution** - What happens if iOS and ESP32 have different config versions?
3. **Offline Mode** - Should ESP32 always have fallback patterns if iOS never connects?
4. **OUI Database** - Should we include full IEEE OUI lookup, or just known surveillance vendors?

---

## References

- [BLE_PROTOCOL_REFERENCE.md](BLE_PROTOCOL_REFERENCE.md) - Current BLE protocol spec
- [DETECTION_SIGNATURES.md](DETECTION_SIGNATURES.md) - Known detection patterns
- [flock-you/src/main.cpp](../flock-you/src/main.cpp) - Current firmware patterns
- [IEEE OUI Database](https://standards-oui.ieee.org/oui/oui.txt) - Official MAC prefix registry
