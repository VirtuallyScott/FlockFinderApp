import Foundation
import CoreBluetooth
import Combine

/// BLE Manager for connecting to FlockFinder ESP32 device
class BLEManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var latestDetection: DetectionData?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var rssi: Int = 0
    @Published var recentDetections: [FlockDetection] = []
    @Published var statusMessage: String = "Ready to scan"
    @Published var bluetoothState: CBManagerState = .unknown
    
    // MARK: - Detection callback
    var onDetection: ((DetectionData) -> Void)?
    var onRawData: ((Data, String) -> Void)? // Callback for raw BLE data (data, description)
    
    // MARK: - BLE UUIDs - Must match ESP32 firmware exactly
    static let flockServiceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    static let detectionCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    static let commandCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a9")
    static let streamCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26aa")  // Live scan stream
    static let configCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26ab")  // Configuration transfer
    
    // Device name patterns to look for (case insensitive)
    static let deviceNamePatterns = ["flockfinder", "flock", "feather", "esp32", "s3"]
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var detectionCharacteristic: CBCharacteristic?
    private var commandCharacteristic: CBCharacteristic?
    private var streamCharacteristic: CBCharacteristic?  // Live scan stream
    private var configCharacteristic: CBCharacteristic?  // Configuration transfer
    
    // Config transfer state
    private var configReceiveBuffer: String = ""
    private var configTransferInProgress: Bool = false
    var onConfigReceived: ((String) -> Void)?  // Callback when config received from ESP32
    var onConfigSyncComplete: ((Bool, String?) -> Void)?  // Callback when config sync completes
    private var rssiTimer: Timer?
    private var scanTimer: Timer?
    private var peripheralReferences: [UUID: CBPeripheral] = [:] // Keep strong references to prevent deallocation
    
    // MARK: - Discovered Device wrapper
    struct DiscoveredDevice: Identifiable, Equatable {
        let id: UUID
        let peripheral: CBPeripheral
        let name: String
        var rssi: Int
        let hasFlockService: Bool
        let advertisementData: [String: Any]
        
        static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - Connection State
    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case scanning = "Scanning..."
        case connecting = "Connecting..."
        case connected = "Connected"
        case discovering = "Discovering Services..."
        case bluetoothOff = "Bluetooth Off"
        case unauthorized = "Bluetooth Unauthorized"
    }
    
    // MARK: - Detection Data Structure
    struct DetectionData: Codable, Identifiable {
        let id: UUID
        let deviceType: String
        let macAddress: String?
        let ssid: String?
        let rssi: Int
        let confidence: Double
        let timestamp: Date
        
        init(from json: [String: Any]) {
            self.id = UUID()
            self.deviceType = json["type"] as? String ?? "unknown"
            self.macAddress = json["mac"] as? String
            self.ssid = json["ssid"] as? String
            self.rssi = json["rssi"] as? Int ?? -100
            self.confidence = json["confidence"] as? Double ?? 0.5
            self.timestamp = Date()
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: [
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
        print("[BLE] 🚀 BLEManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for FlockFinder devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("[BLE] ❌ Cannot scan - Bluetooth state: \(centralManager.state.rawValue)")
            statusMessage = "Bluetooth not available"
            if centralManager.state == .poweredOff {
                connectionState = .bluetoothOff
            } else if centralManager.state == .unauthorized {
                connectionState = .unauthorized
            }
            return
        }
        
        // Clear previous results
        discoveredDevices.removeAll()
        peripheralReferences.removeAll()
        isScanning = true
        connectionState = .scanning
        statusMessage = "Scanning for FlockFinder..."
        
        print("[BLE] 🔍 ========================================")
        print("[BLE] 🔍 Starting BLE scan")
        print("[BLE] 🔍 Service UUID: \(Self.flockServiceUUID.uuidString)")
        print("[BLE] 🔍 Name patterns: \(Self.deviceNamePatterns)")
        print("[BLE] 🔍 ========================================")
        
        // Scan for ALL devices - this catches devices even if service UUID isn't in advertisement
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true  // Get RSSI updates
            ]
        )
        
        // Set a timer to stop scanning after 60 seconds
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            print("[BLE] ⏱️ Scan timeout after 60 seconds")
            self?.stopScanning()
        }
    }
    
    /// Stop scanning
    func stopScanning() {
        centralManager.stopScan()
        scanTimer?.invalidate()
        scanTimer = nil
        isScanning = false
        
        if connectionState == .scanning {
            connectionState = .disconnected
            statusMessage = discoveredDevices.isEmpty ? "No devices found" : "Scan complete - \(discoveredDevices.count) device(s)"
        }
        print("[BLE] 🛑 Stopped scanning. Found \(discoveredDevices.count) device(s)")
    }
    
    /// Connect to a discovered device
    func connect(to device: DiscoveredDevice) {
        print("[BLE] 🔗 Connecting to: \(device.name) (UUID: \(device.id))")
        stopScanning()
        connectionState = .connecting
        statusMessage = "Connecting to \(device.name)..."
        
        // Ensure we have a strong reference
        peripheralReferences[device.peripheral.identifier] = device.peripheral
        centralManager.connect(device.peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }
    
    /// Connect to a CBPeripheral directly
    func connect(to peripheral: CBPeripheral) {
        let name = peripheral.name ?? "Unknown"
        print("[BLE] 🔗 Connecting to peripheral: \(name)")
        stopScanning()
        connectionState = .connecting
        statusMessage = "Connecting to \(name)..."
        
        peripheralReferences[peripheral.identifier] = peripheral
        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }
    
    /// Disconnect from current device
    func disconnect() {
        if let peripheral = connectedDevice {
            print("[BLE] 🔌 Disconnecting from: \(peripheral.name ?? "Unknown")")
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanup()
    }
    
    /// Send command to device
    func sendCommand(_ command: String) {
        guard let characteristic = commandCharacteristic,
              let peripheral = connectedDevice,
              let data = command.data(using: .utf8) else {
            print("[BLE] ❌ Cannot send command - not connected")
            return
        }
        
        print("[BLE] 📤 Sending command: \(command)")
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    // MARK: - Configuration Sync Methods
    
    /// Request current configuration from ESP32
    func requestConfiguration() {
        sendCommand("GET_CONFIG")
    }
    
    /// Tell ESP32 to save current config to flash
    func saveConfigurationToFlash() {
        sendCommand("SAVE_CONFIG")
    }
    
    /// Tell ESP32 to reset config to defaults
    func resetConfigurationToDefaults() {
        sendCommand("RESET_CONFIG")
    }
    
    /// Send configuration to ESP32
    func sendConfiguration(_ config: ScanConfiguration) {
        guard let configCharacteristic = configCharacteristic,
              let peripheral = connectedDevice else {
            print("[BLE] ❌ Cannot send config - not connected or config characteristic not found")
            onConfigSyncComplete?(false, "Not connected")
            return
        }
        
        guard let jsonString = config.toJsonString() else {
            print("[BLE] ❌ Failed to serialize configuration")
            onConfigSyncComplete?(false, "Serialization failed")
            return
        }
        
        print("[BLE] 📤 Sending configuration (\(jsonString.count) bytes)")
        
        // Use chunked transfer if config is large
        let maxChunkSize = 480  // Leave room for BLE overhead
        
        if jsonString.count <= maxChunkSize {
            // Single packet transfer
            if let data = jsonString.data(using: .utf8) {
                peripheral.writeValue(data, for: configCharacteristic, type: .withResponse)
            }
        } else {
            // Chunked transfer
            sendConfigChunked(jsonString, to: peripheral, characteristic: configCharacteristic)
        }
    }
    
    /// Send configuration in chunks for large configs
    private func sendConfigChunked(_ json: String, to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let chunkSize = 480
        var offset = 0
        
        // Send start marker
        if let startData = "CONFIG_START".data(using: .utf8) {
            peripheral.writeValue(startData, for: characteristic, type: .withResponse)
        }
        
        // Send chunks with slight delay to prevent buffer overflow
        let chunks = stride(from: 0, to: json.count, by: chunkSize).map {
            String(json[json.index(json.startIndex, offsetBy: $0)..<json.index(json.startIndex, offsetBy: min($0 + chunkSize, json.count))])
        }
        
        for (index, chunk) in chunks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                if let data = chunk.data(using: .utf8) {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                    print("[BLE] 📤 Sent config chunk \(index + 1)/\(chunks.count)")
                }
            }
        }
        
        // Send end marker after all chunks
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(chunks.count) * 0.05 + 0.1) {
            if let endData = "CONFIG_END".data(using: .utf8) {
                peripheral.writeValue(endData, for: characteristic, type: .withResponse)
                print("[BLE] 📤 Sent config end marker")
            }
        }
    }
    
    /// Process configuration data received from ESP32
    private func processConfigData(_ data: Data) {
        guard let dataString = String(data: data, encoding: .utf8) else {
            print("[BLE] ❌ Failed to decode config data as UTF-8")
            return
        }
        
        print("[BLE] 📥 Config data received: \(dataString.prefix(100))...")
        
        // Check for chunked transfer markers
        if dataString.hasPrefix("CONFIG_START") {
            configReceiveBuffer = ""
            configTransferInProgress = true
            print("[BLE] 📥 Starting chunked config receive")
            return
        }
        
        if dataString == "CONFIG_END" {
            configTransferInProgress = false
            print("[BLE] 📥 Config receive complete (\(configReceiveBuffer.count) bytes)")
            onConfigReceived?(configReceiveBuffer)
            configReceiveBuffer = ""
            return
        }
        
        // Check for response messages
        if dataString.hasPrefix("{") && dataString.contains("\"response\"") {
            // This is a response message, not config data
            if let responseData = dataString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let message = json["message"] as? String
                onConfigSyncComplete?(success, message)
            }
            return
        }
        
        if configTransferInProgress {
            // Append chunk to buffer
            configReceiveBuffer += dataString
            print("[BLE] 📥 Buffered chunk, total: \(configReceiveBuffer.count) bytes")
            return
        }
        
        // Single-packet config (starts with {)
        if dataString.hasPrefix("{") {
            print("[BLE] 📥 Received single-packet config")
            onConfigReceived?(dataString)
        }
    }
    
    /// Check if config characteristic is available
    var hasConfigSupport: Bool {
        return configCharacteristic != nil
    }
        }
        
        print("[BLE] 📤 Sending command: \(command)")
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// Request RSSI update
    func readRSSI() {
        connectedDevice?.readRSSI()
    }
    
    // MARK: - Private Methods
    
    private func cleanup() {
        isConnected = false
        connectedDevice = nil
        detectionCharacteristic = nil
        commandCharacteristic = nil
        streamCharacteristic = nil
        configCharacteristic = nil
        configReceiveBuffer = ""
        configTransferInProgress = false
        connectionState = .disconnected
        statusMessage = "Disconnected"
        rssiTimer?.invalidate()
        rssiTimer = nil
    }
    
    private func startRSSITimer() {
        rssiTimer?.invalidate()
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.readRSSI()
        }
    }
    
    private func processDetectionData(_ data: Data) {
        // Notify raw data callback for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            onRawData?(data, "Detection: \(jsonString)")
        }
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            print("[BLE] ❌ Failed to decode detection data as UTF-8")
            return
        }
        
        print("[BLE] 📥 Received detection: \(jsonString)")
        
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("[BLE] ❌ Failed to parse detection JSON")
            return
        }
        
        let detection = DetectionData(from: json)
        
        DispatchQueue.main.async { [weak self] in
            self?.latestDetection = detection
            self?.onDetection?(detection)
        }
    }
    
    private func processStreamData(_ data: Data) {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            print("[BLE] ❌ Failed to decode stream data as UTF-8")
            return
        }
        
        // Send to raw data callback for debug stream view
        onRawData?(data, jsonString)
        
        // Parse for logging
        if let jsonData = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let event = json["evt"] as? String {
            switch event {
            case "wifi_scan":
                let ssid = json["ssid"] as? String ?? ""
                let mac = json["mac"] as? String ?? ""
                let rssi = json["rssi"] as? Int ?? 0
                print("[BLE] 📡 WiFi: \(ssid.isEmpty ? "(hidden)" : ssid) | \(mac) | \(rssi)dBm")
            case "ble_scan":
                let name = json["name"] as? String ?? ""
                let mac = json["mac"] as? String ?? ""
                let rssi = json["rssi"] as? Int ?? 0
                print("[BLE] 📱 BLE: \(name.isEmpty ? "(no name)" : name) | \(mac) | \(rssi)dBm")
            case "channel":
                let ch = json["ch"] as? Int ?? 0
                print("[BLE] 📻 Channel hop: \(ch)")
            case "status":
                let msg = json["msg"] as? String ?? ""
                print("[BLE] ℹ️ Status: \(msg)")
            default:
                print("[BLE] 📦 Stream: \(jsonString)")
            }
        }
    }
    
    private func isFlockFinderDevice(name: String?, advertisementData: [String: Any]) -> Bool {
        // Check advertised services first
        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            if services.contains(Self.flockServiceUUID) {
                return true
            }
        }
        
        // Check device name from peripheral or advertisement
        let deviceName = name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        let lowercaseName = deviceName.lowercased()
        
        for pattern in Self.deviceNamePatterns {
            if lowercaseName.contains(pattern) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        
        switch central.state {
        case .poweredOn:
            print("[BLE] ✅ Bluetooth powered on - ready to scan")
            statusMessage = "Ready to scan"
            connectionState = .disconnected
        case .poweredOff:
            print("[BLE] ❌ Bluetooth powered off")
            statusMessage = "Turn on Bluetooth in Settings"
            connectionState = .bluetoothOff
            cleanup()
        case .unauthorized:
            print("[BLE] ⚠️ Bluetooth unauthorized - check app permissions in Settings")
            statusMessage = "Bluetooth access denied - check Settings"
            connectionState = .unauthorized
        case .unsupported:
            print("[BLE] ❌ Bluetooth not supported on this device")
            statusMessage = "Bluetooth not supported"
        case .resetting:
            print("[BLE] ⏳ Bluetooth resetting...")
            statusMessage = "Bluetooth resetting..."
        case .unknown:
            print("[BLE] ❓ Bluetooth state unknown")
            statusMessage = "Checking Bluetooth..."
        @unknown default:
            print("[BLE] ❓ Unknown Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let hasFlockService = services.contains(Self.flockServiceUUID)
        
        // Check if this is a FlockFinder device
        guard isFlockFinderDevice(name: peripheral.name, advertisementData: advertisementData) else {
            return // Skip non-FlockFinder devices silently
        }
        
        print("[BLE] 📡 ----------------------------------------")
        print("[BLE] 📡 Found potential FlockFinder device!")
        print("[BLE] 📡 Name: '\(deviceName)' (empty=no name)")
        print("[BLE] 📡 UUID: \(peripheral.identifier)")
        print("[BLE] 📡 RSSI: \(RSSI) dBm")
        print("[BLE] 📡 Advertised services: \(services.map { $0.uuidString })")
        print("[BLE] 📡 Has FlockFinder service UUID: \(hasFlockService)")
        print("[BLE] 📡 ----------------------------------------")
        
        // Keep strong reference to peripheral to prevent deallocation
        peripheralReferences[peripheral.identifier] = peripheral
        
        let displayName = deviceName.isEmpty ? "FlockFinder Device" : deviceName
        
        // Check if already in list
        if let existingIndex = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Update existing device with new RSSI
            var updated = discoveredDevices[existingIndex]
            updated.rssi = RSSI.intValue
            discoveredDevices[existingIndex] = DiscoveredDevice(
                id: peripheral.identifier,
                peripheral: peripheral,
                name: displayName,
                rssi: RSSI.intValue,
                hasFlockService: hasFlockService,
                advertisementData: advertisementData
            )
        } else {
            // Add new device
            let device = DiscoveredDevice(
                id: peripheral.identifier,
                peripheral: peripheral,
                name: displayName,
                rssi: RSSI.intValue,
                hasFlockService: hasFlockService,
                advertisementData: advertisementData
            )
            discoveredDevices.append(device)
            statusMessage = "Found: \(displayName)"
            
            print("[BLE] ✅ Added to discovered list (total: \(discoveredDevices.count))")
        }
        
        // Auto-connect if this has the FlockFinder service UUID
        if hasFlockService && connectedDevice == nil && connectionState == .scanning {
            print("[BLE] 🎯 Auto-connecting - device has FlockFinder service UUID!")
            let device = DiscoveredDevice(
                id: peripheral.identifier,
                peripheral: peripheral,
                name: displayName,
                rssi: RSSI.intValue,
                hasFlockService: hasFlockService,
                advertisementData: advertisementData
            )
            connect(to: device)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BLE] ✅ Connected to: \(peripheral.name ?? "Unknown")")
        
        connectedDevice = peripheral
        peripheral.delegate = self
        connectionState = .discovering
        statusMessage = "Discovering services..."
        
        // Discover our specific service
        peripheral.discoverServices([Self.flockServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[BLE] ❌ Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "unknown error")")
        statusMessage = "Connection failed - try again"
        cleanup()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[BLE] 🔌 Disconnected from \(peripheral.name ?? "Unknown")")
        if let error = error {
            print("[BLE]    Reason: \(error.localizedDescription)")
            statusMessage = "Disconnected unexpectedly"
        } else {
            statusMessage = "Disconnected"
        }
        cleanup()
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("[BLE] ❌ Error discovering services: \(error.localizedDescription)")
            statusMessage = "Service discovery failed"
            return
        }
        
        guard let services = peripheral.services else {
            print("[BLE] ❌ No services found on device")
            statusMessage = "No services found"
            return
        }
        
        print("[BLE] 📋 Discovered \(services.count) service(s):")
        
        for service in services {
            print("[BLE]    - \(service.uuid.uuidString)")
            if service.uuid == Self.flockServiceUUID {
                print("[BLE] ✅ Found FlockFinder service!")
                statusMessage = "Found FlockFinder service"
                peripheral.discoverCharacteristics(
                    [Self.detectionCharacteristicUUID, Self.commandCharacteristicUUID, Self.streamCharacteristicUUID, Self.configCharacteristicUUID],
                    for: service
                )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("[BLE] ❌ Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("[BLE] ❌ No characteristics found")
            return
        }
        
        print("[BLE] 📋 Discovered \(characteristics.count) characteristic(s):")
        
        for characteristic in characteristics {
            print("[BLE]    - \(characteristic.uuid.uuidString)")
            
            switch characteristic.uuid {
            case Self.detectionCharacteristicUUID:
                print("[BLE] ✅ Found detection characteristic - subscribing to notifications")
                detectionCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                
            case Self.commandCharacteristicUUID:
                print("[BLE] ✅ Found command characteristic")
                commandCharacteristic = characteristic
                
            case Self.streamCharacteristicUUID:
                print("[BLE] ✅ Found stream characteristic - subscribing to notifications")
                streamCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                
            case Self.configCharacteristicUUID:
                print("[BLE] ✅ Found config characteristic - subscribing to notifications")
                configCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                
            default:
                break
            }
        }
        
        // Connection complete when we have the detection characteristic
        if detectionCharacteristic != nil {
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = true
                self?.connectionState = .connected
                self?.statusMessage = "Connected to FlockFinder!"
                self?.startRSSITimer()
                print("[BLE] 🎉 Connection complete - ready to receive detections!")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BLE] ❌ Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        switch characteristic.uuid {
        case Self.detectionCharacteristicUUID:
            processDetectionData(data)
            
        case Self.streamCharacteristicUUID:
            processStreamData(data)
            
        case Self.configCharacteristicUUID:
            processConfigData(data)
            
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.rssi = RSSI.intValue
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BLE] ❌ Error enabling notifications: \(error.localizedDescription)")
            return
        }
        
        print("[BLE] 🔔 Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(characteristic.uuid.uuidString)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BLE] ❌ Error writing to characteristic: \(error.localizedDescription)")
        } else {
            print("[BLE] ✅ Command sent successfully")
        }
    }
}
