import SwiftUI

@main
struct FlockFinderApp: App {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var databaseManager = DatabaseManager.shared
    @StateObject private var detectionCoordinator: DetectionCoordinator
    
    init() {
        // Create managers first
        let ble = BLEManager()
        let loc = LocationManager()
        let db = DatabaseManager.shared
        
        // Create state objects
        _bleManager = StateObject(wrappedValue: ble)
        _locationManager = StateObject(wrappedValue: loc)
        _databaseManager = StateObject(wrappedValue: db)
        
        // Create coordinator with dependencies
        _detectionCoordinator = StateObject(
            wrappedValue: DetectionCoordinator(
                bleManager: ble,
                databaseManager: db,
                locationManager: loc
            )
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(locationManager)
                .environmentObject(databaseManager)
                .environmentObject(detectionCoordinator)
        }
    }
}
