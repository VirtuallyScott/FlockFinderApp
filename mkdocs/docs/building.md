# Building FlockFinder

This guide covers building the FlockFinder iOS app from source code.

## Prerequisites

| Requirement | Version |
|-------------|---------|
| **macOS** | Ventura 13.0+ |
| **Xcode** | 15.0 or later |
| **iOS Device** | Physical device (BLE requires hardware) |
| **Apple Developer Account** | Free or paid membership |

!!! warning "Simulator Limitations"
    The iOS Simulator does not support Bluetooth Low Energy. You must build and run on a physical iOS device to test BLE functionality.

## Clone the Repository

```bash
git clone https://github.com/VirtuallyScott/FlockFinderApp.git
cd FlockFinderApp
```

## Open in Xcode

1. Open `FlockFinder.xcodeproj` in Xcode 15+
2. Wait for Swift Package Manager to resolve dependencies (if any)

## Configure Signing

1. Select the **FlockFinder** target in the project navigator
2. Go to the **Signing & Capabilities** tab
3. Select your **Team** from the dropdown
4. Xcode will automatically manage provisioning profiles

!!! tip "Free Developer Account"
    You can use a free Apple Developer account for personal testing. The app will need to be re-signed every 7 days.

## Build and Run

1. Connect your iOS device via USB or WiFi
2. Select your device from the device dropdown
3. Press `⌘R` or click the **Run** button
4. Trust the developer certificate on your device if prompted:
   - Go to **Settings > General > VPN & Device Management**
   - Tap your developer certificate and select **Trust**

## Build Configuration

### Debug Build

The default Debug configuration includes:

- Full logging output
- Debug stream view for raw BLE data
- Faster iteration with incremental builds

### Release Build

For distribution or optimized testing:

1. Select **Product > Scheme > Edit Scheme**
2. Change **Build Configuration** to **Release**
3. Build and archive: `⌘⇧A` or **Product > Archive**

## Troubleshooting

### Common Build Errors

#### "Signing requires a development team"

- Ensure you've selected a team in Signing & Capabilities
- Sign in to your Apple ID in Xcode Preferences > Accounts

#### "Untrusted Developer"

- On your iOS device: Settings > General > VPN & Device Management
- Trust your developer certificate

#### "No provisioning profiles found"

- Let Xcode manage signing automatically
- Or manually create profiles in the Apple Developer portal

### BLE Not Working

If Bluetooth features aren't working:

1. Ensure you're running on a **physical device**, not the simulator
2. Check that Bluetooth is enabled on your device
3. Verify the app has Bluetooth permissions in Settings
4. Try killing and restarting the app

## Project Structure

After building successfully, familiarize yourself with the [project architecture](architecture.md) to understand the codebase.

## Next Steps

- [Configure app permissions](permissions.md)
- [Understand the BLE protocol](ble-protocol.md)
- [Learn about detection types](detection-types.md)
