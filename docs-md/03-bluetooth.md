# Bluetooth Protocol

> How the ESP32 hardware "talks" to your iPhone — the invisible protocol that delivers every detection across the air.

---

## BLE vs Classic Bluetooth

Classic Bluetooth (speakers, headphones) streams data continuously — like a tap left running. **Bluetooth Low Energy (BLE)** is more like postal delivery: small, precisely addressed packets, only when there is something to say.

This is ideal for FlockFinder. The hardware only needs to send a short JSON message when it detects a camera. No need for a continuous audio stream — and the ESP32 stays powered for hours on a small battery.

---

## The Four-Step Connection Handshake

```
1. Advertise
   ESP32 broadcasts a BLE advertisement:
   "FlockFinder-S3 is here — here's my service UUID."
   Your iPhone sees it while scanning.

2. Connect
   iPhone establishes a private BLE connection.
   Moves from "I see you" to "let's talk."
   Only one device can be connected at a time.

3. Discover Services
   iPhone asks: "What can you do?"
   ESP32 responds with its service and characteristic list.
   iPhone finds the FlockFinder service by its UUID.

4. Subscribe to Notifications
   iPhone writes to the CCCD (Client Characteristic Configuration Descriptor)
   on the detection characteristic — telling the ESP32:
   "Push data to me whenever you find something."
   From this point the ESP32 sends detections without being asked.
```

---

## UUIDs: The Channel Numbers

Every BLE service and characteristic has a UUID — a 128-bit address that works like a radio channel. Both the iOS app and the ESP32 firmware must agree on the exact same UUIDs, or they cannot communicate.

FlockFinder uses three UUIDs defined in `BLEManager.swift`:

```swift
// Managers/BLEManager.swift

static let flockServiceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
static let detectionCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
static let commandCharacteristicUUID   = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a9")
static let streamCharacteristicUUID    = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26aa")
```

| UUID | Role |
|------|------|
| `flockServiceUUID` | The "FlockFinder station" — the parent service both devices must tune to |
| `detectionCharacteristicUUID` | The detection channel — ESP32 notifies when a camera is found |
| `commandCharacteristicUUID` | iOS → ESP32 control channel — send configuration or commands |
| `streamCharacteristicUUID` | Live scan stream — raw Wi-Fi scan data for the debug view |

> **ESP32 firmware note:** If you modify these UUIDs in the iOS app, you must change the matching values in the ESP32 firmware too. They are not negotiated automatically.

---

## Device Discovery: What Gets Scanned

`BLEManager` scans for any BLE device whose name matches one of these patterns (case-insensitive):

```swift
static let deviceNamePatterns = ["flockfinder", "flock", "feather", "esp32", "s3"]
```

It also looks for the `flockServiceUUID` in the advertisement data for a more reliable match. Devices are deduplicated by UUID and stored in `discoveredDevices` — a published array that drives the device picker in the Scanner tab UI.

---

## The Detection Payload

When the ESP32 finds a camera, it sends a UTF-8 encoded JSON string over the detection characteristic. Example payload:

```json
{
  "type": "Flock Safety",
  "mac": "AA:BB:CC:DD:EE:FF",
  "ssid": "FlockFS-12345",
  "rssi": -67,
  "confidence": 0.95
}
```

`BLEManager` parses this in `centralManager(_:didUpdateValueFor:)`:

```swift
// Managers/BLEManager.swift — simplified

func centralManager(_ central: CBCentralManager,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
    guard let data = characteristic.value,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return }

    let detection = DetectionData(from: json)
    onDetection?(detection)           // Fire the callback → DetectionCoordinator
    onRawData?(data, "detection")     // Also available for the debug stream view
}
```

### DetectionData struct

```swift
struct DetectionData: Codable, Identifiable {
    let id: UUID           // Generated locally on the iPhone; not from the ESP32
    let deviceType: String
    let macAddress: String?
    let ssid: String?
    let rssi: Int
    let confidence: Double
    let timestamp: Date
}
```

---

## Connection State Machine

`BLEManager` tracks its state through a `ConnectionState` enum:

```swift
enum ConnectionState: String {
    case disconnected  = "Disconnected"
    case scanning      = "Scanning..."
    case connecting    = "Connecting..."
    case connected     = "Connected"
    case discovering   = "Discovering Services..."
    case bluetoothOff  = "Bluetooth Off"
    case unauthorized  = "Bluetooth Unauthorized"
}
```

State transitions:

```
disconnected
    └─(startScanning)──► scanning
                             └─(device selected)──► connecting
                                                        └─(peripheral connected)──► discovering
                                                                                        └─(characteristics found)──► connected
                                                                                                                         └─(disconnect/error)──► disconnected
```

---

## RSSI Polling

Signal strength is not pushed by the ESP32 — it must be polled. `BLEManager` sets up a repeating timer after connecting:

```swift
rssiTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
    self.connectedDevice?.readRSSI()
}
```

The result arrives in `peripheral(_:didReadRSSI:error:)` and updates `@Published var rssi: Int`, which drives the signal bar in the Scanner UI.

---

## Strong Reference Management

CoreBluetooth peripherals are weakly held by the central manager. `BLEManager` keeps a strong reference dictionary to prevent unexpected deallocation during scanning:

```swift
private var peripheralReferences: [UUID: CBPeripheral] = [:]
// Populated in centralManager(_:didDiscover:advertisementData:rssi:)
// Cleared when scanning stops or a device connects
```

---

## Sending Commands to the ESP32

The `commandCharacteristicUUID` channel allows iOS to send instructions back to the hardware — for example, triggering a configuration reset or requesting a firmware version string. Writes use `CBCharacteristicWriteType.withResponse`:

```swift
func sendCommand(_ command: String) {
    guard let characteristic = commandCharacteristic,
          let data = command.data(using: .utf8)
    else { return }
    connectedDevice?.writeValue(data, for: characteristic, type: .withResponse)
}
```

---

## Where to Find This Code

| Topic | File | Key method/property |
|-------|------|---------------------|
| UUIDs | `Managers/BLEManager.swift` | Static UUID constants |
| Scanning | `BLEManager.swift` | `startScanning()` / `stopScanning()` |
| Connection | `BLEManager.swift` | `connect(to:)` |
| Parsing | `BLEManager.swift` | `centralManager(_:didUpdateValueFor:)` |
| State | `BLEManager.swift` | `ConnectionState` enum + `@Published connectionState` |
| Commands | `BLEManager.swift` | `sendCommand(_:)` |
| Debug stream | `Views/DebugStreamView.swift` | Subscribes to `onRawData` callback |
