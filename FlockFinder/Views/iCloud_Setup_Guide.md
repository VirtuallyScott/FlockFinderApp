# iCloud Backup & Sync - Setup Guide

## ✅ What's Now Implemented

### Two Types of iCloud Storage:

1. **iCloud Key-Value Store** (for app settings)
   - Automatically syncs small preferences across devices
   - Already working - no user action needed
   - Settings like audio alerts, map orientation, etc.

2. **iCloud Drive** (for database backup)
   - Manual and automatic backup of detection database
   - New section added to Settings > iCloud Backup
   - Backs up the complete SQLite database

## 📱 iCloud Backup Section in Settings

The new **iCloud Backup** section in Settings includes:

- **iCloud Status**: Shows if iCloud is available
- **Last Backup**: Timestamp and file size of last backup
- **Backup to iCloud**: Manual backup button
- **Restore from iCloud**: Restore database from backup
- **Automatic Backup**: Happens automatically after detections (max once per hour)

## ⚙️ Required Xcode Configuration

### 1. Enable iCloud Capability

**Steps:**
1. Open your project in Xcode
2. Select the **FlockFinder** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **iCloud**
6. Under iCloud Services, check **BOTH**:
   - ☑️ **Key-value storage** (for settings sync)
   - ☑️ **iCloud Documents** (for database backup)

### 2. Configure iCloud Container (Important!)

After enabling iCloud Documents:
1. Xcode should create a default container
2. The container identifier will be like: `iCloud.com.yourteam.FlockFinder`
3. Make sure it's checked/selected in the iCloud capability section

### 3. Entitlements File

Xcode should automatically create or update your `.entitlements` file with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- iCloud Key-Value Storage (Settings) -->
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
    
    <!-- iCloud Documents (Database Backup) -->
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.$(CFBundleIdentifier)</string>
    </array>
    
    <!-- Background Audio for CarPlay/Bluetooth Alerts -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
