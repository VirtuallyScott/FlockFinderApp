# The Detection Journey

> What FlockFinder actually does — and the data path your detection takes in the half-second after a camera is found.

---

## What Is This App, Really?

An ESP32-S3 FeatherS3 device is constantly sniffing the air for Wi-Fi signals whose patterns match known surveillance cameras — particularly **Flock Safety** ALPR cameras that photograph licence plates. When it finds one, it beams a compact JSON message to your iPhone over Bluetooth Low Energy. Your phone receives the signal, plays an audio alert, records GPS coordinates, and saves everything to a private on-device database.

Three moving parts:

| Component | Role |
|-----------|------|
| **The Hardware** | ESP32-S3 scans Wi-Fi, detects camera SSIDs and MAC patterns, broadcasts BLE notifications |
| **The App** | Receives BLE data, enriches it with GPS, stores it in SQLite, shows it on a map |
| **The Map** | Every detection becomes a pin — building a personal picture of local surveillance infrastructure |

---

## Step-by-Step: What Happens on a Detection

```
[ESP32 Hardware]
     │
     │  1. Detects a Flock Safety Wi-Fi signal while scanning
     │  2. Packages: device type, MAC address, SSID, RSSI, confidence → JSON
     │
     ▼  BLE Notification
[BLEManager]
     │
     │  3. Receives notification on the detection characteristic
     │  4. Parses JSON → DetectionData struct
     │  5. Fires onDetection callback
     │
     ▼  Callback
[DetectionCoordinator]
     │
     │  6. Requests current location from LocationManager
     │
     ▼  Request
[LocationManager]
     │
     │  7. Returns: latitude, longitude, altitude, accuracy, speed, heading
     │
     ▼  Location data
[DetectionCoordinator]
     │
     │  8. Combines BLE data + location → FlockDetection model
     │  9. Checks confidence threshold (configurable in AppSettings)
     │
     ▼  Insert
[DatabaseManager]
     │
     │  10. Writes FlockDetection to flockfinder.sqlite
     │
     ▼  Side effects
[AudioAlertManager]    [iCloudManager]     [BLEManager.recentDetections]
     │                       │                          │
     11. Plays chime    12. Schedules backup     13. Prepends to
                             (max once/hr)            recent list (cap 10)
```

---

## The FlockDetection Model

Every detection is captured as a `FlockDetection` — a single Swift struct that bundles every piece of information about one camera sighting.

```swift
// Models/FlockDetection.swift

struct FlockDetection: Identifiable, Codable {
    let id: UUID
    let deviceType: DeviceType   // .flock, .verkada, .ring, etc.
    let macAddress: String?
    let ssid: String?
    let rssi: Int                // Signal strength (dBm) — more negative = weaker
    let confidence: Double       // 0.0–1.0 from the ESP32's matching logic
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let accuracy: Double
    let speed: Double
    let heading: Double
    let timestamp: Date
}
```

### What each field means

| Field | Source | Notes |
|-------|--------|-------|
| `deviceType` | ESP32 JSON `"type"` | Parsed into the `DeviceType` enum |
| `macAddress` | ESP32 JSON `"mac"` | Hardware address of the detected device; may be nil |
| `ssid` | ESP32 JSON `"ssid"` | Wi-Fi network name broadcast by the camera |
| `rssi` | ESP32 JSON `"rssi"` | Received signal strength in dBm; −40 is close, −90 is distant |
| `confidence` | ESP32 JSON `"confidence"` | The firmware's certainty score; detections below `AppSettings.minimumConfidence` are discarded |
| `latitude` / `longitude` | `LocationManager` | `CLLocation.coordinate` at time of detection |
| `altitude` | `LocationManager` | Metres above sea level |
| `accuracy` | `LocationManager` | Horizontal accuracy in metres (lower = better) |
| `speed` | `LocationManager` | Speed in m/s converted to mph for display |
| `heading` | `LocationManager` | Course (direction of travel) in degrees; falls back to compass if GPS course unavailable |
| `timestamp` | `Date()` at detection | ISO 8601 string in SQLite; `Date` in-memory |

---

## The Confidence Filter

Before saving, `DetectionCoordinator` checks:

```swift
guard detection.confidence >= appSettings.minimumConfidence else {
    print("⚠️ Detection below confidence threshold")
    return  // Discard — do not save, do not alert
}
```

The default threshold is configurable in **Settings → Minimum Confidence**. Raising it reduces false positives; lowering it captures weaker/uncertain detections.

---

## What Triggers the Audio Alert

After a detection clears the confidence gate and is saved to the database:

```swift
if appSettings.audibleAlertsEnabled {
    audioManager.playDetectionAlert()
}

if appSettings.hapticFeedback {
    triggerHapticFeedback()
}
```

Both are independently togglable. The audio session is configured for CarPlay and Bluetooth speakers so the alert plays through your car stereo.

---

## iCloud Backup Scheduling

Each successful detection schedules a background iCloud backup — but with throttling:

```swift
iCloudManager.shared.scheduleAutomaticBackup()
// Internal: only actually runs if last backup was > 1 hour ago
```

This keeps your detection history synced across devices without hammering iCloud on every single detection.

---

## Where to Find This Code

| Concept | File |
|---------|------|
| Detection data model | `Models/FlockDetection.swift` |
| Orchestration logic | `Views/DetectionCoordinator.swift` |
| BLE parsing | `Managers/BLEManager.swift` — `DetectionData.init(from:)` |
| Location enrichment | `Managers/LocationManager.swift` — `getLocationData()` |
| Database write | `Managers/DatabaseManager.swift` — `insertDetection(_:)` |
| Audio alert | `Views/AudioAlertManager.swift` — `playDetectionAlert()` |
| Confidence setting | `Views/AppSettings.swift` — `minimumConfidence` |
