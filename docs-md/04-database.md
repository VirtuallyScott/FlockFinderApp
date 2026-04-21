# Database

> How FlockFinder stores thousands of detections permanently — without needing a server, an account, or a Wi-Fi connection.

---

## Why SQLite?

FlockFinder stores all data in **SQLite** — a self-contained database engine that lives in a single file on your iPhone. There is no server, no network connection, no account required. Apple ships SQLite3 with every iOS device; FlockFinder uses the C-level `sqlite3` bindings directly, with no third-party ORM.

The database file is created automatically on first launch:

```
/private/var/mobile/Containers/Data/Application/<UUID>/Documents/flockfinder.sqlite
```

You can access this file via Xcode's "Download Container" feature or the Files app (when the app declares the Documents folder as accessible).

---

## The Schema

```sql
CREATE TABLE IF NOT EXISTS detections (
    id                INTEGER  PRIMARY KEY AUTOINCREMENT,
    device_type       TEXT     NOT NULL,
    mac_address       TEXT,
    ssid              TEXT,
    rssi              INTEGER  NOT NULL,
    confidence        REAL     NOT NULL,
    latitude          REAL     NOT NULL,
    longitude         REAL     NOT NULL,
    altitude          REAL,
    accuracy          REAL,
    speed             REAL,
    heading           REAL,
    acceleration_x    REAL,
    acceleration_y    REAL,
    acceleration_z    REAL,
    activity_type     TEXT,
    timestamp         TEXT     NOT NULL,
    synced            INTEGER  DEFAULT 0
);
```

### Column reference

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER | Auto-incrementing primary key |
| `device_type` | TEXT | Raw value of `DeviceType` enum, e.g. `"Flock Safety"` |
| `mac_address` | TEXT | Hardware MAC from ESP32; nullable |
| `ssid` | TEXT | Wi-Fi network name; nullable |
| `rssi` | INTEGER | Signal strength in dBm |
| `confidence` | REAL | 0.0–1.0 match certainty from firmware |
| `latitude` | REAL | WGS-84 decimal degrees |
| `longitude` | REAL | WGS-84 decimal degrees |
| `altitude` | REAL | Metres above sea level |
| `accuracy` | REAL | Horizontal accuracy in metres |
| `speed` | REAL | Speed in m/s at time of detection |
| `heading` | REAL | Course in degrees (0 = north) |
| `acceleration_x/y/z` | REAL | Accelerometer values (legacy; populated as 0 now) |
| `activity_type` | TEXT | Motion classification string; nullable |
| `timestamp` | TEXT | ISO 8601 UTC string, e.g. `2025-04-21T14:32:01Z` |
| `synced` | INTEGER | 0 = not yet backed up to iCloud; 1 = synced |

### Indexes

Four indexes are created to make common queries fast:

```sql
CREATE INDEX IF NOT EXISTS idx_timestamp   ON detections(timestamp);
CREATE INDEX IF NOT EXISTS idx_device_type ON detections(device_type);
CREATE INDEX IF NOT EXISTS idx_synced      ON detections(synced);
CREATE INDEX IF NOT EXISTS idx_location    ON detections(latitude, longitude);
```

---

## DatabaseManager

`Managers/DatabaseManager.swift` owns the database connection. It is a singleton — one connection, shared across the app.

```swift
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()   // Singleton access
    @Published var lastInsertedId: Int64?   // Useful for confirming the last write
}
```

### Lifecycle

```
init()
  └─ openDatabase()    — opens flockfinder.sqlite (creates it if absent)
  └─ createTables()    — runs CREATE TABLE IF NOT EXISTS + CREATE INDEX IF NOT EXISTS

deinit
  └─ sqlite3_close(db) — closes the database connection cleanly
```

---

## Writing a Detection

All writes use **parameterised queries** — never string interpolation. This prevents SQL injection and handles special characters in SSIDs or MAC addresses correctly.

```swift
// Managers/DatabaseManager.swift

func insertDetection(_ detection: FlockDetection) {
    let sql = """
        INSERT INTO detections (
            device_type, mac_address, ssid, rssi, confidence,
            latitude, longitude, altitude, accuracy,
            speed, heading,
            acceleration_x, acceleration_y, acceleration_z,
            activity_type, timestamp, synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    var statement: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
        sqlite3_bind_text(statement, 1, detection.deviceType.rawValue, -1, nil)
        // ... bind remaining fields ...
        sqlite3_bind_text(statement, 16, ISO8601DateFormatter().string(from: detection.timestamp), -1, nil)
        sqlite3_bind_int(statement, 17, detection.synced ? 1 : 0)

        sqlite3_step(statement)
        lastInsertedId = sqlite3_last_insert_rowid(db)
    }
    sqlite3_finalize(statement)
}
```

