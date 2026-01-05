import Foundation

// MARK: - Detection Pattern
/// A single detection pattern with its device type identifier
struct DetectionPattern: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var pattern: String
    var deviceType: String
    var isEnabled: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case pattern = "p"
        case deviceType = "t"
        case isEnabled = "e"
    }
    
    init(pattern: String, deviceType: String, isEnabled: Bool = true) {
        self.pattern = pattern
        self.deviceType = deviceType
        self.isEnabled = isEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pattern = try container.decode(String.self, forKey: .pattern)
        self.deviceType = try container.decode(String.self, forKey: .deviceType)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.id = UUID()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pattern, forKey: .pattern)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

// MARK: - Stream Mode
/// Controls what data is streamed from the ESP32
enum StreamMode: Int, Codable, CaseIterable {
    case all = 0            // Stream all detected devices
    case matchesOnly = 1    // Stream only devices matching patterns
    
    var description: String {
        switch self {
        case .all: return "All Devices"
        case .matchesOnly: return "Matches Only"
        }
    }
}

// MARK: - Scan Configuration
/// Configuration for the ESP32 scanner, matching the ConfigManager structure
struct ScanConfiguration: Codable {
    // Version for compatibility checking
    var version: Int = 1
    
    // Scan mode toggles
    var wifiScanEnabled: Bool
    var bleScanEnabled: Bool
    var streamMode: StreamMode
    
    // Scan intervals (in milliseconds)
    var wifiScanInterval: Int
    var bleScanInterval: Int
    var channelHopInterval: Int
    
    // Detection patterns
    var ssidPatterns: [DetectionPattern]
    var macPrefixes: [DetectionPattern]
    var bleNamePatterns: [DetectionPattern]
    var bleUuids: [DetectionPattern]
    
    enum CodingKeys: String, CodingKey {
        case version = "v"
        case wifiScanEnabled = "wifi_en"
        case bleScanEnabled = "ble_en"
        case streamMode = "stream"
        case wifiScanInterval = "wsi"
        case bleScanInterval = "bsi"
        case channelHopInterval = "chi"
        case ssidPatterns = "ssid"
        case macPrefixes = "mac"
        case bleNamePatterns = "ble_n"
        case bleUuids = "ble_u"
    }
    
    /// Creates configuration with default detection patterns
    static func createDefault() -> ScanConfiguration {
        return ScanConfiguration(
            version: 1,
            wifiScanEnabled: true,
            bleScanEnabled: true,
            streamMode: .all,
            wifiScanInterval: 5000,
            bleScanInterval: 3000,
            channelHopInterval: 500,
            ssidPatterns: defaultSsidPatterns,
            macPrefixes: defaultMacPrefixes,
            bleNamePatterns: defaultBleNamePatterns,
            bleUuids: defaultBleUuids
        )
    }
    
    // MARK: - Default Patterns (matching ESP32 defaults)
    
    static let defaultSsidPatterns: [DetectionPattern] = [
        // Flock Safety patterns
        DetectionPattern(pattern: "Flock-", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "FS-", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "FlockSafety", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "ALPRCam", deviceType: "Flock Safety"),
        // Penguin patterns
        DetectionPattern(pattern: "Penguin-", deviceType: "Penguin"),
        DetectionPattern(pattern: "PENGUIN", deviceType: "Penguin"),
        // Pigvision/Motorola patterns
        DetectionPattern(pattern: "Pigvision", deviceType: "Pigvision"),
        DetectionPattern(pattern: "L5Q", deviceType: "Motorola"),
        DetectionPattern(pattern: "M500", deviceType: "Motorola")
    ]
    
    static let defaultMacPrefixes: [DetectionPattern] = [
        // Flock Safety OUIs
        DetectionPattern(pattern: "b0:b2:1c", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "34:94:54", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "00:e0:4c", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "28:ee:52", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "20:6b:e7", deviceType: "Flock Safety"),
        // Quectel modules
        DetectionPattern(pattern: "a4:e5:7c", deviceType: "Quectel"),
        DetectionPattern(pattern: "fc:41:20", deviceType: "Quectel"),
        DetectionPattern(pattern: "ec:21:25", deviceType: "Quectel"),
        // Raven
        DetectionPattern(pattern: "00:60:35", deviceType: "Raven"),
        // Sierra Wireless
        DetectionPattern(pattern: "00:14:3e", deviceType: "Sierra Wireless")
    ]
    
