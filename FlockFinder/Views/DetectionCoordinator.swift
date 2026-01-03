import Foundation
import Combine
import UIKit

/// Coordinates detection handling between BLE, database, and audio alerts
class DetectionCoordinator: ObservableObject {
    
    // MARK: - Dependencies
    private let bleManager: BLEManager
    private let databaseManager: DatabaseManager
    private let locationManager: LocationManager
    private let audioManager = AudioAlertManager.shared
    private let appSettings = AppSettings.shared
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(bleManager: BLEManager, databaseManager: DatabaseManager, locationManager: LocationManager) {
        self.bleManager = bleManager
        self.databaseManager = databaseManager
        self.locationManager = locationManager
        
        setupDetectionHandler()
    }
    
    // MARK: - Setup
    
    private func setupDetectionHandler() {
        // Set up the BLE detection callback
        bleManager.onDetection = { [weak self] detectionData in
            self?.handleDetection(detectionData)
        }
        
        print("🎯 DetectionCoordinator initialized and listening for detections")
    }
    
    // MARK: - Detection Handling
    
    private func handleDetection(_ bleData: BLEManager.DetectionData) {
        print("🎯 Detection received: \(bleData.deviceType)")
        
        // Get current location data
        let locationData = locationManager.getLocationData()
        
        // Create FlockDetection model
        let detection = FlockDetection(bleData: bleData, location: locationData)
        
        // Check if detection meets minimum confidence threshold
        guard detection.confidence >= appSettings.minimumConfidence else {
            print("⚠️ Detection below confidence threshold (\(detection.confidence) < \(appSettings.minimumConfidence))")
            return
        }
        
        // Save to database
        databaseManager.insertDetection(detection)
        print("💾 Detection saved to database")
        
        // Schedule automatic iCloud backup (throttled to max once per hour)
        iCloudManager.shared.scheduleAutomaticBackup()
        
        // Add to recent detections in BLE manager
        DispatchQueue.main.async { [weak self] in
            self?.bleManager.recentDetections.insert(detection, at: 0)
            // Keep only last 10 detections
            if self?.bleManager.recentDetections.count ?? 0 > 10 {
                self?.bleManager.recentDetections = Array(self?.bleManager.recentDetections.prefix(10) ?? [])
            }
        }
        
        // Play audio alert if enabled
        if appSettings.audibleAlertsEnabled {
            audioManager.playDetectionAlert()
            print("🔊 Played audio alert for detection")
        }
        
        // Trigger haptic feedback if enabled
        if appSettings.hapticFeedback {
            triggerHapticFeedback()
        }
        
        // TODO: Send notification if enabled
        if appSettings.notificationsEnabled {
            // scheduleDetectionNotification(detection)
        }
        
        print("✅ Detection handling complete")
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
