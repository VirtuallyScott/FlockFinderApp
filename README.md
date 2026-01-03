# FlockFinder iOS App

A companion iOS application for the FlockFinder ESP32-S3 surveillance camera detection system.

## Features

- **BLE Connectivity**: Connects to your FeatherS3 FlockFinder device via Bluetooth Low Energy
- **GPS Logging**: Records precise GPS coordinates for each detection
- **Motion Tracking**: Captures speed, heading, and activity type (walking, driving, etc.)
- **SQLite Storage**: All detections stored locally for offline access
- **Interactive Map**: Visualize detection locations on a map
- **Detection History**: Browse and search past detections
- **Data Export**: Export to CSV, JSON, or GPX formats

## Requirements

- iOS 16.0 or later
- iPhone with Bluetooth 4.0+ and GPS
- FlockFinder ESP32 device with BLE broadcast firmware

## BLE Protocol

The app communicates with the FlockFinder device using the following UUIDs:

- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Detection Characteristic**: `beb5483e-36e1-4688-b7f5-ea07361b26a8` (Notify)
- **Command Characteristic**: `beb5483e-36e1-4688-b7f5-ea07361b26a9` (Write)

### Detection JSON Format

When a surveillance camera is detected, the device broadcasts JSON:

```json
{
  "type": "Flock Safety",
  "mac": "AA:BB:CC:DD:EE:FF",
  "ssid": "FLOCK-CAM-001",
  "rssi": -55,
  "confidence": 0.95,
  "ts": 123456789
}
```

## Project Structure

```
FlockFinderApp/
├── FlockFinder.xcodeproj/     # Xcode project
└── FlockFinder/
    ├── FlockFinderApp.swift   # Main app entry point
    ├── Info.plist             # App configuration & permissions
    ├── Assets.xcassets/       # App icons & colors
    ├── Views/
    │   ├── ContentView.swift  # Main tab view
    │   ├── MapView.swift      # Detection map
    │   ├── HistoryView.swift  # Detection history list
    │   └── SettingsView.swift # App settings
    ├── Managers/
    │   ├── BLEManager.swift      # CoreBluetooth handler
    │   ├── LocationManager.swift # CoreLocation handler
    │   ├── MotionManager.swift   # CoreMotion handler
    │   └── DatabaseManager.swift # SQLite handler
    └── Models/
        └── FlockDetection.swift  # Detection data model
```

## Building

1. Open `FlockFinder.xcodeproj` in Xcode 15+
2. Select your development team in Signing & Capabilities
3. Build and run on a physical iOS device (BLE requires hardware)

## Permissions

The app requires the following permissions (configured in Info.plist):

- **Bluetooth** - Connect to FlockFinder device
- **Location (When In Use)** - Log detection locations
- **Location (Always)** - Background detection logging
- **Motion** - Record direction of travel

## Firmware Updates

The ESP32 firmware has been updated to include BLE GATT server functionality:

- Device advertises as "FlockFinder-S3"
- Automatically broadcasts detections to connected iOS app
- Continues normal WiFi/BLE scanning for surveillance cameras

To flash the updated firmware:
```bash
cd /Users/scottsmith/tmp/flock
source .venv/bin/activate
cd flock-you
pio run -e um_feathers3 -t upload
```

## Detection Types

The app recognizes the following surveillance camera types:

- **Flock Safety** - ALPR/License plate readers
- **Verkada** - Enterprise security cameras
- **Ring** - Amazon doorbell cameras
- **Nest** - Google smart cameras
- **Raven** - Gunshot detection sensors
- And more...

## Data Privacy

- All detection data is stored locally on device
- Optional crowdsource upload with location anonymization
- No data sent without explicit user consent

## License

This app is part of the FlockFinder surveillance awareness project.
