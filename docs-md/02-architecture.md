# App Architecture

> Five specialist managers and one coordinator — each with a single job, each talking to the others through a careful chain of command.

---

## The Design Philosophy

FlockFinder uses a **single-responsibility manager pattern**: every piece of hardware or storage concern is owned by exactly one class. No manager reaches into another manager's internals. They communicate only through callbacks and published state.

Think of it like a submarine crew — every person has one role. The captain (`DetectionCoordinator`) coordinates them without physically pulling the levers.

---

## The Six Classes

### BLEManager
**The Radio Operator**

`Managers/BLEManager.swift`

Owns the entire Bluetooth connection lifecycle: scanning, pairing, characteristic discovery, and data reception. Parses raw BLE bytes into typed `DetectionData` structs and fires an `onDetection` callback when data arrives. Also maintains a rolling `recentDetections` list (capped at 10) for the live scanner UI.

```swift
class BLEManager: NSObject, ObservableObject {
    @Published var isConnected: Bool
    @Published var connectionState: ConnectionState
    @Published var recentDetections: [FlockDetection]

    var onDetection: ((DetectionData) -> Void)?  // The callback DetectionCoordinator hooks into
}
```

Key responsibilities:
- Scanning for devices matching `["flockfinder", "flock", "feather", "esp32", "s3"]`
- Connecting to a selected peripheral
- Subscribing to the detection, command, and stream BLE characteristics
- Parsing inbound JSON into `DetectionData`
- Maintaining RSSI updates on a timer

---

### LocationManager
**The Navigator**

`Managers/LocationManager.swift`

Wraps `CLLocationManager` and exposes a clean, always-current snapshot of the device's physical position. Updates every 5 metres while the app is in the foreground.

```swift
class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus

    var headingDegrees: Double  // GPS course (direction of travel); falls back to compass
    var speedMPH: Double        // Converts m/s to mph
}
```

Key responsibilities:
- Requesting `whenInUse` location authorisation
- Providing GPS coordinates, altitude, accuracy, speed, and heading on demand
- Preferring `location.course` (direction of travel) over compass heading for vehicles

---

### DatabaseManager
**The Archivist**

`Managers/DatabaseManager.swift`

Owns the SQLite database file `flockfinder.sqlite` in the app's private Documents directory. All reads and writes go through this class — no other class touches the database directly.

```swift
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()  // Singleton — one database, one connection

    func insertDetection(_ detection: FlockDetection)
    func fetchDetections(limit: Int, offset: Int) -> [FlockDetection]
    func fetchDetectionsNear(latitude: Double, longitude: Double, radiusKm: Double) -> [FlockDetection]
    func exportToCSV() -> URL?
    func exportToGeoJSON() -> URL?
}
```

Key responsibilities:
- Creating the `detections` table and indexes on first run
- Inserting new detections (parameterised queries; no string interpolation)
- Fetching detections by time range, device type, or geography
- Exporting the full dataset to CSV or GeoJSON

---

### MotionManager *(deprecated)*
**The Speedometer**

`Managers/MotionManager.swift`

Originally used `CMMotionManager` and `CMMotionActivityManager` to classify movement (driving, walking, stationary) and improve heading accuracy. Now marked `@deprecated` — GPS course and speed from `LocationManager` are more reliable for vehicle use and eliminate the dependency on CoreMotion.

> **Status:** Retained for reference. Safe to delete if you want to reduce binary size and remove the `NSMotionUsageDescription` permission.

---

### AudioAlertManager
**The Alarm**

`Views/AudioAlertManager.swift`

A singleton that manages all audio and haptic output. Configured for CarPlay and external Bluetooth speakers so alerts play through your car stereo.

```swift
class AudioAlertManager: NSObject, ObservableObject {
    static let shared = AudioAlertManager()

    enum AlertSound: String, CaseIterable {
        case chime, bell, ping, alert, horn, sonar
    }

    func playDetectionAlert()
    func previewSound(_ sound: AlertSound)
}
```

Supported alert sounds use iOS system sound IDs — no bundled audio files required.

Key responsibilities:
- Configuring `AVAudioSession` for ambient + speaker output
- Playing the user-selected system sound on each detection
- Providing sound previews in the Settings UI

---

### DetectionCoordinator
**The Captain**

`Views/DetectionCoordinator.swift`

The only class that knows the *order* things must happen. Owns no data of its own — just wires the other managers together in response to BLE events.

```swift
class DetectionCoordinator: ObservableObject {
    init(
        bleManager: BLEManager,
        databaseManager: DatabaseManager,
        locationManager: LocationManager
    )
}
```

On every BLE detection:
1. Receives `DetectionData` via `bleManager.onDetection`
2. Calls `locationManager.getLocationData()` for current GPS
3. Constructs a `FlockDetection` model
4. Checks `confidence >= appSettings.minimumConfidence`
5. Calls `databaseManager.insertDetection(_:)`
6. Schedules `iCloudManager.shared.scheduleAutomaticBackup()`
7. Updates `bleManager.recentDetections` on the main thread
8. Triggers `audioManager.playDetectionAlert()` if enabled
9. Fires `triggerHapticFeedback()` if enabled

---

## Dependency Injection at App Start

`FlockFinderApp.swift` creates all managers once and injects them:

```swift
@main
struct FlockFinderApp: App {
    @StateObject private var bleManager: BLEManager
    @StateObject private var locationManager: LocationManager
    @StateObject private var databaseManager: DatabaseManager
    @StateObject private var detectionCoordinator: DetectionCoordinator

    init() {
        let ble = BLEManager()
        let loc = LocationManager()
        let db  = DatabaseManager.shared

        _bleManager        = StateObject(wrappedValue: ble)
        _locationManager   = StateObject(wrappedValue: loc)
        _databaseManager   = StateObject(wrappedValue: db)
        _detectionCoordinator = StateObject(
            wrappedValue: DetectionCoordinator(
                bleManager: ble,
                databaseManager: db,
                locationManager: loc
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(locationManager)
                .environmentObject(databaseManager)
                .environmentObject(detectionCoordinator)
        }
    }
}
```

All four objects are pushed into the SwiftUI environment, making them available to every view without prop-drilling.

---

## The UI Shell

`Views/ContentView.swift` is a four-tab `TabView`:

| Tab | View | Purpose |
|-----|------|---------|
| Scanner | `ScannerView` | BLE connection controls, recent detections, live status |
| Map | `MapView` | All saved detections as map pins |
| History | `HistoryView` | Scrollable detection log with filter/search |
| Settings | `SettingsView` | Confidence threshold, audio, iCloud, export |

---

## Communication Patterns

| Relationship | Mechanism |
|-------------|-----------|
| ESP32 → BLEManager | BLE characteristic notification (push) |
| BLEManager → DetectionCoordinator | `onDetection` closure callback |
| DetectionCoordinator → LocationManager | Direct method call (`getLocationData()`) |
| DetectionCoordinator → DatabaseManager | Direct method call (`insertDetection`) |
| Manager → SwiftUI view | `@Published` properties observed via `@EnvironmentObject` |
| Settings persistence | `AppSettings` backed by `UserDefaults` |

---

## What to Read Next

- [Bluetooth Protocol](./03-bluetooth.md) — how BLEManager connects and parses data
- [Database](./04-database.md) — how DatabaseManager stores and queries detections
- [Detection Journey](./01-detection-journey.md) — the full end-to-end data flow
