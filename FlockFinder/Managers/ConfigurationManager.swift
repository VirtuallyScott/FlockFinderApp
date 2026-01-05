import Foundation
import Combine

/// Manages scan configuration persistence and synchronization with the ESP32
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    // MARK: - Published Properties
    
    @Published var currentConfiguration: ScanConfiguration
    @Published var isLoading: Bool = false
    @Published var lastSyncDate: Date?
    @Published var lastError: String?
    @Published var isSynced: Bool = false
    
    // MARK: - Private Properties
    
    private let userDefaultsKey = "FlockFinder.ScanConfiguration"
    private let lastSyncKey = "FlockFinder.LastConfigSync"
    private var cancellables = Set<AnyCancellable>()
    
    // Callback for when config should be sent to ESP32
    var onConfigurationChanged: ((ScanConfiguration) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        // Load saved configuration or use defaults
        if let savedConfig = Self.loadFromUserDefaults() {
            self.currentConfiguration = savedConfig
        } else {
            self.currentConfiguration = .createDefault()
        }
        
        // Load last sync date
        self.lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        
        // Auto-save when configuration changes
        $currentConfiguration
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] config in
                self?.saveToUserDefaults(config)
                self?.isSynced = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    /// Saves configuration to UserDefaults
    private func saveToUserDefaults(_ config: ScanConfiguration) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(config) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("[ConfigManager] Configuration saved to UserDefaults")
        }
    }
    
    /// Loads configuration from UserDefaults
    private static func loadFromUserDefaults() -> ScanConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "FlockFinder.ScanConfiguration") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(ScanConfiguration.self, from: data)
    }
    
    /// Resets configuration to factory defaults
    func resetToDefaults() {
        currentConfiguration = .createDefault()
        lastError = nil
        isSynced = false
        print("[ConfigManager] Configuration reset to defaults")
    }
    
    // MARK: - Pattern Management
    
    /// Adds a new SSID pattern
    func addSsidPattern(_ pattern: String, deviceType: String) {
        let newPattern = DetectionPattern(pattern: pattern, deviceType: deviceType)
        currentConfiguration.ssidPatterns.append(newPattern)
    }
    
    /// Removes an SSID pattern
    func removeSsidPattern(_ pattern: DetectionPattern) {
        currentConfiguration.ssidPatterns.removeAll { $0.id == pattern.id }
    }
    
    /// Adds a new MAC prefix pattern
    func addMacPrefix(_ prefix: String, deviceType: String) {
        let newPattern = DetectionPattern(pattern: prefix.lowercased(), deviceType: deviceType)
        currentConfiguration.macPrefixes.append(newPattern)
    }
    
    /// Removes a MAC prefix pattern
    func removeMacPrefix(_ pattern: DetectionPattern) {
        currentConfiguration.macPrefixes.removeAll { $0.id == pattern.id }
    }
    
    /// Adds a new BLE name pattern
    func addBleNamePattern(_ name: String, deviceType: String) {
        let newPattern = DetectionPattern(pattern: name, deviceType: deviceType)
        currentConfiguration.bleNamePatterns.append(newPattern)
    }
    
    /// Removes a BLE name pattern
    func removeBleNamePattern(_ pattern: DetectionPattern) {
        currentConfiguration.bleNamePatterns.removeAll { $0.id == pattern.id }
    }
    
    /// Adds a new BLE UUID pattern
    func addBleUuid(_ uuid: String, deviceType: String) {
        let newPattern = DetectionPattern(pattern: uuid.lowercased(), deviceType: deviceType)
        currentConfiguration.bleUuids.append(newPattern)
    }
    
    /// Removes a BLE UUID pattern
    func removeBleUuid(_ pattern: DetectionPattern) {
        currentConfiguration.bleUuids.removeAll { $0.id == pattern.id }
    }
    
    /// Toggles a pattern's enabled state
    func togglePattern(_ pattern: inout DetectionPattern) {
        pattern.isEnabled.toggle()
    }
    
    // MARK: - Scan Interval Management
    
    /// Updates WiFi scan interval (in milliseconds)
    func setWifiScanInterval(_ interval: Int) {
        currentConfiguration.wifiScanInterval = max(1000, min(60000, interval))
    }
    
    /// Updates BLE scan interval (in milliseconds)
    func setBleScanInterval(_ interval: Int) {
        currentConfiguration.bleScanInterval = max(1000, min(60000, interval))
    }
    
    /// Updates channel hop interval (in milliseconds)
    func setChannelHopInterval(_ interval: Int) {
        currentConfiguration.channelHopInterval = max(100, min(5000, interval))
    }
    
    // MARK: - ESP32 Synchronization
    
    /// Converts current configuration to JSON for sending to ESP32
    func getConfigurationJson() -> String? {
        return currentConfiguration.toJsonString()
    }
    
    /// Called when configuration is received from ESP32
    func updateFromEsp32(_ jsonString: String) {
        guard let config = ScanConfiguration.fromJsonString(jsonString) else {
            lastError = "Failed to parse configuration from ESP32"
            print("[ConfigManager] Error: Failed to parse ESP32 config")
            return
        }
        
        DispatchQueue.main.async {
            self.currentConfiguration = config
            self.lastSyncDate = Date()
            self.lastError = nil
            self.isSynced = true
            UserDefaults.standard.set(Date(), forKey: self.lastSyncKey)
            print("[ConfigManager] Configuration updated from ESP32")
        }
    }
    
    /// Marks configuration as synced with ESP32
    func markAsSynced() {
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
            self.isSynced = true
            UserDefaults.standard.set(Date(), forKey: self.lastSyncKey)
        }
    }
    
    /// Gets the configuration as chunked data for BLE transfer
    /// Returns array of chunks suitable for 512-byte BLE MTU
    func getConfigurationChunks(chunkSize: Int = 480) -> [Data] {
        guard let jsonString = currentConfiguration.toJsonString(),
              let fullData = jsonString.data(using: .utf8) else {
            return []
        }
        
        var chunks: [Data] = []
        var offset = 0
        
        while offset < fullData.count {
            let end = min(offset + chunkSize, fullData.count)
            let chunk = fullData.subdata(in: offset..<end)
            chunks.append(chunk)
            offset = end
        }
        
        return chunks
    }
    
    // MARK: - Validation
    
    /// Validates current configuration
    func validateConfiguration() -> [String] {
        return currentConfiguration.validate()
    }
    
    // MARK: - Import/Export
    
    /// Exports configuration to a shareable JSON file
    func exportConfiguration() -> URL? {
        guard let jsonString = currentConfiguration.toJsonString() else { return nil }
        
        let fileName = "FlockFinder_Config_\(formattedDate()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            lastError = "Failed to export configuration: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Imports configuration from JSON data
    func importConfiguration(from data: Data) -> Bool {
        guard let jsonString = String(data: data, encoding: .utf8),
              let config = ScanConfiguration.fromJsonString(jsonString) else {
            lastError = "Invalid configuration file format"
            return false
        }
        
        let errors = config.validate()
        if !errors.isEmpty {
            lastError = errors.joined(separator: "\n")
            return false
        }
        
        currentConfiguration = config
        isSynced = false
        return true
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    // MARK: - Statistics
    
    var totalPatternCount: Int {
        currentConfiguration.ssidPatterns.count +
        currentConfiguration.macPrefixes.count +
        currentConfiguration.bleNamePatterns.count +
        currentConfiguration.bleUuids.count
    }
    
    var enabledPatternCount: Int {
        currentConfiguration.ssidPatterns.filter(\.isEnabled).count +
        currentConfiguration.macPrefixes.filter(\.isEnabled).count +
        currentConfiguration.bleNamePatterns.filter(\.isEnabled).count +
        currentConfiguration.bleUuids.filter(\.isEnabled).count
    }
}
