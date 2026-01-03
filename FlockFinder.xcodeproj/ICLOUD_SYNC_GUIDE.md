# iCloud Sync Guide for FlockFinder

FlockFinder now supports comprehensive iCloud synchronization for both app settings and detection data.

## Overview

FlockFinder uses two different iCloud technologies:

1. **NSUbiquitousKeyValueStore** - For app settings (automatic, real-time)
2. **iCloud Drive** - For database backups (manual, on-demand)

## App Settings Sync

### What Gets Synced

All app settings are automatically synced across your devices:

- ✅ Auto-connect on launch
- ✅ Background scanning
- ✅ Notifications enabled
- ✅ Haptic feedback
- ✅ Minimum confidence threshold
- ✅ Crowdsource upload settings
- ✅ Data anonymization preference
- ✅ Map orientation mode
- ✅ Audio alert settings (enabled, sound, volume)

### How It Works

Settings sync uses **NSUbiquitousKeyValueStore**, which:

- Syncs automatically in the background
- Updates in near real-time (typically within seconds)
- Requires no user action
- Works across iPhone, iPad, and iPod touch
- Requires user to be signed into iCloud

### Implementation Details

The `AppSettings` class:

1. Saves every setting change to both local UserDefaults and iCloud
2. Listens for external changes from iCloud
3. Updates the UI automatically when changes arrive from other devices
4. Prevents sync loops using an internal flag

```swift
// Settings are synced on every change
@Published var autoConnect: Bool {
    didSet { 
        guard !isUpdatingFromCloud else { return }
        sync(Keys.autoConnect, value: autoConnect)
    }
}
```

### First Launch Behavior

When the app launches:

1. Loads settings from local UserDefaults
2. Performs an initial sync with iCloud after a short delay
3. If iCloud has newer values, they override local settings
4. Subsequent changes sync bidirectionally

### Limitations

NSUbiquitousKeyValueStore has the following limits:

- Maximum of 1024 keys
- Maximum of 1 MB total storage
- Individual values limited to 1 MB

These limits are far above what FlockFinder needs for settings.

## Database Backup Sync

### What Gets Backed Up

- Complete SQLite database containing all detection records
- Metadata about the backup (date, record count, file size)

### How It Works

Database backup uses **iCloud Drive**, which:

- Requires manual backup/restore actions
- Stores the full SQLite database file
- Provides version control and conflict resolution
- Works across all Apple platforms

### Using Database Backup

#### Backing Up

1. Open Settings
2. Scroll to "iCloud Backup" section
3. Tap "Backup to iCloud"
4. Wait for confirmation

#### Restoring

1. Open Settings
2. Scroll to "iCloud Backup" section
3. Tap "Restore from iCloud"
4. Confirm the action
5. Your current database is preserved as a backup before restore

### When to Use Database Backup

- Before upgrading to a new device
- As a safety backup before clearing data
- To sync detection history between devices
- To recover data after app reinstallation

## Requirements

### iCloud Requirements

- User must be signed into iCloud
- iCloud Drive must be enabled
- App must have iCloud permissions in Settings

### Info.plist Configuration

The app requires these entitlements:

```xml
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>

<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
```

### Xcode Project Configuration

1. Enable iCloud capability in project settings
2. Check "Key-value storage"
3. Check "iCloud Documents"

## Troubleshooting

### Settings Not Syncing

**Check:**
- User is signed into iCloud on all devices
- iCloud Drive is enabled in iOS Settings
- App has iCloud permission
- Device has internet connectivity

**Debug:**
- Check console logs for "☁️" prefixed messages
- Look for NSUbiquitousKeyValueStore notifications

### Database Backup Failing

**Check:**
- iCloud Drive has sufficient storage space
- User is signed into iCloud
- iCloud Drive is enabled for the app
- App has document folder permissions

**Debug:**
- Check `iCloudManager.backupError` for error messages
- Verify `iCloudManager.isICloudAvailable` is true

### Sync Conflicts

Settings sync automatically resolves conflicts by using the most recent change. Database backups are timestamped, allowing users to choose which version to restore.

## Privacy Considerations

### Settings Sync
- Settings are synced to Apple's iCloud servers
- Data is encrypted in transit and at rest
- Only accessible by the user's iCloud account

### Database Backup
- Detection data may contain location information
- Users can enable "Anonymize location data" in settings
- Backups are stored in the user's private iCloud Drive
- Only accessible by the user's iCloud account

## Testing

### Testing Settings Sync

1. Change a setting on Device A
2. Wait 5-10 seconds
3. Launch app on Device B
4. Verify setting has synced

### Testing Database Backup

1. Create some detections
2. Backup to iCloud
3. Clear all data locally
4. Restore from iCloud
5. Verify detections are restored

### Testing Without Multiple Devices

You can test using the simulator:
1. Use different simulator instances
2. Sign into the same iCloud account
3. Settings should sync between simulators
4. Note: Database backup may not work fully in simulator

## Code References

- **Settings Sync**: `AppSettings.swift`
- **Database Backup**: `iCloudManager.swift`
- **Settings UI**: `SettingsView.swift`

## Best Practices

1. **Never** store sensitive authentication tokens in synced settings
2. **Always** provide UI feedback during backup/restore operations
3. **Test** on actual devices, not just simulators
4. **Handle** iCloud being unavailable gracefully
5. **Log** sync operations for debugging

## Future Enhancements

Potential improvements:

- CloudKit integration for crowdsource database
- Automatic periodic backups
- Backup scheduling options
- Multiple backup versions
- Export backups outside iCloud
