import Foundation
import CoreLocation
import Combine

/// Location Manager for GPS tracking
class LocationManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var heading: CLHeading?
    @Published var speed: Double = 0
    @Published var lastError: Error?
    
    // MARK: - Computed Properties
    var coordinate: CLLocationCoordinate2D? {
        currentLocation?.coordinate
    }
    
    var altitude: Double {
        currentLocation?.altitude ?? 0
    }
    
    var horizontalAccuracy: Double {
        currentLocation?.horizontalAccuracy ?? 0
    }
    
    var headingDegrees: Double {
        // Use course (direction of travel) if available and valid
        // This is more accurate for vehicles than compass heading
        if let location = currentLocation, location.course >= 0 {
            return location.course
        }
        // Fall back to compass heading if course unavailable
        return heading?.trueHeading ?? heading?.magneticHeading ?? 0
    }
    
    var speedMPH: Double {
        speed * 2.237 // Convert m/s to mph
    }
    
    var locationString: String {
        guard let location = currentLocation else { return "Unknown" }
        return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    
    // MARK: - Initialization
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false
        
        print("📍 LocationManager initialized")
        print("📍 Authorization status: \(locationManager.authorizationStatus)")
    }
    
    // MARK: - Public Methods
    
    /// Request location authorization
    func requestAuthorization() {
        print("📍 Requesting location authorization (current: \(authorizationStatus))")
        
        // Check if we have the required Info.plist keys
        if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") == nil {
            print("❌ ERROR: Missing 'NSLocationWhenInUseUsageDescription' in Info.plist!")
            print("❌ Add this to Info.plist:")
            print("   Key: Privacy - Location When In Use Usage Description")
            print("   Value: FlockFinder needs your location to tag detected surveillance devices.")
        }
        
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Request always authorization for background tracking
    func requestAlwaysAuthorization() {
        print("📍 Requesting always location authorization")
        locationManager.requestAlwaysAuthorization()
    }
    
    /// Start tracking location
    func startTracking() {
        print("📍 startTracking() called")
        print("📍 Current authorization: \(authorizationStatus)")
        
        guard authorizationStatus == .authorizedWhenInUse || 
              authorizationStatus == .authorizedAlways else {
            print("⚠️ Not authorized, requesting permission...")
            requestAuthorization()
            return
        }
        
        print("✅ Starting location and heading updates")
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        isTracking = true
    }
    
    /// Stop tracking location
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        isTracking = false
    }
    
    /// Get current location data for logging
    func getLocationData() -> LocationData {
        return LocationData(
            latitude: currentLocation?.coordinate.latitude ?? 0,
            longitude: currentLocation?.coordinate.longitude ?? 0,
            altitude: altitude,
            accuracy: horizontalAccuracy,
            speed: speed,
            heading: headingDegrees,
            timestamp: Date()
        )
    }
    
    /// Calculate distance from current location
    func distance(from coordinate: CLLocationCoordinate2D) -> Double? {
        guard let current = currentLocation else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return current.distance(from: location)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            print("📍 Authorization changed to: \(manager.authorizationStatus)")
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ Location authorized, starting tracking")
                self.startTracking()
            case .denied, .restricted:
                print("❌ Location access denied/restricted")
                self.stopTracking()
            case .notDetermined:
                print("⚠️ Location authorization not determined yet")
                break
            @unknown default:
                print("⚠️ Unknown authorization status")
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Validate the location
        guard location.coordinate.latitude != 0 || location.coordinate.longitude != 0,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 100 else { // Ignore very inaccurate locations
            print("⚠️ Ignoring invalid or inaccurate location: \(location)")
            return
        }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.speed = max(0, location.speed) // Negative means invalid
            print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude) - Accuracy: \(location.horizontalAccuracy)m")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.heading = newHeading
            print("🧭 Heading updated: \(newHeading.trueHeading)°")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.lastError = error
        }
        print("❌ Location error: \(error.localizedDescription)")
        
        // Provide more specific error information
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("❌ Location access denied by user")
            case .locationUnknown:
                print("⚠️ Location currently unknown, will keep trying...")
            case .network:
                print("❌ Network error while determining location")
            default:
                print("❌ Other location error: \(clError.code.rawValue)")
            }
        }
    }
}

// MARK: - Location Data Structure
struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let accuracy: Double
    let speed: Double
    let heading: Double
    let timestamp: Date
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
