import SwiftUI
import MapKit
import CoreBluetooth

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var databaseManager: DatabaseManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Live Scanner View
            ScannerView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Scanner")
                }
                .tag(0)
            
            // Map View
            MapView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(1)
            
            // Detection History
            HistoryView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("History")
                }
                .tag(2)
            
            // Settings
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .onAppear {
            locationManager.requestAuthorization()
        }
    }
}

// MARK: - Scanner View
struct ScannerView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var showingDebugStream = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status Card
                ConnectionStatusCard(
                    connectionState: bleManager.connectionState,
                    deviceName: bleManager.connectedDevice?.name,
                    statusMessage: bleManager.statusMessage
                )
                
                // Discovered Devices (show when scanning or have devices)
                if bleManager.isScanning || !bleManager.discoveredDevices.isEmpty {
                    DiscoveredDevicesCard(
                        devices: bleManager.discoveredDevices,
                        isScanning: bleManager.isScanning,
                        onDeviceSelected: { device in
                            bleManager.connect(to: device)
                        }
                    )
                }
                
                // Current Location Card
                LocationCard(
                    latitude: locationManager.currentLocation?.coordinate.latitude ?? 0,
                    longitude: locationManager.currentLocation?.coordinate.longitude ?? 0,
                    speed: locationManager.speed,
                    heading: locationManager.headingDegrees
                )
                
                // Recent Detections
                RecentDetectionsCard(detections: bleManager.recentDetections)
                
                Spacer()
                
                // Connect/Disconnect Button
                Button(action: {
                    if bleManager.isConnected {
                        bleManager.disconnect()
                    } else if bleManager.isScanning {
                        bleManager.stopScanning()
                    } else {
                        bleManager.startScanning()
                    }
                }) {
                    HStack {
                        if bleManager.isScanning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: buttonIcon)
                        }
                        Text(buttonText)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(buttonColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(bleManager.connectionState == .connecting || 
                          bleManager.connectionState == .discovering ||
                          bleManager.connectionState == .bluetoothOff ||
                          bleManager.connectionState == .unauthorized)
            }
            .padding()
            .navigationTitle("FlockFinder")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bleManager.isConnected {
                        Button {
                            showingDebugStream = true
                        } label: {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDebugStream) {
                DebugStreamView()
            }
        }
    }
    
    private var buttonIcon: String {
        switch bleManager.connectionState {
        case .disconnected:
            return "antenna.radiowaves.left.and.right"
        case .scanning:
            return "stop.fill"
        case .connecting, .discovering:
            return "hourglass"
        case .connected:
            return "antenna.radiowaves.left.and.right.slash"
        case .bluetoothOff:
            return "exclamationmark.triangle"
        case .unauthorized:
            return "lock"
        }
    }
    
    private var buttonText: String {
        switch bleManager.connectionState {
        case .disconnected:
            return "Scan for FlockFinder"
        case .scanning:
            return "Stop Scanning"
        case .connecting:
            return "Connecting..."
        case .discovering:
            return "Setting up..."
        case .connected:
            return "Disconnect"
        case .bluetoothOff:
            return "Turn On Bluetooth"
        case .unauthorized:
            return "Enable Bluetooth Access"
        }
    }
    
    private var buttonColor: Color {
        switch bleManager.connectionState {
        case .disconnected:
            return .blue
        case .scanning:
            return .orange
        case .connecting, .discovering:
            return .gray
        case .connected:
            return .red
        case .bluetoothOff, .unauthorized:
            return .gray
        }
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    let connectionState: BLEManager.ConnectionState
    let deviceName: String?
    let statusMessage: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(connectionState.rawValue)
                    .font(.headline)
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let name = deviceName, connectionState == .connected {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            if connectionState == .connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if connectionState == .scanning || connectionState == .connecting || connectionState == .discovering {
                ProgressView()
                    .scaleEffect(0.8)
            } else if connectionState == .bluetoothOff {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else if connectionState == .unauthorized {
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch connectionState {
        case .connected:
            return .green
        case .scanning, .connecting, .discovering:
            return .orange
        case .disconnected:
            return .gray
        case .bluetoothOff, .unauthorized:
            return .red
        }
    }
}

// MARK: - Discovered Devices Card
struct DiscoveredDevicesCard: View {
    let devices: [BLEManager.DiscoveredDevice]
    let isScanning: Bool
    let onDeviceSelected: (BLEManager.DiscoveredDevice) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Discovered Devices")
                    .font(.headline)
                Spacer()
                if isScanning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !devices.isEmpty {
                    Text("\(devices.count) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if devices.isEmpty {
                VStack(spacing: 4) {
                    Text(isScanning ? "Searching for FlockFinder..." : "No devices found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if isScanning {
                        Text("Make sure the Feather is powered on")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                ForEach(devices) { device in
                    Button(action: {
                        onDeviceSelected(device)
                    }) {
                        HStack {
                            Image(systemName: device.hasFlockService ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                                .foregroundColor(device.hasFlockService ? .green : .blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .foregroundColor(.primary)
                                    .fontWeight(device.hasFlockService ? .semibold : .regular)
                                HStack(spacing: 8) {
                                    Text("\(device.rssi) dBm")
                                    if device.hasFlockService {
                                        Text("• FlockFinder")
                                            .foregroundColor(.green)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Location Card
struct LocationCard: View {
    let latitude: Double
    let longitude: Double
    let speed: Double
    let heading: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Location")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Lat: \(latitude, specifier: "%.6f")")
                    Text("Lon: \(longitude, specifier: "%.6f")")
                }
                .font(.system(.caption, design: .monospaced))
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Speed: \(max(0, speed * 2.237), specifier: "%.1f") mph")
                    Text("Heading: \(heading, specifier: "%.0f")°")
                }
                .font(.system(.caption, design: .monospaced))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Recent Detections Card
struct RecentDetectionsCard: View {
    let detections: [FlockDetection]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Detections")
                    .font(.headline)
                Spacer()
                Text("\(detections.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(detections.isEmpty ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            if detections.isEmpty {
                Text("No detections yet...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(detections.prefix(3)) { detection in
                    DetectionRow(detection: detection)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Detection Row
struct DetectionRow: View {
    let detection: FlockDetection
    
    var body: some View {
        HStack {
            Image(systemName: detection.deviceType.icon)
                .foregroundColor(.red)
            
            VStack(alignment: .leading) {
                Text(detection.deviceType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detection.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(detection.rssi) dBm")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(BLEManager())
        .environmentObject(LocationManager())
        .environmentObject(DatabaseManager.shared)
}
