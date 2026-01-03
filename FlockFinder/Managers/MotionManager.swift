import Foundation
import CoreMotion
import Combine

/// Motion Manager for accelerometer and motion tracking
/// 
/// ⚠️ DEPRECATED: This class is no longer used in the app.
/// GPS/Location services alone provide sufficient heading and speed data.
/// Keeping this file for reference only - can be deleted.
/// 
/// Motion tracking was originally intended to improve heading accuracy,
/// but GPS course (direction of travel) is more reliable for vehicle movement.
class MotionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isTracking = false
    @Published var acceleration: CMAcceleration = CMAcceleration()
    @Published var rotationRate: CMRotationRate = CMRotationRate()
    @Published var attitude: CMAttitude?
    @Published var gravity: CMAcceleration = CMAcceleration()
    @Published var userAcceleration: CMAcceleration = CMAcceleration()
    @Published var heading: Double = 0
    @Published var activityType: String = "Unknown"
    @Published var isMoving = false
    
    // MARK: - Computed Properties
    var accelerationMagnitude: Double {
        sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
    }
    
    var userAccelerationMagnitude: Double {
        sqrt(pow(userAcceleration.x, 2) + pow(userAcceleration.y, 2) + pow(userAcceleration.z, 2))
    }
    
    var pitch: Double {
        attitude?.pitch ?? 0
    }
    
    var roll: Double {
        attitude?.roll ?? 0
    }
    
    var yaw: Double {
        attitude?.yaw ?? 0
    }
    
    // MARK: - Private Properties
    private let motionManager = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let updateInterval: TimeInterval = 0.1 // 10 Hz
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Check if motion services are available
    var isAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }
    
    var isAccelerometerAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }
    
    var isGyroAvailable: Bool {
        motionManager.isGyroAvailable
    }
    
    var isActivityAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }
    
    /// Start motion tracking
    func startTracking() {
        guard isAvailable else {
            print("Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = updateInterval
        
        motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: .main
        ) { [weak self] motion, error in
            guard let motion = motion, error == nil else {
                print("Motion error: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            self?.processMotionData(motion)
        }
        
        // Start activity tracking
        if isActivityAvailable {
            startActivityTracking()
        }
        
        isTracking = true
    }
    
    /// Stop motion tracking
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
        activityManager.stopActivityUpdates()
        isTracking = false
    }
    
    /// Get current motion data for logging
    func getMotionData() -> MotionData {
        return MotionData(
            accelerationX: userAcceleration.x,
            accelerationY: userAcceleration.y,
            accelerationZ: userAcceleration.z,
            rotationX: rotationRate.x,
            rotationY: rotationRate.y,
            rotationZ: rotationRate.z,
            pitch: pitch,
            roll: roll,
            yaw: yaw,
            heading: heading,
            activityType: activityType,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func processMotionData(_ motion: CMDeviceMotion) {
        DispatchQueue.main.async {
            self.attitude = motion.attitude
            self.gravity = motion.gravity
            self.userAcceleration = motion.userAcceleration
            self.rotationRate = motion.rotationRate
            self.heading = motion.heading
            
            // Detect if device is moving based on acceleration
            self.isMoving = self.userAccelerationMagnitude > 0.1
        }
    }
    
    private func startActivityTracking() {
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            
            DispatchQueue.main.async {
                self?.activityType = self?.classifyActivity(activity) ?? "Unknown"
            }
        }
    }
    
    private func classifyActivity(_ activity: CMMotionActivity) -> String {
        if activity.stationary {
            return "Stationary"
        } else if activity.walking {
            return "Walking"
        } else if activity.running {
            return "Running"
        } else if activity.cycling {
            return "Cycling"
        } else if activity.automotive {
            return "Driving"
        } else {
            return "Unknown"
        }
    }
}

// MARK: - Motion Data Structure
/// ⚠️ DEPRECATED: No longer used - GPS provides heading and speed
struct MotionData: Codable {
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
    let pitch: Double
    let roll: Double
    let yaw: Double
    let heading: Double
    let activityType: String
    let timestamp: Date
    
    var accelerationMagnitude: Double {
        sqrt(pow(accelerationX, 2) + pow(accelerationY, 2) + pow(accelerationZ, 2))
    }
}
