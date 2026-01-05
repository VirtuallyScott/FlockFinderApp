import SwiftUI

/// Configuration view for managing detection patterns and scan settings
struct ConfigurationView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @ObservedObject var bleManager: BLEManager
    
    @State private var showingAddPattern = false
    @State private var selectedPatternType: PatternType = .ssid
    @State private var newPattern = ""
    @State private var newDeviceType = "Flock Safety"
    @State private var showingSyncAlert = false
    @State private var syncMessage = ""
    @State private var isExpanded: [PatternType: Bool] = [
        .ssid: true,
        .mac: false,
        .bleName: false,
        .bleUuid: false
    ]
    
    enum PatternType: String, CaseIterable {
        case ssid = "SSID Patterns"
        case mac = "MAC Prefixes"
        case bleName = "BLE Name Patterns"
        case bleUuid = "BLE UUIDs"
    }
    
    var body: some View {
        NavigationView {
            List {
                // Sync Status Section
                Section {
                    syncStatusRow
                } header: {
                    Text("ESP32 Sync Status")
                }
                
                // Scanned Devices Section - shows what ESP32 is seeing
                if bleManager.isConnected && hasScannedDevices {
                    scannedDevicesSection
                }
                
                // Scan Mode Toggles Section
                Section {
                    scanModeToggles
                } header: {
                    Text("Scan Modes")
                } footer: {
                    Text("Enable or disable WiFi and BLE scanning. Note: ESP32 only supports 2.4GHz WiFi (channels 1-14).")
                }
                
                // Stream Mode Section
                Section {
                    streamModeControl
                } header: {
                    Text("Debug Stream")
                } footer: {
                    Text("Control what data is streamed to the debug view. 'All Devices' shows everything the scanner sees. 'Matches Only' shows only devices matching your alert patterns.")
                }
                
                // Scan Intervals Section
                Section {
                    scanIntervalControls
                } header: {
                    Text("Scan Intervals")
                } footer: {
                    Text("Adjust how frequently the ESP32 scans for devices")
                }
                
                // Pattern Sections
                ForEach(PatternType.allCases, id: \.self) { patternType in
                    patternSection(for: patternType)
                }
                
                // Actions Section
                Section {
                    actionButtons
                } header: {
                    Text("Actions")
                }
            }
            .navigationTitle("Configuration")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPattern = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPattern) {
                addPatternSheet
            }
            .alert("Sync Status", isPresented: $showingSyncAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(syncMessage)
            }
            .onAppear {
                setupBLECallbacks()
            }
        }
    }
    
    // MARK: - Scanned Devices Section
    
    private var scannedDevicesSection: some View {
        Section {
            HStack {
                Label {
                    VStack(alignment: .leading) {
                        Text("WiFi Devices")
                        Text("\(bleManager.scannedWiFiDevices.count) discovered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "wifi")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if !bleManager.scannedWiFiDevices.isEmpty {
                    Button {
                        selectedPatternType = .mac
                        showingAddPattern = true
                    } label: {
                        Text("Add")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            HStack {
                Label {
                    VStack(alignment: .leading) {
                        Text("BLE Devices")
                        Text("\(bleManager.scannedBLEDevices.count) discovered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                if !bleManager.scannedBLEDevices.isEmpty {
                    Button {
                        selectedPatternType = .mac
                        showingAddPattern = true
                    } label: {
                        Text("Add")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        } header: {
            HStack {
                Text("Live Scanned Devices")
                Spacer()
                Button {
                    bleManager.clearScannedDevices()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
            }
        } footer: {
            Text("Devices currently being detected by the ESP32. Tap 'Add' to create alert patterns from these devices.")
        }
    }
    
    // MARK: - Sync Status Row
    
    private var syncStatusRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(bleManager.isConnected ? (configManager.isSynced ? Color.green : Color.orange) : Color.red)
                        .frame(width: 10, height: 10)
                    Text(syncStatusText)
                        .font(.headline)
                }
                
                if let lastSync = configManager.lastSyncDate {
                    Text("Last sync: \(lastSync, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(configManager.enabledPatternCount)/\(configManager.totalPatternCount) patterns enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if bleManager.isConnected {
                Button(action: syncConfiguration) {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(configManager.isSynced ? .green : .orange)
            }
        }
    }
    
    private var syncStatusText: String {
        if !bleManager.isConnected {
            return "Not Connected"
        } else if configManager.isSynced {
            return "Synced"
        } else {
            return "Pending Sync"
        }
    }
    
    // MARK: - Scan Interval Controls
    
    private var scanIntervalControls: some View {
        Group {
            VStack(alignment: .leading) {
                HStack {
                    Text("WiFi Scan")
                    Spacer()
                    Text("\(configManager.currentConfiguration.wifiScanInterval / 1000)s")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(configManager.currentConfiguration.wifiScanInterval) },
                        set: { configManager.setWifiScanInterval(Int($0)) }
                    ),
                    in: 1000...30000,
                    step: 1000
                )
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("BLE Scan")
                    Spacer()
                    Text("\(configManager.currentConfiguration.bleScanInterval / 1000)s")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(configManager.currentConfiguration.bleScanInterval) },
                        set: { configManager.setBleScanInterval(Int($0)) }
                    ),
                    in: 1000...30000,
                    step: 1000
                )
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Channel Hop")
                    Spacer()
                    Text("\(configManager.currentConfiguration.channelHopInterval)ms")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(configManager.currentConfiguration.channelHopInterval) },
                        set: { configManager.setChannelHopInterval(Int($0)) }
                    ),
                    in: 100...2000,
                    step: 100
                )
            }
        }
    }
    
    // MARK: - Scan Mode Toggles
    
    private var scanModeToggles: some View {
        Group {
            Toggle(isOn: Binding(
                get: { configManager.currentConfiguration.wifiScanEnabled },
                set: { configManager.setWifiScanEnabled($0) }
            )) {
                Label {
                    VStack(alignment: .leading) {
                        Text("WiFi Scanning")
                        Text("2.4GHz only (channels 1-14)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "wifi")
                        .foregroundColor(.blue)
                }
            }
            
            Toggle(isOn: Binding(
                get: { configManager.currentConfiguration.bleScanEnabled },
                set: { configManager.setBleScanEnabled($0) }
            )) {
                Label {
                    VStack(alignment: .leading) {
                        Text("BLE Scanning")
                        Text("Bluetooth Low Energy devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Stream Mode Control
    
    private var streamModeControl: some View {
        Picker("Stream Mode", selection: Binding(
            get: { configManager.currentConfiguration.streamMode },
            set: { configManager.setStreamMode($0) }
        )) {
            ForEach(StreamMode.allCases, id: \.self) { mode in
                HStack {
                    Image(systemName: mode == .all ? "list.bullet" : "target")
                    Text(mode.description)
                }
                .tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Pattern Section
    
    private func patternSection(for type: PatternType) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { isExpanded[type] ?? false },
                    set: { isExpanded[type] = $0 }
                )
            ) {
                ForEach(patterns(for: type), id: \.id) { pattern in
                    patternRow(pattern, type: type)
                }
                .onDelete { indexSet in
                    deletePatterns(at: indexSet, type: type)
                }
            } label: {
                HStack {
                    Text(type.rawValue)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(enabledCount(for: type))/\(patterns(for: type).count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func patternRow(_ pattern: DetectionPattern, type: PatternType) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.pattern)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(pattern.isEnabled ? .primary : .secondary)
                Text(pattern.deviceType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { pattern.isEnabled },
                set: { newValue in
                    togglePattern(pattern, type: type, enabled: newValue)
                }
            ))
            .labelsHidden()
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        Group {
            Button(action: fetchFromESP32) {
                Label("Fetch from ESP32", systemImage: "arrow.down.circle")
            }
            .disabled(!bleManager.isConnected)
            
            Button(action: sendToESP32) {
                Label("Send to ESP32", systemImage: "arrow.up.circle")
            }
            .disabled(!bleManager.isConnected)
            
            Button(action: saveToESP32Flash) {
                Label("Save to ESP32 Flash", systemImage: "square.and.arrow.down")
            }
            .disabled(!bleManager.isConnected)
            
            Button(role: .destructive, action: resetToDefaults) {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
            }
        }
    }
    
    // MARK: - Add Pattern Sheet
    
    private var addPatternSheet: some View {
        NavigationView {
            Form {
                Picker("Pattern Type", selection: $selectedPatternType) {
                    ForEach(PatternType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                // Show device picker for MAC addresses if we have scanned devices
                if selectedPatternType == .mac && hasScannedDevices {
                    scannedDevicePicker
                }
                
                // Show SSID picker if we have WiFi devices with SSIDs
                if selectedPatternType == .ssid && hasScannedSSIDs {
                    scannedSSIDPicker
                }
                
                // Show BLE name picker if we have BLE devices with names
                if selectedPatternType == .bleName && hasScannedBLENames {
                    scannedBLENamePicker
                }
                
                Section {
                    TextField("Pattern (or enter manually)", text: $newPattern)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Manual Entry")
                }
                
                Picker("Device Type", selection: $newDeviceType) {
                    ForEach(SurveillanceDeviceType.allCases, id: \.rawValue) { device in
                        Text(device.displayName).tag(device.rawValue)
                    }
                }
                
                Section {
                    Text(patternHelpText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Help")
                }
            }
            .navigationTitle("Add Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAddPattern = false
                        resetAddForm()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addPattern()
                        showingAddPattern = false
                        resetAddForm()
                    }
                    .disabled(newPattern.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Scanned Device Pickers
    
    private var hasScannedDevices: Bool {
        !bleManager.scannedWiFiDevices.isEmpty || !bleManager.scannedBLEDevices.isEmpty
    }
    
    private var hasScannedSSIDs: Bool {
        bleManager.scannedWiFiDevices.contains { !$0.ssid.isEmpty }
    }
    
    private var hasScannedBLENames: Bool {
        bleManager.scannedBLEDevices.contains { !$0.name.isEmpty }
    }
    
    private var scannedDevicePicker: some View {
        Section {
            if !bleManager.scannedWiFiDevices.isEmpty {
                DisclosureGroup("WiFi Devices (\(bleManager.scannedWiFiDevices.count))") {
                    ForEach(bleManager.scannedWiFiDevices.prefix(20)) { device in
                        Button {
                            // Extract MAC prefix (first 3 octets)
                            let components = device.mac.split(separator: ":").prefix(3)
                            newPattern = components.joined(separator: ":").lowercased()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.ssid.isEmpty ? "(hidden)" : device.ssid)
                                        .font(.subheadline)
                                    Text(device.mac)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fontDesign(.monospaced)
                                }
                                Spacer()
                                Text("\(device.rssi) dBm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            
            if !bleManager.scannedBLEDevices.isEmpty {
                DisclosureGroup("BLE Devices (\(bleManager.scannedBLEDevices.count))") {
                    ForEach(bleManager.scannedBLEDevices.prefix(20)) { device in
                        Button {
                            // Extract MAC prefix (first 3 octets)
                            let components = device.mac.split(separator: ":").prefix(3)
                            newPattern = components.joined(separator: ":").lowercased()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name.isEmpty ? "(no name)" : device.name)
                                        .font(.subheadline)
                                    Text(device.mac)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fontDesign(.monospaced)
                                }
                                Spacer()
                                Text("\(device.rssi) dBm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        } header: {
            HStack {
                Text("Pick from Scanned Devices")
                Spacer()
                Text("Tap to select")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } footer: {
            Text("Shows devices recently scanned by the ESP32. Selecting a device will use its MAC prefix.")
        }
    }
    
    private var scannedSSIDPicker: some View {
        Section {
            let uniqueSSIDs = Array(Set(bleManager.scannedWiFiDevices.compactMap { $0.ssid.isEmpty ? nil : $0.ssid })).sorted()
            ForEach(uniqueSSIDs.prefix(15), id: \.self) { ssid in
                Button {
                    newPattern = ssid
                } label: {
                    HStack {
                        Text(ssid)
                            .font(.subheadline)
                        Spacer()
                        if newPattern == ssid {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        } header: {
            Text("Pick from Scanned SSIDs")
        } footer: {
            Text("SSIDs discovered by the ESP32 WiFi scan")
        }
    }
    
    private var scannedBLENamePicker: some View {
        Section {
            let uniqueNames = Array(Set(bleManager.scannedBLEDevices.compactMap { $0.name.isEmpty ? nil : $0.name })).sorted()
            ForEach(uniqueNames.prefix(15), id: \.self) { name in
                Button {
                    newPattern = name
                } label: {
                    HStack {
                        Text(name)
                            .font(.subheadline)
                        Spacer()
                        if newPattern == name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        } header: {
            Text("Pick from Scanned BLE Names")
        } footer: {
            Text("BLE device names discovered by the ESP32 scan")
        }
    }
    
    private var patternHelpText: String {
        switch selectedPatternType {
        case .ssid:
            return "Enter an SSID pattern to match. Partial matches are supported (e.g., 'Flock-' matches 'Flock-ABC123')."
        case .mac:
            return "Enter a MAC address prefix in format 'xx:xx:xx' (e.g., 'b0:b2:1c')."
        case .bleName:
            return "Enter a BLE device name pattern. Partial matches are supported."
        case .bleUuid:
            return "Enter a BLE service UUID in format 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'."
        }
    }
    
    // MARK: - Helper Methods
    
    private func patterns(for type: PatternType) -> [DetectionPattern] {
        switch type {
        case .ssid: return configManager.currentConfiguration.ssidPatterns
        case .mac: return configManager.currentConfiguration.macPrefixes
        case .bleName: return configManager.currentConfiguration.bleNamePatterns
        case .bleUuid: return configManager.currentConfiguration.bleUuids
        }
    }
    
    private func enabledCount(for type: PatternType) -> Int {
        patterns(for: type).filter(\.isEnabled).count
    }
    
    private func togglePattern(_ pattern: DetectionPattern, type: PatternType, enabled: Bool) {
        switch type {
        case .ssid:
            if let index = configManager.currentConfiguration.ssidPatterns.firstIndex(where: { $0.id == pattern.id }) {
                configManager.currentConfiguration.ssidPatterns[index].isEnabled = enabled
            }
        case .mac:
            if let index = configManager.currentConfiguration.macPrefixes.firstIndex(where: { $0.id == pattern.id }) {
                configManager.currentConfiguration.macPrefixes[index].isEnabled = enabled
            }
        case .bleName:
            if let index = configManager.currentConfiguration.bleNamePatterns.firstIndex(where: { $0.id == pattern.id }) {
                configManager.currentConfiguration.bleNamePatterns[index].isEnabled = enabled
            }
        case .bleUuid:
            if let index = configManager.currentConfiguration.bleUuids.firstIndex(where: { $0.id == pattern.id }) {
                configManager.currentConfiguration.bleUuids[index].isEnabled = enabled
            }
        }
    }
    
    private func deletePatterns(at indexSet: IndexSet, type: PatternType) {
        switch type {
        case .ssid:
            configManager.currentConfiguration.ssidPatterns.remove(atOffsets: indexSet)
        case .mac:
            configManager.currentConfiguration.macPrefixes.remove(atOffsets: indexSet)
        case .bleName:
            configManager.currentConfiguration.bleNamePatterns.remove(atOffsets: indexSet)
        case .bleUuid:
            configManager.currentConfiguration.bleUuids.remove(atOffsets: indexSet)
        }
    }
    
    private func addPattern() {
        switch selectedPatternType {
        case .ssid:
            configManager.addSsidPattern(newPattern, deviceType: newDeviceType)
        case .mac:
            configManager.addMacPrefix(newPattern, deviceType: newDeviceType)
        case .bleName:
            configManager.addBleNamePattern(newPattern, deviceType: newDeviceType)
        case .bleUuid:
            configManager.addBleUuid(newPattern, deviceType: newDeviceType)
        }
    }
    
    private func resetAddForm() {
        newPattern = ""
        newDeviceType = "Flock Safety"
    }
    
    // MARK: - ESP32 Sync Actions
    
    private func setupBLECallbacks() {
        bleManager.onConfigReceived = { jsonString in
            if let config = ScanConfiguration.fromJsonString(jsonString) {
                DispatchQueue.main.async {
                    configManager.currentConfiguration = config
                    configManager.markAsSynced()
                    syncMessage = "Configuration received from ESP32"
                    showingSyncAlert = true
                }
            }
        }
        
        bleManager.onConfigSyncComplete = { success, message in
            DispatchQueue.main.async {
                if success {
                    configManager.markAsSynced()
                }
                syncMessage = message ?? (success ? "Sync complete" : "Sync failed")
                showingSyncAlert = true
            }
        }
    }
    
    private func syncConfiguration() {
        sendToESP32()
    }
    
    private func fetchFromESP32() {
        bleManager.requestConfiguration()
    }
    
    private func sendToESP32() {
        bleManager.sendConfiguration(configManager.currentConfiguration)
    }
    
    private func saveToESP32Flash() {
        bleManager.saveConfigurationToFlash()
    }
    
    private func resetToDefaults() {
        configManager.resetToDefaults()
        if bleManager.isConnected {
            bleManager.resetConfigurationToDefaults()
        }
    }
}

// MARK: - Preview

#Preview {
    ConfigurationView(bleManager: BLEManager())
}
