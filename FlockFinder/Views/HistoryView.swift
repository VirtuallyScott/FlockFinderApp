import SwiftUI
import MapKit

struct HistoryView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    
    @State private var detections: [FlockDetection] = []
    @State private var searchText = ""
    @State private var selectedFilter: DeviceType?
    @State private var sortOrder: SortOrder = .newest
    @State private var showingExportSheet = false
    
    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case strongest = "Strongest Signal"
        case highestConfidence = "Highest Confidence"
    }
    
    var filteredDetections: [FlockDetection] {
        var result = detections
        
        // Filter by device type
        if let filter = selectedFilter {
            result = result.filter { $0.deviceType == filter }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { detection in
                detection.macAddress?.localizedCaseInsensitiveContains(searchText) == true ||
                detection.ssid?.localizedCaseInsensitiveContains(searchText) == true ||
                detection.deviceType.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        switch sortOrder {
        case .newest:
            result.sort { $0.timestamp > $1.timestamp }
        case .oldest:
            result.sort { $0.timestamp < $1.timestamp }
        case .strongest:
            result.sort { $0.rssi > $1.rssi }
        case .highestConfidence:
            result.sort { $0.confidence > $1.confidence }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats header
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        StatBadge(
                            icon: "camera.fill",
                            value: "\(detections.count)",
                            label: "Total"
                        )
                        
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            let count = detections.filter { $0.deviceType == type }.count
                            if count > 0 {
                                StatBadge(
                                    icon: type.icon,
                                    value: "\(count)",
                                    label: type.rawValue,
                                    color: type.color,
                                    isSelected: selectedFilter == type
                                )
                                .onTapGesture {
                                    withAnimation {
                                        if selectedFilter == type {
                                            selectedFilter = nil
                                        } else {
                                            selectedFilter = type
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                
                // Detection list
                List {
                    if filteredDetections.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.metering.unknown")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Detections")
                                .font(.headline)
                            
                            Text("Connect to your FlockFinder device and start scanning to see detections here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(groupedDetections.keys.sorted().reversed(), id: \.self) { date in
                            Section(header: Text(formatDate(date))) {
                                ForEach(groupedDetections[date] ?? []) { detection in
                                    NavigationLink(destination: HistoryDetailView(detection: detection)) {
                                        HistoryRow(detection: detection)
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteDetections(at: indexSet, in: date)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search MAC, SSID, or type")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                if sortOrder == order {
                                    Label(order.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(order.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive) {
                            clearAllData()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadDetections()
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportView(detections: filteredDetections)
            }
        }
    }
    
    private var groupedDetections: [Date: [FlockDetection]] {
        Dictionary(grouping: filteredDetections) { detection in
            Calendar.current.startOfDay(for: detection.timestamp)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func loadDetections() {
        detections = databaseManager.fetchAllDetections()
    }
    
    private func deleteDetections(at offsets: IndexSet, in date: Date) {
        guard let detectionsForDate = groupedDetections[date] else { return }
        for index in offsets {
            let detection = detectionsForDate[index]
            databaseManager.deleteDetection(id: detection.id)
        }
        loadDetections()
    }
    
    private func clearAllData() {
        databaseManager.clearAllDetections()
        loadDetections()
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .blue
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.headline)
            }
            .foregroundColor(isSelected ? .white : color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let detection: FlockDetection
    
    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: detection.deviceType.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(detection.deviceType.color)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(detection.deviceType.rawValue)
                    .font(.headline)
                
                if let mac = detection.macAddress {
                    Text(mac)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospaced()
                }
                
                HStack {
                    Label("\(detection.rssi) dBm", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    Text(detection.timestamp.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Confidence indicator
            CircularProgressView(progress: detection.confidence)
                .frame(width: 40, height: 40)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))")
                .font(.caption2)
                .bold()
        }
    }
    
    var progressColor: Color {
        if progress > 0.8 {
            return .red
        } else if progress > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - History Detail View
struct HistoryDetailView: View {
    let detection: FlockDetection
    
    var body: some View {
        List {
            Section("Device Information") {
                LabeledContent("Type", value: detection.deviceType.rawValue)
                if let mac = detection.macAddress {
                    LabeledContent("MAC Address", value: mac)
                }
                if let ssid = detection.ssid {
                    LabeledContent("SSID", value: ssid)
                }
                LabeledContent("Signal Strength", value: "\(detection.rssi) dBm")
                LabeledContent("Confidence", value: String(format: "%.0f%%", detection.confidence * 100))
            }
            
            Section("Location") {
                if detection.isValidLocation {
                    LabeledContent("Latitude", value: String(format: "%.6f", detection.latitude))
                    LabeledContent("Longitude", value: String(format: "%.6f", detection.longitude))
                    if detection.altitude > 0 {
                        LabeledContent("Altitude", value: String(format: "%.1f m", detection.altitude))
                    }
                    LabeledContent("GPS Accuracy", value: String(format: "%.1f m", detection.accuracy))
                } else {
                    HStack {
                        Image(systemName: "location.slash")
                            .foregroundColor(.secondary)
                        Text("Location data not available")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Motion Data") {
                LabeledContent("Speed", value: String(format: "%.1f mph", detection.speed * 2.237))
                LabeledContent("Heading", value: String(format: "%.0f°", detection.heading))
            }
            
            Section("Timestamp") {
                LabeledContent("Detected At", value: detection.timestamp.formatted())
            }
            
            if detection.isValidLocation {
                Section {
                    Button {
                        openInMaps()
                    } label: {
                        Label("View on Map", systemImage: "map")
                    }
                }
            }
        }
        .navigationTitle("Detection Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func openInMaps() {
        guard detection.isValidLocation else { return }
        let coordinate = detection.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = "Flock Detection"
        mapItem.openInMaps()
    }
}

// MARK: - Export View
struct ExportView: View {
    let detections: [FlockDetection]
    @Environment(\.dismiss) var dismiss
    @State private var exportFormat: ExportFormat = .csv
    @State private var showingShareSheet = false
    @State private var showingMailComposer = false
    @State private var exportedFileURL: URL?
    @State private var exportError: String?
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .json: return "json"
            }
        }
        
        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .json: return "application/json"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
                Section("Summary") {
                    LabeledContent("Total Records", value: "\(detections.count)")
                    
                    if !detections.isEmpty {
                        let validLocations = detections.filter { $0.isValidLocation }.count
                        LabeledContent("With Valid Location", value: "\(validLocations)")
                        
                        if let first = detections.last {
                            LabeledContent("From", value: first.timestamp.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let last = detections.first {
                            LabeledContent("To", value: last.timestamp.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                
                if let error = exportError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    Button {
                        exportAndShare()
                    } label: {
                        Label("Export & Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(detections.isEmpty)
                    
                    Button {
                        exportAndShareViaMessage()
                    } label: {
                        Label("Share via Messages", systemImage: "message.fill")
                    }
                    .disabled(detections.isEmpty)
                    
                    Button {
                        exportAndShareViaEmail()
                    } label: {
                        Label("Share via Email", systemImage: "envelope.fill")
                    }
                    .disabled(detections.isEmpty)
                } header: {
                    Text("Export Actions")
                } footer: {
                    Text("Export your detections as \(exportFormat.rawValue) and share via Messages, Mail, or other apps.")
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                if let url = exportedFileURL {
                    MailComposeView(
                        subject: "FlockFinder Detections Export",
                        message: generateEmailBody(),
                        attachmentURL: url,
                        attachmentMimeType: exportFormat.mimeType
                    )
                }
            }
        }
    }
    
    private var formatDescription: String {
        switch exportFormat {
        case .csv:
            return "Spreadsheet-compatible format. Opens in Excel, Numbers, Google Sheets."
        case .json:
            return "Structured data format. For developers and data analysis tools."
        }
    }
    
    private func generateEmailBody() -> String {
        let validCount = detections.filter { $0.isValidLocation }.count
        
        return """
        FlockFinder Detection Report
        
        Total Detections: \(detections.count)
        Valid Locations: \(validCount)
        Export Format: \(exportFormat.rawValue)
        
        This export contains surveillance camera detection data collected with the FlockFinder iOS app.
        
        Device Types Detected:
        \(generateDeviceTypeSummary())
        
        ---
        Generated by FlockFinder v1.0
        """
    }
    
    private func generateDeviceTypeSummary() -> String {
        let grouped = Dictionary(grouping: detections, by: { $0.deviceType })
        return grouped
            .sorted { $0.value.count > $1.value.count }
            .map { "• \($0.key.rawValue): \($0.value.count)" }
            .joined(separator: "\n")
    }
    
    private func exportAndShare() {
        guard let url = exportData() else { return }
        exportedFileURL = url
        showingShareSheet = true
    }
    
    private func exportAndShareViaMessage() {
        guard let url = exportData() else { return }
        exportedFileURL = url
        
        // Use share sheet which includes Messages
        showingShareSheet = true
    }
    
    private func exportAndShareViaEmail() {
        guard let url = exportData() else { return }
        exportedFileURL = url
        showingMailComposer = true
    }
    
    private func exportData() -> URL? {
        exportError = nil
        
        let filename = "flockfinder_detections_\(formattedDate()).\(exportFormat.fileExtension)"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            switch exportFormat {
            case .csv:
                let csvData = generateCSV()
                try csvData.write(to: fileURL, atomically: true, encoding: .utf8)
                
            case .json:
                let jsonData = try generateJSON()
                try jsonData.write(to: fileURL)
            }
            
            print("✅ Exported to: \(fileURL.path)")
            return fileURL
            
        } catch {
            print("❌ Export error: \(error)")
            exportError = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    private func generateCSV() -> String {
        var csv = "ID,Timestamp,Device Type,MAC Address,SSID,RSSI (dBm),Confidence (%),Latitude,Longitude,Altitude (m),GPS Accuracy (m),Speed (mph),Heading (°),Location Valid\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for detection in detections {
            let timestamp = dateFormatter.string(from: detection.timestamp)
            let deviceType = detection.deviceType.rawValue
            let mac = detection.macAddress?.replacingOccurrences(of: ",", with: ";") ?? ""
            let ssid = detection.ssid?.replacingOccurrences(of: ",", with: ";") ?? ""
            let rssi = detection.rssi
            let confidence = Int(detection.confidence * 100)
            let lat = String(format: "%.6f", detection.latitude)
            let lon = String(format: "%.6f", detection.longitude)
            let alt = String(format: "%.1f", detection.altitude)
            let accuracy = String(format: "%.1f", detection.accuracy)
            let speed = String(format: "%.1f", detection.speedMPH)
            let heading = String(format: "%.0f", detection.heading)
            let validLocation = detection.isValidLocation ? "Yes" : "No"
            
            csv += "\(detection.id),\(timestamp),\(deviceType),\(mac),\(ssid),\(rssi),\(confidence),\(lat),\(lon),\(alt),\(accuracy),\(speed),\(heading),\(validLocation)\n"
        }
        
        return csv
    }
    
    private func generateJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Create export structure
        let exportData = ExportData(
            exportDate: Date(),
            version: "1.0",
            detectionCount: detections.count,
            detections: detections.map { detection in
                ExportDetection(
                    id: detection.id,
                    timestamp: detection.timestamp,
                    deviceType: detection.deviceType.rawValue,
                    macAddress: detection.macAddress,
                    ssid: detection.ssid,
                    rssi: detection.rssi,
                    confidence: detection.confidence,
                    location: ExportLocation(
                        latitude: detection.latitude,
                        longitude: detection.longitude,
                        altitude: detection.altitude,
                        accuracy: detection.accuracy,
                        isValid: detection.isValidLocation
                    ),
                    motion: ExportMotion(
                        speed: detection.speed,
                        speedMPH: detection.speedMPH,
                        heading: detection.heading
                    )
                )
            }
        )
        
        return try encoder.encode(exportData)
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }
}

// MARK: - Export Data Structures
struct ExportData: Codable {
    let exportDate: Date
    let version: String
    let detectionCount: Int
    let detections: [ExportDetection]
}

struct ExportDetection: Codable {
    let id: Int64
    let timestamp: Date
    let deviceType: String
    let macAddress: String?
    let ssid: String?
    let rssi: Int
    let confidence: Double
    let location: ExportLocation
    let motion: ExportMotion
}

struct ExportLocation: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let accuracy: Double
    let isValid: Bool
}

struct ExportMotion: Codable {
    let speed: Double
    let speedMPH: Double
    let heading: Double
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Mail Compose View
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let message: String
    let attachmentURL: URL
    let attachmentMimeType: String
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(message, isHTML: false)
        
        // Attach file
        if let data = try? Data(contentsOf: attachmentURL) {
            let filename = attachmentURL.lastPathComponent
            composer.addAttachmentData(data, mimeType: attachmentMimeType, fileName: filename)
        }
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(DatabaseManager.shared)
}
