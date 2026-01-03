import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var audioManager = AudioAlertManager.shared
    @StateObject private var cloudManager = iCloudManager.shared
    
    @State private var showingAbout = false
    @State private var showingClearConfirmation = false
    @State private var showingExportSheet = false
    @State private var showingDebugStream = false
    @State private var recordCount = 0
    @State private var showingBackupConfirmation = false
    @State private var showingRestoreConfirmation = false
    
    // Diagnostic computed properties
    var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Authorized (Always)"
        case .authorizedWhenInUse:
            return "Authorized (In Use)"
        @unknown default:
            return "Unknown"
        }
    }
    
    var locationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    var gpsAccuracyText: String {
        if let location = locationManager.currentLocation {
            let accuracy = location.horizontalAccuracy
            if accuracy < 0 {
                return "Invalid"
            } else if accuracy < 10 {
                return "Excellent (\(Int(accuracy))m)"
            } else if accuracy < 50 {
                return "Good (\(Int(accuracy))m)"
            } else if accuracy < 100 {
                return "Fair (\(Int(accuracy))m)"
            } else {
                return "Poor (\(Int(accuracy))m)"
            }
        }
        return "No Fix"
    }
    
    var gpsAccuracyColor: Color {
        if let location = locationManager.currentLocation {
            let accuracy = location.horizontalAccuracy
            if accuracy < 0 {
                return .red
            } else if accuracy < 50 {
                return .green
            } else if accuracy < 100 {
                return .orange
            } else {
                return .red
            }
        }
        return .red
    }
    
    var infoPlistStatus: String {
        if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil {
            return "✓ Configured"
        } else {
            return "✗ Missing Key"
        }
    }
    
    var infoPlistColor: Color {
        if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil {
            return .green
        } else {
            return .red
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Device section
                Section("Device") {
                    if bleManager.isConnected, let device = bleManager.connectedDevice {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text(device.name ?? "FlockFinder")
                                    .font(.headline)
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Disconnect", role: .destructive) {
                            bleManager.disconnect()
                        }
                    } else {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .foregroundColor(.secondary)
                            Text("No device connected")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("Auto-connect on launch", isOn: $appSettings.autoConnect)
                }
                
                // iCloud Settings Sync section
                Section {
                    Toggle(isOn: $appSettings.iCloudSyncEnabled) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Settings Sync")
                                    .font(.subheadline)
                                Text(appSettings.iCloudSyncEnabled ? "Synced across devices" : "Local only")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } footer: {
                    if appSettings.iCloudSyncEnabled {
                        Text("Your app settings are automatically synchronized across all your devices signed into iCloud. Changes are synced in real-time.")
                    } else {
                        Text("Settings will be stored locally on this device only and will not sync to your other devices.")
                    }
                }
                
                // Scanning section
                Section("Scanning") {
                    Toggle("Background scanning", isOn: $appSettings.backgroundScanning)
                    
                    VStack(alignment: .leading) {
                        Text("Minimum Confidence: \(Int(appSettings.minimumConfidence * 100))%")
                        Slider(value: $appSettings.minimumConfidence, in: 0.1...1.0, step: 0.1)
                    }
                }
                
                // Map section
                Section {
                    Picker("Map Orientation", selection: $appSettings.mapOrientationMode) {
                        ForEach(AppSettings.MapOrientationMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                } header: {
                    Text("Map")
                } footer: {
                    Text(appSettings.mapOrientationMode.description)
                }
                
                // Audio Alerts section
                Section {
                    Toggle("Audible Alerts", isOn: $appSettings.audibleAlertsEnabled)
                    
                    if appSettings.audibleAlertsEnabled {
                        Picker("Alert Sound", selection: $appSettings.alertSoundName) {
                            ForEach(AudioAlertManager.AlertSound.allCases) { sound in
                                Text(sound.rawValue).tag(sound.rawValue)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Volume")
                                Spacer()
                                if appSettings.alertVolume == 0 {
                                    Text("Muted")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                } else {
                                    Text("\(Int(appSettings.alertVolume * 100))%")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: appSettings.alertVolume == 0 ? "speaker.slash.fill" : "speaker.wave.1.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Slider(value: $appSettings.alertVolume, in: 0.0...1.0, step: 0.1)
                                
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        Button {
                            audioManager.testAlert()
                        } label: {
                            HStack {
                                Image(systemName: "speaker.wave.2.circle")
                                Text("Test Alert Sound")
                            }
                        }
                        .disabled(appSettings.alertVolume == 0)
                        
                        // Show current audio output
                        if audioManager.isConnectedToCarPlay {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundColor(.blue)
                                Text("Connected to CarPlay")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if audioManager.isConnectedToBluetooth {
                            HStack {
                                Image(systemName: "bluetooth.fill")
                                    .foregroundColor(.blue)
                                Text("Connected to Bluetooth")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Audio Alerts")
                } footer: {
                    Text("Play an audible alert when a Flock device is detected. Works with CarPlay and Bluetooth audio systems.")
                }
                
                // Notifications section
                Section("Notifications") {
                    Toggle("Detection alerts", isOn: $appSettings.notificationsEnabled)
                    Toggle("Haptic feedback", isOn: $appSettings.hapticFeedback)
                }
                
                // Crowdsource section
                Section {
                    Toggle("Upload to crowdsource", isOn: $appSettings.uploadToCrowdsource)
                    if appSettings.uploadToCrowdsource {
                        Toggle("Anonymize location data", isOn: $appSettings.anonymizeData)
                    }
                } header: {
                    Text("Crowdsource")
                } footer: {
                    Text("Help map surveillance cameras by sharing detection data. Location can be randomized within 100m for privacy.")
                }
                
                // Data management section
                Section("Data Management") {
                    HStack {
                        Text("Stored Detections")
                        Spacer()
                        Text("\(recordCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Export All Data") {
                        showingExportSheet = true
                    }
                    .disabled(recordCount == 0)
                    
                    Button("Clear All Data", role: .destructive) {
                        showingClearConfirmation = true
                    }
                    .disabled(recordCount == 0)
                }
                
                // iCloud Backup section
                iCloudBackupSection
                
                // Diagnostics section
                Section("Diagnostics") {
                    VStack(alignment: .leading, spacing: 8) {
                        DiagnosticRow(
                            icon: "location.fill",
                            label: "Location Status",
                            value: locationStatusText,
                            color: locationStatusColor
                        )
                        
                        DiagnosticRow(
                            icon: "location.circle",
                            label: "GPS Accuracy",
                            value: gpsAccuracyText,
                            color: gpsAccuracyColor
                        )
                        
                        DiagnosticRow(
                            icon: "info.circle",
                            label: "Info.plist Check",
                            value: infoPlistStatus,
                            color: infoPlistColor
                        )
                        
                        DiagnosticRow(
                            icon: "antenna.radiowaves.left.and.right",
                            label: "Bluetooth",
                            value: bleManager.bluetoothState == .poweredOn ? "On" : "Off",
                            color: bleManager.bluetoothState == .poweredOn ? .green : .red
                        )
                    }
                    
                    Button {
                        showingDebugStream = true
                    } label: {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                            Text("View Debug Stream")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .disabled(!bleManager.isConnected)
                }
                
                // About section
                Section("About") {
                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            Text("About FlockFinder")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Link(destination: URL(string: "https://github.com/colonelpanichacks/oui-spy")!) {
                        HStack {
                            Text("OUI-SPY Project")
                            Spacer()
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                recordCount = databaseManager.fetchAllDetections().count
            }
            .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    databaseManager.clearAllDetections()
                    recordCount = 0
                }
            } message: {
                Text("This will permanently delete all \(recordCount) detection records. This action cannot be undone.")
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportView(detections: databaseManager.fetchAllDetections())
            }
            .sheet(isPresented: $showingDebugStream) {
                DebugStreamView()
            }
            .alert("Restore from iCloud?", isPresented: $showingRestoreConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    restoreFromICloud()
                }
            } message: {
                Text("This will replace your current database with the backup from iCloud. Your current data will be saved as a backup.")
            }
        }
    }
    
    // MARK: - iCloud Backup Section
    
    private var iCloudBackupSection: some View {
        Section {
            // iCloud status
            HStack {
                Image(systemName: cloudManager.isICloudAvailable ? "icloud.fill" : "icloud.slash.fill")
                    .foregroundColor(cloudManager.isICloudAvailable ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Status")
                        .font(.subheadline)
                    Text(cloudManager.isICloudAvailable ? "Available" : "Not Available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if cloudManager.isICloudAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // Last backup info
            if let lastBackup = cloudManager.lastBackupDate {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Backup")
                            .font(.subheadline)
                        Text(lastBackup, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let size = cloudManager.getBackupSize() {
                        Text(formatBytes(size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Backup button
            Button {
                backupToICloud()
            } label: {
                HStack {
                    if cloudManager.isBackingUp {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                    Text(cloudManager.isBackingUp ? "Backing Up..." : "Backup to iCloud")
                }
            }
            .disabled(!cloudManager.isICloudAvailable || cloudManager.isBackingUp || recordCount == 0)
            
            // Restore button
            Button {
                showingRestoreConfirmation = true
            } label: {
                HStack {
                    if cloudManager.isRestoring {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                    Text(cloudManager.isRestoring ? "Restoring..." : "Restore from iCloud")
                }
            }
            .disabled(!cloudManager.isICloudAvailable || cloudManager.isRestoring || !cloudManager.hasBackup())
            
            // Error message
            if let error = cloudManager.backupError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        } header: {
            Text("iCloud Backup")
        } footer: {
            if cloudManager.isICloudAvailable {
                Text("Your detection database will be backed up to iCloud Drive. This is separate from Settings Sync, which can be toggled above.")
            } else {
                Text("Sign in to iCloud in Settings to enable backup. Make sure iCloud Drive is enabled for this app.")
            }
        }
    }
    
    // MARK: - iCloud Actions
    
    private func backupToICloud() {
        cloudManager.backupToICloud { result in
            switch result {
            case .success:
                // Show success feedback (could add haptic or alert)
                if appSettings.hapticFeedback {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            case .failure(let error):
                print("Backup failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func restoreFromICloud() {
        cloudManager.restoreFromICloud { result in
            switch result {
            case .success:
                // Reload data
                recordCount = databaseManager.fetchAllDetections().count
                
                if appSettings.hapticFeedback {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            case .failure(let error):
                print("Restore failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    Text("FlockFinder")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Surveillance Detection System")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About")
                            .font(.headline)
                        
                        Text("FlockFinder is an iOS companion app for the Flock-You ESP32 firmware. It connects to your FlockFinder device via Bluetooth Low Energy and logs detections of Flock Safety and other surveillance cameras.")
                            .foregroundColor(.secondary)
                        
                        Text("Features")
                            .font(.headline)
                            .padding(.top)
                        
                        FeatureRow(icon: "antenna.radiowaves.left.and.right", 
                                   title: "BLE Connectivity",
                                   description: "Connect to ESP32-S3 FlockFinder device")
                        
                        FeatureRow(icon: "location.fill",
                                   title: "GPS Logging",
                                   description: "Record precise location of each detection")
                        
                        FeatureRow(icon: "gyroscope",
                                   title: "Motion Tracking",
                                   description: "Capture speed and direction of travel")
                        
                        FeatureRow(icon: "externaldrive.fill",
                                   title: "Local Storage",
                                   description: "SQLite database for offline access")
                        
                        FeatureRow(icon: "map.fill",
                                   title: "Detection Map",
                                   description: "Visualize detections on an interactive map")
                        
                        Text("Credits")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("Based on the OUI-SPY and Flock-You projects by ColonelPanicHacks. Firmware runs on Unexpected Maker FeatherS3 (ESP32-S3).")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Diagnostic Row
struct DiagnosticRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BLEManager())
        .environmentObject(LocationManager())
        .environmentObject(DatabaseManager.shared)
}
