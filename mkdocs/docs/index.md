# FlockFinder iOS App

<div style="text-align: center;">
    <img src="assets/icon.png" alt="FlockFinder Icon" width="128" />
</div>

A companion iOS application for the **FlockFinder ESP32-S3** surveillance camera detection system. This app connects to your FlockFinder hardware device via Bluetooth Low Energy (BLE) and provides real-time detection alerts, GPS logging, and comprehensive detection history.

!!! info "Firmware"
    This app is configured to work with [flock-you](https://github.com/VirtuallyScott/flock-you), a fork of the original flock-you project with BLE GATT server support.

## What is FlockFinder?

FlockFinder is a surveillance awareness project that helps you identify and log encounters with various surveillance camera systems, including:

- **Flock Safety** - Automated License Plate Recognition (ALPR) cameras used by law enforcement
- **Verkada** - Enterprise security camera platforms
- **Ring/Nest/Arlo** - Consumer smart home cameras
- **Commercial Systems** - Hikvision, Dahua, Axis, Lorex, and more

## Key Features

| Feature | Description |
|---------|-------------|
| **BLE Connectivity** | Seamlessly connects to your FlockFinder ESP32-S3 device |
| **GPS Logging** | Records precise coordinates for each detection |
| **Motion Tracking** | Captures speed, heading, and activity type |
| **Local Storage** | SQLite database with optional iCloud sync |
| **Interactive Map** | Visualize detection locations with clustering |
| **Detection History** | Browse, search, and filter past detections |
| **Data Export** | Export to CSV, JSON, or GPX formats |

## Requirements

- **iOS 16.0** or later
- iPhone with **Bluetooth 4.0+** and GPS
- FlockFinder ESP32 device with BLE broadcast firmware

## Quick Start

1. [Build the app](building.md) from source in Xcode
2. [Configure permissions](permissions.md) for Bluetooth and Location
3. [Connect to your device](ble-protocol.md) via the Scanner tab
4. Start detecting surveillance cameras!

## Documentation Sections

<div class="grid cards" markdown>

-   :material-hammer-wrench:{ .lg .middle } **Building**

    ---

    Build and run the app from source code

    [:octicons-arrow-right-24: Build Guide](building.md)

-   :material-bluetooth:{ .lg .middle } **BLE Protocol**

    ---

    Communication protocol with ESP32 device

    [:octicons-arrow-right-24: BLE Protocol](ble-protocol.md)

-   :material-folder-outline:{ .lg .middle } **Architecture**

    ---

    Project structure and code organization

    [:octicons-arrow-right-24: Architecture](architecture.md)

-   :material-camera-iris:{ .lg .middle } **Detection Types**

    ---

    Supported surveillance camera systems

    [:octicons-arrow-right-24: Detection Types](detection-types.md)

</div>

## Privacy

- All detection data is stored **locally on device**
- Optional iCloud sync for personal backup
- No data sent to external servers without explicit consent
- Location data can be anonymized for crowdsourcing

## License

This app is part of the FlockFinder surveillance awareness project.

---

*Built with SwiftUI for iOS 16+*
