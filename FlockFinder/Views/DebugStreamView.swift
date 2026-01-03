import SwiftUI
import CoreBluetooth

/// Debug view for monitoring the live BLE data stream from ESP32
struct DebugStreamView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss
    
    @State private var streamLogs: [StreamLog] = []
    @State private var autoScroll = true
    @State private var showRawData = false
    @State private var filterType: LogType? = nil
    @State private var isPaused = false
    
    // Statistics
    @State private var totalPackets = 0
    @State private var detectionCount = 0
    @State private var errorCount = 0
    @State private var lastPacketTime: Date?
    
    enum LogType: String, CaseIterable {
        case detection = "Detection"
        case raw = "Raw Data"
        case error = "Error"
        case info = "Info"
        
        var icon: String {
            switch self {
            case .detection: return "antenna.radiowaves.left.and.right"
            case .raw: return "doc.text"
            case .error: return "exclamationmark.triangle"
            case .info: return "info.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .detection: return .green
            case .raw: return .blue
            case .error: return .red
            case .info: return .secondary
            }
        }
    }
    
    struct StreamLog: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: LogType
        let message: String
        let rawData: String?
    }
    
    var filteredLogs: [StreamLog] {
        if let filter = filterType {
            return streamLogs.filter { $0.type == filter }
        }
        return streamLogs
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                statsHeader
                
                Divider()
                
                // Filter Bar
                filterBar
                
                Divider()
                
                // Log Stream
                if filteredLogs.isEmpty {
                    emptyState
                } else {
                    logList
                }
            }
            .navigationTitle("Debug Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isPaused.toggle()
                        } label: {
                            Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                        }
                        
                        Button {
                            autoScroll.toggle()
                        } label: {
                            Label(
                                autoScroll ? "Disable Auto-Scroll" : "Enable Auto-Scroll",
                                systemImage: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle"
                            )
                        }
                        
                        Button {
                            showRawData.toggle()
                        } label: {
                            Label(
                                showRawData ? "Hide Raw Data" : "Show Raw Data",
                                systemImage: showRawData ? "eye.slash" : "eye"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            clearLogs()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                setupStreamMonitoring()
            }
            .onDisappear {
                // Clean up if needed
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack(spacing: 16) {
            VStack {
                Text("\(totalPackets)")
                    .font(.title2)
                    .bold()
                Text("Packets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 30)
            
            VStack {
                Text("\(detectionCount)")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.green)
                Text("Detections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 30)
            
            VStack {
                Text("\(errorCount)")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.red)
                Text("Errors")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 30)
            
            VStack {
                if let lastTime = lastPacketTime {
                    Text(timeSince(lastTime))
                        .font(.title3)
                        .bold()
                        .foregroundColor(.blue)
                } else {
                    Text("--")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.secondary)
                }
                Text("Last RX")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    count: streamLogs.count,
                    isSelected: filterType == nil,
                    color: .blue
                ) {
                    filterType = nil
                }
                
                ForEach(LogType.allCases, id: \.self) { type in
                    let count = streamLogs.filter { $0.type == type }.count
                    FilterChip(
                        title: type.rawValue,
                        count: count,
                        isSelected: filterType == type,
                        color: type.color
                    ) {
                        if filterType == type {
                            filterType = nil
                        } else {
                            filterType = type
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Log List
    
    private var logList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredLogs) { log in
                    LogRow(log: log, showRawData: showRawData)
                        .id(log.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: filteredLogs.count) { _ in
                if autoScroll, let lastLog = filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            if bleManager.isConnected {
                if isPaused {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Stream Paused")
                        .font(.headline)
                    Text("Tap the pause button to resume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                    Text("Waiting for data...")
                        .font(.headline)
                    Text("The ESP32 should send detection data when scanning")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Not Connected")
                    .font(.headline)
                Text("Connect to a FlockFinder device to see the data stream")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func setupStreamMonitoring() {
        // Add initial info log
        addLog(type: .info, message: "Debug stream started")
        
        if bleManager.isConnected {
            addLog(type: .info, message: "Connected to: \(bleManager.connectedDevice?.name ?? "Unknown")")
            addLog(type: .info, message: "Monitoring BLE characteristic: \(BLEManager.detectionCharacteristicUUID.uuidString)")
        } else {
            addLog(type: .info, message: "Not connected to any device")
        }
        
        // Monitor the BLE manager's detection callback
        bleManager.onDetection = { detection in
            self.handleDetection(detection)
        }
        
        // Monitor raw BLE data
        bleManager.onRawData = { data, description in
            self.handleRawData(data, description: description)
        }
        
        // Start a heartbeat timer to detect if scanning has stopped
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkHeartbeat()
        }
    }
    
    private func checkHeartbeat() {
        guard !isPaused, bleManager.isConnected else { return }
        
        if let lastTime = lastPacketTime {
            let timeSinceLastPacket = Date().timeIntervalSince(lastTime)
            if timeSinceLastPacket > 30 {
                addLog(
                    type: .info,
                    message: "⚠️ No data received for \(Int(timeSinceLastPacket))s. ESP32 may not be scanning or no devices detected nearby."
                )
            }
        }
    }
    
    private func handleRawData(_ data: Data, description: String) {
        guard !isPaused else { return }
        
        totalPackets += 1
        lastPacketTime = Date()
        
        let hexString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
        let rawDataString = """
        Bytes: \(data.count)
        Hex: \(hexString)
        
        \(description)
        """
        
        addLog(type: .raw, message: "Received \(data.count) bytes", rawData: rawDataString)
    }
    
    private func handleDetection(_ detection: BLEManager.DetectionData) {
        guard !isPaused else { return }
        
        totalPackets += 1
        detectionCount += 1
        lastPacketTime = Date()
        
        let message = """
        Type: \(detection.deviceType)
        MAC: \(detection.macAddress ?? "N/A")
        SSID: \(detection.ssid ?? "N/A")
        RSSI: \(detection.rssi) dBm
        Confidence: \(String(format: "%.0f%%", detection.confidence * 100))
        """
        
        let rawData = """
        {
          "type": "\(detection.deviceType)",
          "mac": "\(detection.macAddress ?? "")",
          "ssid": "\(detection.ssid ?? "")",
          "rssi": \(detection.rssi),
          "confidence": \(detection.confidence)
        }
        """
        
        addLog(type: .detection, message: message, rawData: rawData)
    }
    
    private func addLog(type: LogType, message: String, rawData: String? = nil) {
        let log = StreamLog(
            timestamp: Date(),
            type: type,
            message: message,
            rawData: rawData
        )
        
        DispatchQueue.main.async {
            streamLogs.append(log)
            
            // Keep only last 500 logs to prevent memory issues
            if streamLogs.count > 500 {
                streamLogs.removeFirst(streamLogs.count - 500)
            }
            
            if type == .error {
                errorCount += 1
            }
        }
    }
    
    private func clearLogs() {
        streamLogs.removeAll()
        totalPackets = 0
        detectionCount = 0
        errorCount = 0
        lastPacketTime = nil
        addLog(type: .info, message: "Logs cleared")
    }
    
    private func timeSince(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            return "\(minutes)m"
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? .white : .primary)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Log Row

struct LogRow: View {
    let log: DebugStreamView.StreamLog
    let showRawData: Bool
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                // Type icon
                Image(systemName: log.type.icon)
                    .foregroundColor(log.type.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Timestamp and type
                    HStack {
                        Text(log.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        
                        Text(log.type.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(log.type.color.opacity(0.2))
                            .foregroundColor(log.type.color)
                            .clipShape(Capsule())
                    }
                    
                    // Message
                    Text(log.message)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    // Raw data (if available and enabled)
                    if showRawData, let rawData = log.rawData {
                        Text(rawData)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DebugStreamView()
        .environmentObject(BLEManager())
}