---

## Reading Detections

### All detections (newest first)

```swift
func fetchAllDetections() -> [FlockDetection] {
    // SELECT * FROM detections ORDER BY timestamp DESC;
}
```

### Filtered by device type

```swift
func fetchDetections(byType type: DeviceType) -> [FlockDetection] {
    // SELECT * FROM detections WHERE device_type = ? ORDER BY timestamp DESC;
}
```

### Filtered by date range

```swift
func fetchDetections(from startDate: Date, to endDate: Date) -> [FlockDetection] {
    // SELECT * FROM detections WHERE timestamp BETWEEN ? AND ? ORDER BY timestamp DESC;
}
```

### Count only

```swift
func getDetectionCount() -> Int {
    // SELECT COUNT(*) FROM detections;
}
```

---

## Deleting Detections

```swift
// Delete one record by its primary key
func deleteDetection(id: Int64)

// Wipe all records (used by the "Clear All Data" option in Settings)
func clearAllDetections()
```

> **Warning:** `clearAllDetections()` is permanent and immediate. There is no undo. The iCloud backup is not affected — it retains whatever was last synced.

---

## Exports

### JSON

```swift
func exportToJSON() -> Data?
```

Returns a pretty-printed JSON array of all detections. Timestamps use ISO 8601 encoding. Suitable for import into mapping tools or custom analysis scripts.

### CSV

```swift
func exportToCSV() -> String
```

Returns a CSV string with this header row:

```
id,device_type,mac_address,ssid,rssi,confidence,latitude,longitude,altitude,accuracy,speed,heading,timestamp
```

One row per detection. Share via the system share sheet in `SettingsView`.

---

## Row Parsing

`parseDetectionRow(_:)` converts a raw SQLite statement row into a `FlockDetection` Swift struct by reading columns by index:

```swift
let id          = sqlite3_column_int64(statement, 0)
let deviceType  = String(cString: sqlite3_column_text(statement, 1))
let macAddress  = sqlite3_column_text(statement, 2).map { String(cString: $0) }
// ... columns 3-16 ...
let timestamp   = ISO8601DateFormatter().date(from: timestampString)
```

If the timestamp cannot be parsed, the row is silently skipped (returns `nil`). This prevents a single corrupted row from crashing a full fetch.

---

## iCloud Sync Column

The `synced` flag is managed by `iCloudManager`. After a successful backup:

```sql
UPDATE detections SET synced = 1 WHERE id IN (...);
```

This allows the app to send only new records on subsequent syncs rather than re-uploading the entire database every time.

---

## Using the Database Directly

You can inspect `flockfinder.sqlite` with any SQLite browser (e.g. [DB Browser for SQLite](https://sqlitebrowser.org/)):

```sql
-- Most recent 20 Flock Safety detections
SELECT timestamp, latitude, longitude, confidence, rssi
FROM detections
WHERE device_type = 'Flock Safety'
ORDER BY timestamp DESC
LIMIT 20;

-- Detection count by device type
SELECT device_type, COUNT(*) as count
FROM detections
GROUP BY device_type
ORDER BY count DESC;

-- Unsynced detections
SELECT * FROM detections WHERE synced = 0;
```

---

## Where to Find This Code

| Topic | File | Key method |
|-------|------|------------|
| Schema creation | `Managers/DatabaseManager.swift` | `createTables()` |
| Insert | `DatabaseManager.swift` | `insertDetection(_:)` |
| Fetch all | `DatabaseManager.swift` | `fetchAllDetections()` |
| Fetch by type | `DatabaseManager.swift` | `fetchDetections(byType:)` |
| Fetch by date | `DatabaseManager.swift` | `fetchDetections(from:to:)` |
| Count | `DatabaseManager.swift` | `getDetectionCount()` |
| Delete | `DatabaseManager.swift` | `deleteDetection(id:)` / `clearAllDetections()` |
| JSON export | `DatabaseManager.swift` | `exportToJSON()` |
| CSV export | `DatabaseManager.swift` | `exportToCSV()` |
| iCloud sync | `Views/iCloudManager.swift` | `scheduleAutomaticBackup()` |
