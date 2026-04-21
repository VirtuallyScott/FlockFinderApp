# Permissions

> Why iOS makes your app ask for access — how the permission system works, what each key means, and what happens when a user says no.

---

## The iOS Permission Model

Every sensitive hardware feature on an iPhone — GPS, Bluetooth, microphone, motion sensors — is guarded by a user-controlled permission gate. No app gets through without explicit user approval. After approval, users can revoke access at any time in **Settings → Privacy & Security**.

FlockFinder requires three categories of hardware access:

| Permission | Required? | What breaks without it |
|------------|-----------|------------------------|
| **Bluetooth** | Essential | Cannot scan for or connect to the ESP32; no detections at all |
| **Location (When In Use)** | Essential | Cannot tag detections with GPS coordinates |
| **Motion & Fitness** | Optional | Activity type column in database is left empty |

---

## Info.plist Permission Keys

iOS requires every app to declare *why* it needs each permission. These descriptions live in `Info.plist` — Apple reviews them during App Store submission, and the strings appear verbatim in the permission dialog shown to the user.

### Bluetooth

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>FlockFinder needs Bluetooth to connect to your FlockFinder ESP32 device
and receive surveillance camera detection alerts.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>FlockFinder needs Bluetooth to connect to your FlockFinder ESP32 device.</string>
```

`NSBluetoothAlwaysUsageDescription` is required for any BLE use on iOS 13+, even if you only need foreground access. The legacy `NSBluetoothPeripheralUsageDescription` key is kept for compatibility with iOS 12 and older devices.

### Location

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>FlockFinder needs your location to log where surveillance cameras
are detected, helping you track and map these devices.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>FlockFinder needs background location access to continue logging
detection locations while the app is in the background.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>FlockFinder needs background location access to continue logging
detection locations while the app is in the background.</string>
```

`NSLocationWhenInUseUsageDescription` covers the standard foreground use case. The "Always" variants are required if background location is enabled — they require an additional prompt and Apple justification.

### Motion

```xml
<key>NSMotionUsageDescription</key>
<string>FlockFinder uses motion data to record your direction of travel
and activity type when a surveillance camera is detected.</string>
```

Used by `MotionManager`. Since `MotionManager` is now deprecated, this key can be removed if you delete that file.

---

## Background Modes

FlockFinder declares two background modes in `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>location</string>
</array>
```

| Mode | Effect |
|------|--------|
| `bluetooth-central` | Keeps the BLE central manager active when the app moves to the background; detections continue to arrive |
| `location` | Allows `CLLocationManager` to deliver updates in the background |

> **App Store review note:** Background location requires explicit justification in the App Store submission. Apple looks for apps that show a clear user benefit for background location versus apps that collect it silently.

---

## Required Device Capabilities

```xml
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>bluetooth-le</string>
    <string>location-services</string>
    <string>accelerometer</string>
    <string>gps</string>
    <string>armv7</string>
</array>
```

These entries tell the App Store to hide the app from devices that lack the required hardware. A device without Bluetooth LE cannot use FlockFinder at all, so it is correctly excluded.

---

## Requesting Location in Code

`LocationManager` guards against calling GPS APIs before permission is granted:

```swift
// Managers/LocationManager.swift

func startTracking() {
    guard authorizationStatus == .authorizedWhenInUse ||
          authorizationStatus == .authorizedAlways else {
        requestAuthorization()   // Shows the iOS permission dialog
        return                   // Stop here — cannot start GPS without permission
    }

    locationManager.startUpdatingLocation()
    locationManager.startUpdatingHeading()
}
```

The `authorizationStatus` is a `@Published` property. When it changes (user taps Allow or Deny in the system dialog), any SwiftUI view observing `LocationManager` is automatically re-rendered.

---

## The Missing Plist Key Crash

If an app calls a permission API without the matching `Info.plist` key, **iOS immediately terminates the app** with a fatal error — there is no graceful fallback. `LocationManager` includes a proactive guard to make this failure obvious during development:

```swift
// Managers/LocationManager.swift — requestAuthorization()

if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") == nil {
    print("❌ ERROR: Missing 'NSLocationWhenInUseUsageDescription' in Info.plist!")
    print("❌ Add this to Info.plist:")
    print("   Key: Privacy - Location When In Use Usage Description")
    print("   Value: FlockFinder needs your location to tag detected surveillance devices.")
}
```

If you see a hard crash on `CLLocationManager.requestWhenInUseAuthorization()`, check `Info.plist` first.

---

## What Happens When a User Denies Permission

| Permission denied | Effect | Recovery |
|------------------|--------|----------|
| Bluetooth | `connectionState` → `.unauthorized`; scanning is disabled | User must go to Settings → Privacy → Bluetooth |
| Location | `authorizationStatus` → `.denied`; GPS coordinates recorded as 0,0 | User must go to Settings → Privacy → Location Services |
| Motion | Activity type not recorded; no crash | No user action needed — it is optional |

The app does not repeatedly re-request permissions once denied. It shows an appropriate status message and stays functional for whatever permissions were granted.

---

## Entitlements

`Views/FlockFinder.entitlements` declares the iCloud container for backup:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.virtuallyscott.flockfinder</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)com.virtuallyscott.flockfinder</string>
```

iCloud access requires a matching capability enabled in the Xcode project and in the Apple Developer portal. See [iCloud Setup Guide](../FlockFinder/Views/iCloud_Setup_Guide.md) for step-by-step instructions.

---

## Permission Checklist for a New Build

- [ ] `NSBluetoothAlwaysUsageDescription` present in `Info.plist`
- [ ] `NSLocationWhenInUseUsageDescription` present in `Info.plist`
- [ ] `UIBackgroundModes` includes `bluetooth-central` and `location`
- [ ] `UIRequiredDeviceCapabilities` lists `bluetooth-le` and `gps`
- [ ] iCloud container identifier matches the Apple Developer portal
- [ ] Running on a physical device (BLE and GPS do not work in the Simulator)

---

## Where to Find This Code

| Topic | File |
|-------|------|
| Permission descriptions | `FlockFinder/Info.plist` |
| Background modes | `FlockFinder/Info.plist` → `UIBackgroundModes` |
| Location request | `Managers/LocationManager.swift` → `requestAuthorization()` |
| Bluetooth state handling | `Managers/BLEManager.swift` → `centralManagerDidUpdateState(_:)` |
| iCloud entitlements | `Views/FlockFinder.entitlements` |
| iCloud setup guide | `Views/iCloud_Setup_Guide.md` |
