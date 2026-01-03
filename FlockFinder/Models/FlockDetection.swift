import Foundation
import CoreLocation
import SwiftUI

// MARK: - Device Type Enum
enum DeviceType: String, Codable, CaseIterable {
    case flock = "Flock Safety"
    case verkada = "Verkada"
    case lorex = "Lorex"
    case reolink = "Reolink"
    case axis = "Axis"
    case hikvision = "Hikvision"
    case dahua = "Dahua"
    case ring = "Ring"
    case nest = "Nest"
    case arlo = "Arlo"
    case wyze = "Wyze"
    case eufy = "Eufy"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .flock:
            return "car.fill"
        case .verkada:
            return "building.2.fill"
        case .lorex, .reolink, .axis, .hikvision, .dahua:
            return "video.fill"
        case .ring:
            return "bell.fill"
        case .nest:
            return "house.fill"
        case .arlo, .wyze, .eufy:
            return "camera.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .flock:
            return .red
        case .verkada:
            return .orange
        case .lorex, .reolink:
            return .blue
        case .axis:
            return .yellow
        case .hikvision, .dahua:
            return .purple
        case .ring:
            return .cyan
        case .nest:
            return .teal
        case .arlo, .wyze, .eufy:
            return .green
        case .unknown:
            return .gray
        }
    }
    
    var description: String {
        switch self {
        case .flock:
            return "Flock Safety - ALPR camera system used by law enforcement"
        case .verkada:
            return "Verkada - Enterprise security camera platform"
        case .lorex:
            return "Lorex - Consumer/commercial security cameras"
        case .reolink:
            return "Reolink - IP security cameras"
        case .axis:
            return "Axis Communications - Professional IP cameras"
        case .hikvision:
            return "Hikvision - Chinese surveillance manufacturer"
        case .dahua:
            return "Dahua - Chinese surveillance manufacturer"
        case .ring:
            return "Ring - Amazon smart doorbell/camera"
        case .nest:
            return "Nest - Google smart home camera"
        case .arlo:
            return "Arlo - Wireless security camera"
        case .wyze:
            return "Wyze - Budget smart home camera"
        case .eufy:
            return "Eufy - Smart home security"
        case .unknown:
            return "Unknown surveillance device"
        }
    }
}

// MARK: - Flock Detection Model
struct FlockDetection: Identifiable, Codable, Equatable {
    let id: Int64
    let deviceType: DeviceType
    let macAddress: String?
    let ssid: String?
    let rssi: Int
    let confidence: Double
    
    // Location data
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let accuracy: Double
    let speed: Double // meters per second from GPS
    let heading: Double // course/direction of travel from GPS (0-360°)
    
    // Motion data (deprecated - kept for database compatibility)
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let activityType: String?
    
    // Metadata
    let timestamp: Date
    let synced: Bool
    
    // Computed properties
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isValidLocation: Bool {
        // Check if coordinates are valid (not 0,0 and within valid range)
        return abs(latitude) > 0.0001 && abs(longitude) > 0.0001 &&
               latitude >= -90 && latitude <= 90 &&
               longitude >= -180 && longitude <= 180
    }
    
    var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }
    
    var speedMPH: Double {
        speed * 2.237
    }
    
    var accelerationMagnitude: Double {
        sqrt(pow(accelerationX, 2) + pow(accelerationY, 2) + pow(accelerationZ, 2))
    }
    
    var signalStrengthDescription: String {
        if rssi >= -50 {
            return "Excellent"
        } else if rssi >= -60 {
            return "Good"
        } else if rssi >= -70 {
            return "Fair"
        } else {
            return "Weak"
        }
    }
    
    var confidenceDescription: String {
        if confidence >= 0.9 {
            return "Very High"
        } else if confidence >= 0.7 {
            return "High"
        } else if confidence >= 0.5 {
            return "Medium"
        } else {
            return "Low"
        }
    }
    
    // Initializers
    init(
        id: Int64 = 0,
        deviceType: DeviceType,
        macAddress: String?,
        ssid: String?,
        rssi: Int,
        confidence: Double,
        latitude: Double,
        longitude: Double,
        altitude: Double = 0,
        accuracy: Double = 0,
        speed: Double = 0,
        heading: Double = 0,
        accelerationX: Double = 0,
        accelerationY: Double = 0,
        accelerationZ: Double = 0,
        activityType: String? = nil,
        timestamp: Date = Date(),
        synced: Bool = false
    ) {
        self.id = id
        self.deviceType = deviceType
        self.macAddress = macAddress
        self.ssid = ssid
        self.rssi = rssi
        self.confidence = confidence
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.accuracy = accuracy
        self.speed = speed
        self.heading = heading
        self.accelerationX = accelerationX
        self.accelerationY = accelerationY
        self.accelerationZ = accelerationZ
        self.activityType = activityType
        self.timestamp = timestamp
        self.synced = synced
    }
    
    // Create from BLE detection data + location (no motion data needed)
    init(
        bleData: BLEManager.DetectionData,
        location: LocationData
    ) {
        self.id = 0
        self.deviceType = DeviceType(rawValue: bleData.deviceType) ?? .unknown
        self.macAddress = bleData.macAddress
        self.ssid = bleData.ssid
        self.rssi = bleData.rssi
        self.confidence = bleData.confidence
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.altitude = location.altitude
        self.accuracy = location.accuracy
        self.speed = location.speed
        self.heading = location.heading
        // Motion data no longer used - set to zeros
        self.accelerationX = 0
        self.accelerationY = 0
        self.accelerationZ = 0
        self.activityType = nil
        self.timestamp = bleData.timestamp
        self.synced = false
    }
    
    static func == (lhs: FlockDetection, rhs: FlockDetection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data for Previews
extension FlockDetection {
    static var sampleData: [FlockDetection] {
        [
            FlockDetection(
                id: 1,
                deviceType: .flock,
                macAddress: "AA:BB:CC:DD:EE:01",
                ssid: "FLOCK-CAM-001",
                rssi: -55,
                confidence: 0.95,
                latitude: 37.7749,
                longitude: -122.4194,
                altitude: 15.0,
                accuracy: 5.0,
                speed: 12.5,
                heading: 45.0,
                accelerationX: 0.01,
                accelerationY: 0.02,
                accelerationZ: 0.98,
                activityType: "Driving",
                timestamp: Date().addingTimeInterval(-3600),
                synced: true
            ),
            FlockDetection(
                id: 2,
                deviceType: .verkada,
                macAddress: "AA:BB:CC:DD:EE:02",
                ssid: nil,
                rssi: -62,
                confidence: 0.78,
                latitude: 37.7850,
                longitude: -122.4100,
                altitude: 20.0,
                accuracy: 8.0,
                speed: 0.0,
                heading: 0.0,
                accelerationX: 0.0,
                accelerationY: 0.0,
                accelerationZ: 1.0,
                activityType: "Stationary",
                timestamp: Date().addingTimeInterval(-7200),
                synced: false
            ),
            FlockDetection(
                id: 3,
                deviceType: .ring,
                macAddress: "AA:BB:CC:DD:EE:03",
                ssid: "Ring-Doorbell",
                rssi: -70,
                confidence: 0.65,
                latitude: 37.7700,
                longitude: -122.4250,
                altitude: 10.0,
                accuracy: 10.0,
                speed: 1.2,
                heading: 180.0,
                accelerationX: 0.05,
                accelerationY: 0.03,
                accelerationZ: 0.99,
                activityType: "Walking",
                timestamp: Date().addingTimeInterval(-86400),
                synced: true
            )
        ]
    }
}
