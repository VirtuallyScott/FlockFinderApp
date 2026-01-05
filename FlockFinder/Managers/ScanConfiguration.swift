import Foundation

/// Configuration structure for ESP32 scanner device
struct ScanConfiguration: Codable {
    
    // MARK: - WiFi Scanning
    var wifiEnabled: Bool = true
    var wifiScanDuration: Int = 3000  // ms per channel
    var wifiChannels: [Int] = [1, 6, 11]  // Common WiFi channels
    
    // MARK: - BLE Scanning
    var bleEnabled: Bool = true
    var bleScanDuration: Int = 5000  // ms
    var bleScanInterval: Int = 100  // ms
    var bleScanWindow: Int = 50  // ms
    
    // MARK: - Detection Thresholds
    var rssiThreshold: Int = -80  // Minimum signal strength
    var confidenceThreshold: Double = 0.5  // 0.0 - 1.0
    
    // MARK: - General Settings
    var scanInterval: Int = 10000  // ms between scan cycles
    var maxResults: Int = 50  // Maximum detections to store
    var autoStart: Bool = true  // Start scanning on power-up
    
    // MARK: - JSON Serialization
    
    /// Convert configuration to JSON string for BLE transmission
    func toJsonString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        guard let jsonData = try? encoder.encode(self),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    /// Create configuration from JSON string
    static func fromJsonString(_ jsonString: String) -> ScanConfiguration? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(ScanConfiguration.self, from: jsonData)
    }
    
    // MARK: - Presets
    
    /// Default configuration
    static let `default` = ScanConfiguration()
    
    /// Aggressive scanning for maximum detection
    static let aggressive = ScanConfiguration(
        wifiEnabled: true,
        wifiScanDuration: 5000,
        wifiChannels: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        bleEnabled: true,
        bleScanDuration: 10000,
        bleScanInterval: 50,
        bleScanWindow: 50,
        rssiThreshold: -90,
        confidenceThreshold: 0.3,
        scanInterval: 5000,
        maxResults: 100,
        autoStart: true
    )
    
    /// Battery-saving configuration
    static let batterySaver = ScanConfiguration(
        wifiEnabled: true,
        wifiScanDuration: 2000,
        wifiChannels: [1, 6, 11],
        bleEnabled: true,
        bleScanDuration: 3000,
        bleScanInterval: 200,
        bleScanWindow: 25,
        rssiThreshold: -70,
        confidenceThreshold: 0.6,
        scanInterval: 20000,
        maxResults: 25,
        autoStart: true
    )
}
