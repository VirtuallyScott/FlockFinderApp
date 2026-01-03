import Foundation
import SwiftUI
import Combine

/// Centralized app settings manager with iCloud sync support
class AppSettings: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = AppSettings()
    
    // MARK: - iCloud Key-Value Store
    private let cloudStore = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Keys
    private enum Keys {
        static let autoConnect = "autoConnect"
        static let backgroundScanning = "backgroundScanning"
        static let notificationsEnabled = "notificationsEnabled"
        static let hapticFeedback = "hapticFeedback"
        static let minimumConfidence = "minimumConfidence"
        static let uploadToCrowdsource = "uploadToCrowdsource"
        static let anonymizeData = "anonymizeData"
        
        // Map settings
        static let mapOrientationMode = "mapOrientationMode"
        
        // Audio alert settings
        static let audibleAlertsEnabled = "audibleAlertsEnabled"
        static let alertSoundName = "alertSoundName"
        static let alertVolume = "alertVolume"
        
        // iCloud sync control (stored locally only, not synced)
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
    }
    
    // MARK: - Map Orientation Mode
    enum MapOrientationMode: String, CaseIterable, Codable {
        case north = "North Up"
        case heading = "Heading Up"
        
        var icon: String {
            switch self {
            case .north: return "arrow.up.circle"
            case .heading: return "location.north.line"
            }
        }
        
        var description: String {
            switch self {
            case .north: return "Map always oriented to true north"
            case .heading: return "Map rotates with direction of travel"
            }
        }
    }
    
    // MARK: - Private Properties
    
    /// Flag to prevent sync loops when updating from iCloud
    private var isUpdatingFromCloud = false
    
    // MARK: - Published Properties
    
    // Existing settings
    @Published var autoConnect: Bool {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.autoConnect, value: autoConnect)
        }
    }
    
    @Published var backgroundScanning: Bool {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.backgroundScanning, value: backgroundScanning)
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.notificationsEnabled, value: notificationsEnabled)
        }
    }
    
    @Published var hapticFeedback: Bool {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.hapticFeedback, value: hapticFeedback)
        }
    }
    
    @Published var minimumConfidence: Double {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.minimumConfidence, value: minimumConfidence)
        }
    }
    
    @Published var uploadToCrowdsource: Bool {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.uploadToCrowdsource, value: uploadToCrowdsource)
        }
    }
    
    @Published var anonymizeData: Bool {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.anonymizeData, value: anonymizeData)
        }
    }
    
    // Map settings
    @Published var mapOrientationMode: MapOrientationMode {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.mapOrientationMode, value: mapOrientationMode.rawValue)
        }
    }
    
    // Audio alert settings
    @Published var audibleAlertsEnabled: Bool {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.audibleAlertsEnabled, value: audibleAlertsEnabled)
        }
    }
    
    @Published var alertSoundName: String {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.alertSoundName, value: alertSoundName)
        }
    }
    
    @Published var alertVolume: Double {
        didSet { 
            guard !isUpdatingFromCloud else { return }
            sync(Keys.alertVolume, value: alertVolume)
        }
    }
    
    // iCloud sync control (stored locally only)
    @Published var iCloudSyncEnabled: Bool {
        didSet {
            // Store locally only (never sync this setting)
            UserDefaults.standard.set(iCloudSyncEnabled, forKey: Keys.iCloudSyncEnabled)
            
            if iCloudSyncEnabled {
                // When enabling, push all current settings to iCloud
                pushAllSettingsToCloud()
                print("☁️ iCloud sync enabled - pushing all settings")
            } else {
                print("☁️ iCloud sync disabled - settings will remain local only")
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Load iCloud sync preference first (local only, default true)
        self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: Keys.iCloudSyncEnabled, defaultValue: true)
        
        // Load from UserDefaults (local storage)
        self.autoConnect = UserDefaults.standard.bool(forKey: Keys.autoConnect, defaultValue: true)
        self.backgroundScanning = UserDefaults.standard.bool(forKey: Keys.backgroundScanning, defaultValue: false)
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: Keys.notificationsEnabled, defaultValue: true)
        self.hapticFeedback = UserDefaults.standard.bool(forKey: Keys.hapticFeedback, defaultValue: true)
        self.minimumConfidence = UserDefaults.standard.double(forKey: Keys.minimumConfidence, defaultValue: 0.5)
        self.uploadToCrowdsource = UserDefaults.standard.bool(forKey: Keys.uploadToCrowdsource, defaultValue: false)
        self.anonymizeData = UserDefaults.standard.bool(forKey: Keys.anonymizeData, defaultValue: true)
        
        // Map settings
        let orientationRawValue = UserDefaults.standard.string(forKey: Keys.mapOrientationMode) ?? MapOrientationMode.north.rawValue
        self.mapOrientationMode = MapOrientationMode(rawValue: orientationRawValue) ?? .north
        
        // Audio alert settings
        self.audibleAlertsEnabled = UserDefaults.standard.bool(forKey: Keys.audibleAlertsEnabled, defaultValue: true)
        self.alertSoundName = UserDefaults.standard.string(forKey: Keys.alertSoundName) ?? "chime"
        self.alertVolume = UserDefaults.standard.double(forKey: Keys.alertVolume, defaultValue: 0.7)
        
        // Only set up iCloud sync if enabled
        if iCloudSyncEnabled {
            // Observe iCloud changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCloudUpdate),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: cloudStore
            )
            
            // Start synchronizing with iCloud
            cloudStore.synchronize()
            
            // Perform initial sync from iCloud (in case this device has older data)
            performInitialCloudSync()
            
            print("⚙️ AppSettings initialized with iCloud sync enabled")
        } else {
            print("⚙️ AppSettings initialized with iCloud sync disabled")
        }
    }
    
    // MARK: - Initial Cloud Sync
    
    /// Perform an initial sync from iCloud to get the latest settings
    private func performInitialCloudSync() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Check if iCloud has values and update if they're different
            let allKeys = [
                Keys.autoConnect,
                Keys.backgroundScanning,
                Keys.notificationsEnabled,
                Keys.hapticFeedback,
                Keys.minimumConfidence,
                Keys.uploadToCrowdsource,
                Keys.anonymizeData,
                Keys.mapOrientationMode,
                Keys.audibleAlertsEnabled,
                Keys.alertSoundName,
                Keys.alertVolume
            ]
            
            for key in allKeys {
                if self.cloudStore.object(forKey: key) != nil {
                    self.updateFromCloud(key: key)
                }
            }
            
            print("☁️ Initial iCloud sync completed")
        }
    }
    
    // MARK: - Sync Methods
    
    /// Push all settings to iCloud (used when enabling sync)
    private func pushAllSettingsToCloud() {
        cloudStore.set(autoConnect, forKey: Keys.autoConnect)
        cloudStore.set(backgroundScanning, forKey: Keys.backgroundScanning)
        cloudStore.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        cloudStore.set(hapticFeedback, forKey: Keys.hapticFeedback)
        cloudStore.set(minimumConfidence, forKey: Keys.minimumConfidence)
        cloudStore.set(uploadToCrowdsource, forKey: Keys.uploadToCrowdsource)
        cloudStore.set(anonymizeData, forKey: Keys.anonymizeData)
        cloudStore.set(mapOrientationMode.rawValue, forKey: Keys.mapOrientationMode)
        cloudStore.set(audibleAlertsEnabled, forKey: Keys.audibleAlertsEnabled)
        cloudStore.set(alertSoundName, forKey: Keys.alertSoundName)
        cloudStore.set(alertVolume, forKey: Keys.alertVolume)
        cloudStore.synchronize()
    }
    
    /// Synchronize a setting to both UserDefaults and iCloud
    private func sync(_ key: String, value: Any) {
        // Save to UserDefaults
        UserDefaults.standard.set(value, forKey: key)
        
        // Save to iCloud only if sync is enabled
        if iCloudSyncEnabled {
            cloudStore.set(value, forKey: key)
            cloudStore.synchronize()
            print("☁️ Synced \(key) = \(value)")
        } else {
            print("💾 Saved locally \(key) = \(value)")
        }
    }
    
    /// Handle incoming changes from iCloud
    @objc private func handleCloudUpdate(_ notification: Notification) {
        // Don't process if sync is disabled
        guard iCloudSyncEnabled else { return }
        
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        // Only handle external changes (not our own writes)
        guard reason == NSUbiquitousKeyValueStoreServerChange ||
              reason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("☁️ Received iCloud update, refreshing settings...")
            
            // Update from iCloud (don't trigger sync again)
            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                for key in changedKeys {
                    self.updateFromCloud(key: key)
                }
            }
        }
    }
    
    /// Update a specific setting from iCloud
    private func updateFromCloud(key: String) {
        isUpdatingFromCloud = true
        defer { isUpdatingFromCloud = false }
        
        switch key {
        case Keys.autoConnect:
            if let value = cloudStore.object(forKey: key) as? Bool {
                self.autoConnect = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.backgroundScanning:
            if let value = cloudStore.object(forKey: key) as? Bool {
                self.backgroundScanning = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.notificationsEnabled:
            if let value = cloudStore.object(forKey: key) as? Bool {
                self.notificationsEnabled = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.hapticFeedback:
            if let value = cloudStore.object(forKey: key) as? Bool {
                self.hapticFeedback = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.minimumConfidence:
            if let value = cloudStore.object(forKey: key) as? Double {
                self.minimumConfidence = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.uploadToCrowdsource:
            if let value = cloudStore.object(forKey: key) as? Bool {
                self.uploadToCrowdsource = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.anonymizeData:
            if let value = cloudStore.object(forKey: key) as? Bool {
                self.anonymizeData = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.mapOrientationMode:
            if let value = cloudStore.string(forKey: key),
               let mode = MapOrientationMode(rawValue: value) {
                self.mapOrientationMode = mode
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.audibleAlertsEnabled:
            if let value = cloudStore.object(forKey: key) as? Bool {
                self.audibleAlertsEnabled = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.alertSoundName:
            if let value = cloudStore.string(forKey: key) {
                self.alertSoundName = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        case Keys.alertVolume:
            if let value = cloudStore.object(forKey: key) as? Double {
                self.alertVolume = value
                UserDefaults.standard.set(value, forKey: key)
                print("☁️ Updated \(key) from iCloud: \(value)")
            }
        default:
            break
        }
    }
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
    
    func double(forKey key: String, defaultValue: Double) -> Double {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return double(forKey: key)
    }
}
