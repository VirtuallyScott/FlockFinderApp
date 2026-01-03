import Foundation
import SQLite3
import CoreLocation

/// Database Manager for SQLite storage of detections
class DatabaseManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DatabaseManager()
    
    // MARK: - Published Properties
    @Published var lastInsertedId: Int64?
    
    // MARK: - Private Properties
    private var db: OpaquePointer?
    private let dbName = "flockfinder.sqlite"
    
    // MARK: - Initialization
    init() {
        openDatabase()
        createTables()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Database Setup
    
    private func openDatabase() {
        let fileURL = getDocumentsDirectory().appendingPathComponent(dbName)
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
            return
        }
        
        print("Database opened at: \(fileURL.path)")
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func createTables() {
        let createDetectionsTable = """
            CREATE TABLE IF NOT EXISTS detections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_type TEXT NOT NULL,
                mac_address TEXT,
                ssid TEXT,
                rssi INTEGER NOT NULL,
                confidence REAL NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                altitude REAL,
                accuracy REAL,
                speed REAL,
                heading REAL,
                acceleration_x REAL,
                acceleration_y REAL,
                acceleration_z REAL,
                activity_type TEXT,
                timestamp TEXT NOT NULL,
                synced INTEGER DEFAULT 0
            );
        """
        
        let createIndexes = """
            CREATE INDEX IF NOT EXISTS idx_timestamp ON detections(timestamp);
            CREATE INDEX IF NOT EXISTS idx_device_type ON detections(device_type);
            CREATE INDEX IF NOT EXISTS idx_synced ON detections(synced);
            CREATE INDEX IF NOT EXISTS idx_location ON detections(latitude, longitude);
        """
        
        executeSQL(createDetectionsTable)
        executeSQL(createIndexes)
    }
    
    private func executeSQL(_ sql: String) {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            if let error = errorMessage {
                print("SQL Error: \(String(cString: error))")
                sqlite3_free(errorMessage)
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Insert a new detection record
    func insertDetection(_ detection: FlockDetection) {
        let insertSQL = """
            INSERT INTO detections (
                device_type, mac_address, ssid, rssi, confidence,
                latitude, longitude, altitude, accuracy,
                speed, heading,
                acceleration_x, acceleration_y, acceleration_z,
                activity_type, timestamp, synced
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, detection.deviceType.rawValue, -1, nil)
            bindOptionalText(statement, 2, detection.macAddress)
            bindOptionalText(statement, 3, detection.ssid)
            sqlite3_bind_int(statement, 4, Int32(detection.rssi))
            sqlite3_bind_double(statement, 5, detection.confidence)
            sqlite3_bind_double(statement, 6, detection.latitude)
            sqlite3_bind_double(statement, 7, detection.longitude)
            sqlite3_bind_double(statement, 8, detection.altitude)
            sqlite3_bind_double(statement, 9, detection.accuracy)
            sqlite3_bind_double(statement, 10, detection.speed)
            sqlite3_bind_double(statement, 11, detection.heading)
            sqlite3_bind_double(statement, 12, detection.accelerationX)
            sqlite3_bind_double(statement, 13, detection.accelerationY)
            sqlite3_bind_double(statement, 14, detection.accelerationZ)
            bindOptionalText(statement, 15, detection.activityType)
            sqlite3_bind_text(statement, 16, ISO8601DateFormatter().string(from: detection.timestamp), -1, nil)
            sqlite3_bind_int(statement, 17, detection.synced ? 1 : 0)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                lastInsertedId = sqlite3_last_insert_rowid(db)
                print("Detection inserted with ID: \(lastInsertedId ?? 0)")
            } else {
                print("Error inserting detection")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    /// Fetch all detections
    func fetchAllDetections() -> [FlockDetection] {
        let querySQL = "SELECT * FROM detections ORDER BY timestamp DESC;"
        var detections: [FlockDetection] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let detection = parseDetectionRow(statement) {
                    detections.append(detection)
                }
            }
        }
        
        sqlite3_finalize(statement)
        print("📊 Fetched \(detections.count) detections from database")
        if !detections.isEmpty {
            let validCount = detections.filter { $0.isValidLocation }.count
            print("📊 \(validCount) have valid locations")
        }
        return detections
    }
    
    /// Fetch detections by device type
    func fetchDetections(byType type: DeviceType) -> [FlockDetection] {
        let querySQL = "SELECT * FROM detections WHERE device_type = ? ORDER BY timestamp DESC;"
        var detections: [FlockDetection] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, type.rawValue, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let detection = parseDetectionRow(statement) {
                    detections.append(detection)
                }
            }
        }
        
        sqlite3_finalize(statement)
        return detections
    }
    
    /// Fetch detections within a date range
    func fetchDetections(from startDate: Date, to endDate: Date) -> [FlockDetection] {
        let querySQL = "SELECT * FROM detections WHERE timestamp BETWEEN ? AND ? ORDER BY timestamp DESC;"
        var detections: [FlockDetection] = []
        var statement: OpaquePointer?
        
        let formatter = ISO8601DateFormatter()
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, formatter.string(from: startDate), -1, nil)
            sqlite3_bind_text(statement, 2, formatter.string(from: endDate), -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let detection = parseDetectionRow(statement) {
                    detections.append(detection)
                }
            }
        }
        
        sqlite3_finalize(statement)
        return detections
    }
    
    /// Fetch unsynced detections for upload
    func fetchUnsyncedDetections() -> [FlockDetection] {
        let querySQL = "SELECT * FROM detections WHERE synced = 0 ORDER BY timestamp ASC;"
        var detections: [FlockDetection] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let detection = parseDetectionRow(statement) {
                    detections.append(detection)
                }
            }
        }
        
        sqlite3_finalize(statement)
        return detections
    }
    
    /// Mark detections as synced
    func markAsSynced(ids: [Int64]) {
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let updateSQL = "UPDATE detections SET synced = 1 WHERE id IN (\(placeholders));"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            for (index, id) in ids.enumerated() {
                sqlite3_bind_int64(statement, Int32(index + 1), id)
            }
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Marked \(ids.count) detections as synced")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    /// Delete a detection
    func deleteDetection(id: Int64) {
        let deleteSQL = "DELETE FROM detections WHERE id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, id)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Detection \(id) deleted")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    /// Clear all detections
    func clearAllDetections() {
        let deleteSQL = "DELETE FROM detections;"
        executeSQL(deleteSQL)
        print("All detections cleared")
    }
    
    /// Get detection count
    func getDetectionCount() -> Int {
        let querySQL = "SELECT COUNT(*) FROM detections;"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    // MARK: - Export
    
    /// Export detections to JSON
    func exportToJSON() -> Data? {
        let detections = fetchAllDetections()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(detections)
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }
    
    /// Export detections to CSV
    func exportToCSV() -> String {
        let detections = fetchAllDetections()
        var csv = "id,device_type,mac_address,ssid,rssi,confidence,latitude,longitude,altitude,accuracy,speed,heading,timestamp\n"
        
        for detection in detections {
            csv += "\(detection.id),"
            csv += "\(detection.deviceType.rawValue),"
            csv += "\(detection.macAddress ?? ""),"
            csv += "\(detection.ssid ?? ""),"
            csv += "\(detection.rssi),"
            csv += "\(detection.confidence),"
            csv += "\(detection.latitude),"
            csv += "\(detection.longitude),"
            csv += "\(detection.altitude),"
            csv += "\(detection.accuracy),"
            csv += "\(detection.speed),"
            csv += "\(detection.heading),"
            csv += "\(ISO8601DateFormatter().string(from: detection.timestamp))\n"
        }
        
        return csv
    }
    
    // MARK: - Private Helpers
    
    private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value = value {
            sqlite3_bind_text(statement, index, value, -1, nil)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func parseDetectionRow(_ statement: OpaquePointer?) -> FlockDetection? {
        guard let statement = statement else { return nil }
        
        let id = sqlite3_column_int64(statement, 0)
        let deviceTypeStr = String(cString: sqlite3_column_text(statement, 1))
        let macAddress = sqlite3_column_text(statement, 2).map { String(cString: $0) }
        let ssid = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        let rssi = Int(sqlite3_column_int(statement, 4))
        let confidence = sqlite3_column_double(statement, 5)
        let latitude = sqlite3_column_double(statement, 6)
        let longitude = sqlite3_column_double(statement, 7)
        let altitude = sqlite3_column_double(statement, 8)
        let accuracy = sqlite3_column_double(statement, 9)
        let speed = sqlite3_column_double(statement, 10)
        let heading = sqlite3_column_double(statement, 11)
        let accelerationX = sqlite3_column_double(statement, 12)
        let accelerationY = sqlite3_column_double(statement, 13)
        let accelerationZ = sqlite3_column_double(statement, 14)
        let activityType = sqlite3_column_text(statement, 15).map { String(cString: $0) }
        let timestampStr = String(cString: sqlite3_column_text(statement, 16))
        let synced = sqlite3_column_int(statement, 17) == 1
        
        guard let timestamp = ISO8601DateFormatter().date(from: timestampStr) else {
            return nil
        }
        
        return FlockDetection(
            id: id,
            deviceType: DeviceType(rawValue: deviceTypeStr) ?? .unknown,
            macAddress: macAddress,
            ssid: ssid,
            rssi: rssi,
            confidence: confidence,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            accuracy: accuracy,
            speed: speed,
            heading: heading,
            accelerationX: accelerationX,
            accelerationY: accelerationY,
            accelerationZ: accelerationZ,
            activityType: activityType,
            timestamp: timestamp,
            synced: synced
        )
    }
}