</dict>
</plist>
```

**Note**: Xcode fills in `$(TeamIdentifierPrefix)` and `$(CFBundleIdentifier)` automatically.

### 4. Test on Device (Not Simulator)

⚠️ **Important**: iCloud features require:
- Real iOS device (simulator has limited iCloud support)
- Signed in to iCloud in Settings app
- iCloud Drive enabled for the app

## 📖 Usage Guide

### How to Backup Database to iCloud

1. Open FlockFinder app
2. Go to **Settings** tab
3. Scroll to **iCloud Backup** section
4. Check that iCloud Status shows "Available" ✅
5. Tap **Backup to iCloud** button
6. Wait for "Last Backup" to update with current time

**Automatic Backup:**
- Happens automatically after detections are saved
- Limited to once per hour to avoid excessive syncing
- Runs in background, you don't need to do anything

### How to Restore Database from iCloud

⚠️ **Warning**: This replaces your current database!

1. Go to **Settings** > **iCloud Backup**
2. Check "Last Backup" to see when backup was created
3. Tap **Restore from iCloud**
4. Confirm the alert
5. Your current database is saved as `.pre-restore` backup
6. Database is restored from iCloud
7. App reloads data automatically

**Use cases for restore:**
- New device setup
- After reinstalling app
- Recovered from accidental data deletion
- Syncing data from another device

## 🔧 Files Created/Modified

### New Files:
- **iCloudManager.swift**: Manages database backup/restore to iCloud Drive

### Modified Files:
- **SettingsView.swift**: Added iCloud Backup section with controls
- **DetectionCoordinator.swift**: Calls automatic backup after saving detections

## 🎯 What Gets Backed Up

### Settings (Auto-sync via Key-Value Store):
- ✅ Map orientation preference
- ✅ Audio alert settings (enabled, sound, volume)
- ✅ All scanning preferences
- ✅ Notification settings
- ✅ Crowdsource preferences
- **Syncs**: Instantly, automatically across all devices

### Database (Manual + Auto backup via iCloud Drive):
- ✅ Complete SQLite database file
- ✅ All detection records
- ✅ WAL and SHM files (SQLite transaction logs)
- ✅ Backup metadata (timestamp, record count, size)
- **Backup**: Manual button or automatic (once per hour max)
- **Storage location**: `iCloud Drive/FlockFinder/Documents/`

## 🐛 Troubleshooting

### "iCloud Not Available" Message

**Check these:**
1. ✅ Signed into iCloud account in iOS Settings
2. ✅ iCloud Drive is turned ON in iOS Settings
3. ✅ FlockFinder is allowed to use iCloud Drive (Settings > Apple ID > iCloud > Manage Storage > FlockFinder)
4. ✅ Internet connection available
5. ✅ Running on real device (not simulator)

### Backup Button Grayed Out

**Possible reasons:**
- No detections in database (nothing to backup)
- iCloud not available (see above)
- Currently backing up (wait for it to complete)

### Restore Button Grayed Out

**Possible reasons:**
- No backup exists in iCloud yet
- iCloud not available
- Currently restoring (wait for it to complete)

### "Failed to Backup" Error

**Solutions:**
1. Check iCloud storage space (Settings > Apple ID > iCloud)
2. Ensure app has iCloud Drive permission
3. Try signing out and back into iCloud
4. Check console logs for specific error

### Backup Not Syncing to Other Device

**Wait time:**
- iCloud Drive can take a few minutes to sync
- On cellular, syncing may be slower or paused
- Connect to WiFi for faster sync

**Force sync:**
1. Tap "Backup to iCloud" on first device
2. Wait 1-2 minutes
3. On second device, go to Settings > iCloud Backup
4. Tap "Restore from iCloud" (checks for latest backup)

## 💡 Best Practices

### When to Backup Manually:
- Before deleting the app
- Before device upgrade/replacement
- After collecting many detections
- Before clearing all data
- Periodically for peace of mind

### When to Restore:
- New device setup
- After app reinstall
- To sync data from another device
- After accidental data loss

### Storage Management:
- Database backup size depends on detection count
- Typical: 1,000 detections ≈ 100-200 KB
- iCloud free tier: 5 GB (plenty for detection data)
- Settings sync uses minimal storage (< 1 KB)

## 🔒 Privacy & Security

- **iCloud Encryption**: All data encrypted in transit and at rest
- **Apple Security**: Uses your iCloud account's security
- **No Third Party**: Data only goes to Apple's iCloud
- **Local First**: App works fully offline, iCloud is backup only
- **User Control**: You control when to backup/restore

## 📝 Console Logging

Look for these messages:
- `☁️ iCloudManager initialized`
- `☁️ iCloud available: true/false`
- `☁️ Backup completed: X detections, Y KB`
- `☁️ Restore completed`
- `☁️ Synced [setting] = [value]` (settings sync)

## 🚀 Next Steps

1. Enable iCloud capability in Xcode (both Key-Value and Documents)
2. Build and run on real device signed into iCloud
3. Check Settings > iCloud Backup section
4. Verify iCloud Status shows "Available"
5. Add some detections by scanning
6. Test backup with "Backup to iCloud" button
7. Check "Last Backup" updates
8. Optional: Test restore on another device

## 📚 Technical Details

### Architecture:
- **Singleton Pattern**: `iCloudManager.shared` for global access
- **Async Operations**: All backup/restore runs on background queue
- **File Coordination**: Uses FileManager with iCloud container URLs
- **Metadata Tracking**: JSON file with backup info
- **Safety**: Pre-restore backup prevents data loss

### Storage Paths:
- **Local DB**: `Documents/flockfinder.sqlite`
- **iCloud DB**: `iCloud Drive/Documents/flockfinder_backup.sqlite`
- **Metadata**: `iCloud Drive/Documents/backup_metadata.json`

### Automatic Backup Throttling:
```swift
// Only backs up if:
// 1. iCloud is available
// 2. Last backup was > 1 hour ago
// 3. New detections were saved
```

This prevents excessive iCloud API calls and respects rate limits.

---

**Questions or issues?** Check the console logs and ensure all Xcode capabilities are properly configured!
