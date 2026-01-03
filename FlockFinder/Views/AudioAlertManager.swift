import Foundation
import AVFoundation
import UIKit

/// Manages audio alerts for Flock device detections
/// Supports playback to iPhone speakers, CarPlay, and Bluetooth audio devices
class AudioAlertManager: NSObject, ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = AudioAlertManager()
    
    // MARK: - Alert Sounds
    enum AlertSound: String, CaseIterable, Identifiable {
        case chime = "Chime"
        case bell = "Bell"
        case ping = "Ping"
        case alert = "Alert"
        case horn = "Horn"
        case sonar = "Sonar"
        
        var id: String { rawValue }
        
        var systemSoundID: SystemSoundID {
            switch self {
            case .chime: return 1253  // Anticipate.caf
            case .bell: return 1013   // news_flash.caf
            case .ping: return 1003   // sms-received1.caf
            case .alert: return 1005  // sms-received3.caf
            case .horn: return 1009   // alarm.caf
            case .sonar: return 1070  // begin_record.caf
            }
        }
        
        var description: String {
            switch self {
            case .chime: return "Gentle chime sound"
            case .bell: return "Classic notification bell"
            case .ping: return "Quick ping tone"
            case .alert: return "Alert notification"
            case .horn: return "Attention-grabbing horn"
            case .sonar: return "Sonar-like beep"
            }
        }
    }
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    /// Configure audio session for alerts that can play through CarPlay and Bluetooth
    private func setupAudioSession() {
        do {
            // Use .playback category to enable audio output to all connected devices
            // .mixWithOthers allows alerts to play alongside other audio (like music or navigation)
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            
            try audioSession.setActive(true)
            
            print("🔊 Audio session configured for alerts")
            logAvailableOutputs()
            
        } catch {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    /// Log available audio output routes (for debugging)
    private func logAvailableOutputs() {
        let outputs = audioSession.currentRoute.outputs
        print("🔊 Available audio outputs:")
        for output in outputs {
            print("   - \(output.portType.rawValue): \(output.portName)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Play an alert sound with specified volume
    /// - Parameters:
    ///   - sound: The alert sound to play
    ///   - volume: Volume level (0.0 to 1.0)
    func playAlert(sound: AlertSound, volume: Double = 0.7) {
        guard AppSettings.shared.audibleAlertsEnabled else {
            print("🔇 Audible alerts are disabled")
            return
        }
        
        // Ensure audio session is active
        activateAudioSession()
        
        // Use system sound for reliability across all output devices
        playSystemSound(sound.systemSoundID, volume: volume)
        
        print("🔊 Playing alert: \(sound.rawValue) at volume \(String(format: "%.0f%%", volume * 100))")
    }
    
    /// Play alert using system sound (most reliable for CarPlay/Bluetooth)
    private func playSystemSound(_ soundID: SystemSoundID, volume: Double) {
        // Note: System sounds play at system volume level and cannot be individually adjusted
        // The volume parameter is accepted for API consistency but not used with system sounds
        
        // Play the sound
        AudioServicesPlaySystemSound(soundID)
        
        // Optional: Add vibration on iPhone for additional feedback
        if AppSettings.shared.hapticFeedback {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    /// Play a custom audio file alert (alternative method)
    /// - Parameters:
    ///   - fileName: Name of the audio file in the bundle
    ///   - volume: Volume level (0.0 to 1.0)
    func playCustomAlert(fileName: String, volume: Double = 0.7) {
        guard AppSettings.shared.audibleAlertsEnabled else {
            print("🔇 Audible alerts are disabled")
            return
        }
        
        activateAudioSession()
        
        // Find the audio file in the bundle
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("❌ Audio file not found: \(fileName)")
            return
        }
        
        do {
            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = Float(max(0.0, min(1.0, volume)))
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            print("🔊 Playing custom alert: \(fileName)")
        } catch {
            print("❌ Failed to play audio: \(error.localizedDescription)")
        }
    }
    
    /// Activate audio session before playing sounds
    private func activateAudioSession() {
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Failed to activate audio session: \(error.localizedDescription)")
        }
    }
    
    /// Stop currently playing alert
    func stopAlert() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    /// Test the selected alert sound
    func testAlert() {
        let soundName = AppSettings.shared.alertSoundName
        let volume = AppSettings.shared.alertVolume
        
        if let sound = AlertSound(rawValue: soundName) {
            playAlert(sound: sound, volume: volume)
        }
    }
    
    /// Play detection alert (called when a Flock device is detected)
    func playDetectionAlert() {
        let soundName = AppSettings.shared.alertSoundName
        let volume = AppSettings.shared.alertVolume
        
        if let sound = AlertSound(rawValue: soundName) {
            playAlert(sound: sound, volume: volume)
        }
    }
    
    // MARK: - Audio Route Monitoring
    
    /// Check if audio is currently routed to CarPlay
    var isConnectedToCarPlay: Bool {
        audioSession.currentRoute.outputs.contains { output in
            output.portType == .carAudio
        }
    }
    
    /// Check if audio is routed to Bluetooth
    var isConnectedToBluetooth: Bool {
        audioSession.currentRoute.outputs.contains { output in
            output.portType == .bluetoothA2DP || 
            output.portType == .bluetoothLE ||
            output.portType == .bluetoothHFP
        }
    }
    
    /// Get current audio output description
    var currentOutputDescription: String {
        let outputs = audioSession.currentRoute.outputs.map { $0.portName }
        return outputs.joined(separator: ", ")
    }
}

// MARK: - AVAudioSession Port Type Extensions
extension AVAudioSession.Port {
    var friendlyName: String {
        switch self {
        case .builtInSpeaker: return "iPhone Speaker"
        case .builtInReceiver: return "iPhone Earpiece"
        case .headphones: return "Headphones"
        case .bluetoothA2DP: return "Bluetooth Audio"
        case .bluetoothLE: return "Bluetooth LE"
        case .bluetoothHFP: return "Bluetooth Hands-Free"
        case .carAudio: return "CarPlay"
        case .airPlay: return "AirPlay"
        default: return rawValue
        }
    }
}
