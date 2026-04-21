# FlockFinder — Developer Documentation

FlockFinder is an iOS companion app for an ESP32-based Wi-Fi surveillance camera detector. The hardware sniffs Wi-Fi signals, identifies known ALPR (Automatic License Plate Reader) cameras and other surveillance devices, and beams the findings to your iPhone over Bluetooth Low Energy. The app records each detection with a GPS timestamp, stores it in an on-device SQLite database, and displays your personal map of surveillance infrastructure.

---

## Table of Contents

1. [The Detection Journey](./01-detection-journey.md) — What happens in the half-second after a camera is found
2. [App Architecture](./02-architecture.md) — The six specialists that power every detection
3. [Bluetooth Protocol](./03-bluetooth.md) — How the ESP32 talks to your iPhone
4. [Database](./04-database.md) — On-device SQLite storage: schema, queries, and exports
5. [Permissions](./05-permissions.md) — iOS hardware access, Info.plist keys, and graceful degradation

---

## Project Structure

```
FlockFinder/
├── FlockFinderApp.swift          # App entry point — wires all managers together
├── Info.plist                    # Permission descriptions, app config
│
├── Managers/                     # Single-responsibility data layer
│   ├── BLEManager.swift          # Bluetooth scanning, connection, data parsing
│   ├── DatabaseManager.swift     # SQLite read/write, schema, exports
│   ├── LocationManager.swift     # GPS, heading, speed
│   └── MotionManager.swift       # Accelerometer (deprecated — GPS now sufficient)
│
├── Models/
│   └── FlockDetection.swift      # Core data model + DeviceType enum
│
└── Views/                        # UI + coordination layer
    ├── ContentView.swift          # TabView shell — Scanner, Map, History, Settings
    ├── DetectionCoordinator.swift # Orchestrates managers on each detection event
    ├── AudioAlertManager.swift    # Sound and haptic feedback
    ├── MapView.swift              # Detection map
    ├── HistoryView.swift          # Detection log list
    ├── SettingsView.swift         # User preferences
    ├── AppSettings.swift          # Persistent settings store
    ├── iCloudManager.swift        # Optional iCloud backup
    └── DebugStreamView.swift      # Raw BLE stream inspector
```

---

## Quick Start

1. Build and run the Xcode project on a physical iPhone (BLE and GPS require real hardware).
2. Grant **Bluetooth**, **Location**, and optionally **Motion** permissions when prompted.
3. Power on the ESP32-S3 FeatherS3 device.
4. Tap **Scanner** → **Start Scanning** in the app. Select your device when it appears.
5. Drive — detections appear on the **Map** tab and accumulate in **History**.

---

## Key Concepts

| Term | Meaning |
|------|---------|
| **ALPR** | Automatic License Plate Reader — roadside cameras that photograph every passing vehicle |
| **Flock Safety** | The primary ALPR vendor FlockFinder targets; cameras broadcast recognisable Wi-Fi SSIDs |
| **BLE** | Bluetooth Low Energy — low-power short-range radio used by the ESP32 to push detection data |
| **ESP32-S3** | The microcontroller in the hardware device; scans Wi-Fi and sends JSON over BLE |
| **SQLite** | Embedded, serverless database engine; the entire detection history lives in one `.sqlite` file |
| **DetectionCoordinator** | The glue class that wires BLE events to location lookup, database writes, and audio alerts |

---

## Supported Device Types

FlockFinder recognises thirteen camera families:

| Device | Category |
|--------|----------|
| Flock Safety | ALPR / Law enforcement |
| Verkada | Enterprise security |
| Axis | Professional IP camera |
| Hikvision / Dahua | Chinese surveillance |
| Ring | Amazon smart doorbell |
| Nest | Google home camera |
| Lorex / Reolink / Arlo / Wyze / Eufy | Consumer IP camera |
