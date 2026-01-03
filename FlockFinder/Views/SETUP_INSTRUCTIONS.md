# FlockFinder - Setup Instructions

## Features Added

### 1. Map Orientation Toggle (North Up / Heading Up)
- **Location**: MapView - Floating button with arrow icon
- **Functionality**: Toggle between north-up (fixed orientation) and heading-up (rotates with direction of travel)
- **Persistence**: Setting is saved to UserDefaults and synced to iCloud
- **Icon Changes**: Blue when in North mode, Green when in Heading mode

### 2. Audible Alerts
- **Location**: SettingsView > Audio Alerts section
- **Features**:
  - Enable/disable audible alerts for Flock device detections
  - Choose from 6 different alert sounds (Chime, Bell, Ping, Alert, Horn, Sonar)
  - Volume slider with mute capability (0-100%)
  - Test button to preview the selected sound
  - Automatic detection of CarPlay and Bluetooth connections
- **Audio Output**: Works with iPhone speakers, CarPlay, and Bluetooth audio systems
- **Persistence**: All settings saved to UserDefaults and synced to iCloud

### 3. Settings Persistence with iCloud Sync
- **Implementation**: New `AppSettings` class with `NSUbiquitousKeyValueStore` integration
- **Settings Synced**:
  - Auto-connect
  - Background scanning
  - Notifications enabled
  - Haptic feedback
  - Minimum confidence threshold
  - Upload to crowdsource
  - Anonymize data
  - Map orientation mode
  - Audible alerts enabled
  - Alert sound name
  - Alert volume
- **Benefits**: Settings automatically sync across all user devices logged into the same iCloud account

## Required Xcode Configuration

### 1. Enable iCloud Capability

1. Open your project in Xcode
2. Select the **FlockFinder** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **iCloud**
6. Under iCloud, check **Key-value storage**

### 2. Background Audio (for CarPlay/Bluetooth alerts)

1. In the **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **Background Modes**
4. Check **Audio, AirPlay, and Picture in Picture**

### 3. Info.plist Entries

Your Info.plist should already have location permissions. Verify these keys exist:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>FlockFinder needs your location to tag detected surveillance devices with GPS coordinates.</string>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>FlockFinder uses Bluetooth to connect to your ESP32 FlockFinder device for real-time detection scanning.</string>
```

## New Files Created

1. **AppSettings.swift** - Centralized settings manager with iCloud sync
2. **AudioAlertManager.swift** - Audio playback for detection alerts
3. **DetectionCoordinator.swift** - Coordinates detection handling (save, alert, haptic)
4. **SETUP_INSTRUCTIONS.md** - This file

## Modified Files

1. **MapView.swift** - Added map orientation toggle and rotation functionality
2. **SettingsView.swift** - Added Map and Audio Alerts sections, migrated to AppSettings
3. **FlockFinderApp.swift** - Integrated DetectionCoordinator

## Usage

### Map Orientation
1. Open the Map tab
2. Look for the floating button panel on the right side
3. The top button (arrow icon) toggles orientation:
   - **Blue arrow up** = North-up mode (map doesn't rotate)
   - **Green compass arrow** = Heading-up mode (map rotates with travel direction)

### Audio Alerts
1. Go to Settings tab
2. Scroll to "Audio Alerts" section
3. Toggle "Audible Alerts" on
4. Select your preferred alert sound from the picker
5. Adjust volume using the slider
6. Tap "Test Alert Sound" to preview
7. The setting shows if you're connected to CarPlay or Bluetooth

### Alert Behavior
- Alerts play automatically when a Flock device is detected
- Only plays if detection confidence meets the minimum threshold
- Works simultaneously with haptic feedback and notifications
- Audio routes to CarPlay, Bluetooth, or iPhone speaker automatically

## Testing

### Map Orientation
1. Connect to your FlockFinder device
2. Start driving (or use simulator with location simulation)
3. Toggle between North and Heading modes
4. In Heading mode, the map should rotate as you change direction

### Audio Alerts
1. Enable audible alerts in Settings
2. Choose a sound and set volume > 0
3. Tap "Test Alert Sound" to hear it
4. Connect to a FlockFinder device
5. Trigger a detection (or simulate with debug stream)
6. The alert should play through your selected audio output

### CarPlay Testing
1. Connect iPhone to CarPlay (real or simulator)
2. Enable audible alerts
3. Trigger a detection
4. Alert should play through car speakers
5. Settings should show "Connected to CarPlay"

## Troubleshooting

### iCloud Sync Not Working
- Ensure you're signed into iCloud on the device
- Check that the iCloud capability is enabled in Xcode
- Settings should sync within a few seconds between devices
- Check console for "☁️ Synced..." messages

### Audio Not Playing
- Check that "Audible Alerts" is enabled in Settings
- Ensure volume is > 0 (not muted)
- Verify that device volume is not at 0
- Check that Do Not Disturb is not enabled
- Try the "Test Alert Sound" button first

### Map Not Rotating
- Ensure you selected "Heading Up" mode (green icon)
- Check that you're moving (GPS must provide course/heading)
- Stationary devices won't rotate (no heading data)
- Heading requires device movement at walking/driving speed

### Detection Not Saving
- Check that DetectionCoordinator is initialized in FlockFinderApp
- Verify location permissions are granted
- Check minimum confidence threshold in Settings
- Look for "💾 Detection saved to database" in console logs

## Architecture Notes

### AppSettings
- Singleton pattern with `shared` instance
- Uses Combine's `@Published` for SwiftUI reactivity
- Dual-storage: UserDefaults (local) + NSUbiquitousKeyValueStore (iCloud)
- Observes `NSUbiquitousKeyValueStore.didChangeExternallyNotification` for remote changes

### AudioAlertManager
- Singleton pattern with `shared` instance
- Uses `AVAudioSession` with `.playback` category
- `.mixWithOthers` and `.duckOthers` options for car audio compatibility
- System sounds via `AudioServicesPlaySystemSound` for reliability

### DetectionCoordinator
- Lifecycle managed by FlockFinderApp
- Sets `bleManager.onDetection` callback
- Handles detection flow: save → alert → haptic → notification
- Checks confidence threshold before processing

## Future Enhancements

- [ ] Push notifications for detections (requires notification permission)
- [ ] Custom audio file support (user-provided sounds)
- [ ] Map clustering for high-density detection areas
- [ ] 3D map view option
- [ ] Export settings configuration
- [ ] Alert cooldown period (avoid alert spam)
- [ ] Different alert sounds for different device types
- [ ] Speech synthesis for detection announcements

## Questions or Issues

If you encounter any issues:
1. Check Xcode console for log messages
2. Verify all capabilities are enabled
3. Ensure Info.plist entries are correct
4. Try clean build (⇧⌘K then ⌘B)
5. Check that all new files are included in the target