    static let defaultBleNamePatterns: [DetectionPattern] = [
        DetectionPattern(pattern: "Flock", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "FlockCam", deviceType: "Flock Safety"),
        DetectionPattern(pattern: "Penguin", deviceType: "Penguin"),
        DetectionPattern(pattern: "Pigvision", deviceType: "Pigvision"),
        DetectionPattern(pattern: "Raven", deviceType: "Raven")
    ]
    
    // Raven gunshot detector service UUIDs
    static let defaultBleUuids: [DetectionPattern] = [
        // Raven service UUIDs
        DetectionPattern(pattern: "7b183224-9168-443e-a927-7aeea07e8105", deviceType: "Raven"),
        DetectionPattern(pattern: "00002a00-0000-1000-8000-00805f9b34fb", deviceType: "Raven"),
        DetectionPattern(pattern: "0000180a-0000-1000-8000-00805f9b34fb", deviceType: "Raven"),
        DetectionPattern(pattern: "0000affe-0000-1000-8000-00805f9b34fb", deviceType: "Raven"),
        DetectionPattern(pattern: "0000b00b-0000-1000-8000-00805f9b34fb", deviceType: "Raven"),
        DetectionPattern(pattern: "0000b007-0000-1000-8000-00805f9b34fb", deviceType: "Raven"),
        DetectionPattern(pattern: "0000face-0000-1000-8000-00805f9b34fb", deviceType: "Raven"),
        DetectionPattern(pattern: "0000dead-0000-1000-8000-00805f9b34fb", deviceType: "Raven"),
        // Legacy Raven UUIDs
        DetectionPattern(pattern: "e8e7c8ba-e87e-11e5-a837-0800200c9a66", deviceType: "Raven"),
        DetectionPattern(pattern: "f4c2d11c-e87e-11e5-a837-0800200c9a66", deviceType: "Raven")
    ]
    
    // MARK: - Validation
    
    /// Validates the configuration has reasonable values
    func validate() -> [String] {
        var errors: [String] = []
        
        if wifiScanInterval < 1000 || wifiScanInterval > 60000 {
            errors.append("WiFi scan interval should be between 1000-60000ms")
        }
        
        if bleScanInterval < 1000 || bleScanInterval > 60000 {
            errors.append("BLE scan interval should be between 1000-60000ms")
        }
        
        if channelHopInterval < 100 || channelHopInterval > 5000 {
            errors.append("Channel hop interval should be between 100-5000ms")
        }
        
        return errors
    }
    
    // MARK: - JSON Serialization
    
    /// Converts configuration to JSON string for sending to ESP32
    func toJsonString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [] // Compact, no pretty print
        
        if let data = try? encoder.encode(self),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return nil
    }
    
    /// Parses configuration from JSON string received from ESP32
    static func fromJsonString(_ json: String) -> ScanConfiguration? {
        guard let data = json.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(ScanConfiguration.self, from: data)
    }
}

// MARK: - Device Type Enum
/// Known surveillance device types
enum SurveillanceDeviceType: String, CaseIterable {
    case flockSafety = "Flock Safety"
    case penguin = "Penguin"
    case pigvision = "Pigvision"
    case raven = "Raven"
    case motorola = "Motorola"
    case quectel = "Quectel"
    case sierraWireless = "Sierra Wireless"
    case unknown = "Unknown"
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .flockSafety:
            return "Flock Safety ALPR camera"
        case .penguin:
            return "Penguin surveillance device"
        case .pigvision:
            return "Pigvision/Motorola camera"
        case .raven:
            return "SoundThinking/ShotSpotter gunshot detector"
        case .motorola:
            return "Motorola surveillance equipment"
        case .quectel:
            return "Quectel cellular module"
        case .sierraWireless:
            return "Sierra Wireless modem"
        case .unknown:
            return "Unidentified device"
        }
    }
    
    var threatLevel: ThreatLevel {
        switch self {
        case .flockSafety, .penguin, .pigvision:
            return .high
        case .raven:
            return .critical
        case .motorola:
            return .medium
        case .quectel, .sierraWireless:
            return .low
        case .unknown:
            return .unknown
        }
    }
}

enum ThreatLevel: String {
    case critical = "CRITICAL"
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    case unknown = "UNKNOWN"
}
