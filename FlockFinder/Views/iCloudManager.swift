import Foundation
import CloudKit

/// Manages iCloud backup and sync for the FlockFinder database
class iCloudManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = iCloudManager()
    
    // MARK: - Published Properties
    @Published var isICloudAvailable = false
    @Published var lastBackupDate: Date?
    @Published var lastRestoreDate: Date?
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var backupError: String?
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let appSettings = AppSettings.shared
    
    // iCloud container URL
    private var iCloudContainerURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }
    
    // Local database URL
    private var localDatabaseURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("flockfinder.sqlite")
    }
    
    // iCloud database backup URL
    private var iCloudDatabaseURL: URL? {
        iCloudContainerURL?.appendingPathComponent("flockfinder_backup.sqlite")
    }
    
    // Backup metadata file
    private var backupMetadataURL: URL? {
        iCloudContainerURL?.appendingPathComponent("backup_metadata.json")
    }
    
    // MARK: - Backup Metadata
    struct BackupMetadata: Codable {
        let backupDate: Date
        let detectionCount: Int
        let databaseSize: Int64
        let appVersion: String
    }
    
    // MARK: - Initialization
    private init() {
        checkICloudAvailability()
        loadBackupMetadata()
        
        // Observe iCloud account changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleICloudAccountChange),
            name: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil
        )
        
        print("☁️ iCloudManager initialized")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - iCloud Availability
    
    /// Check if iCloud is available
    func checkICloudAvailability() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let available = self?.fileManager.ubiquityIdentityToken != nil
            
            DispatchQueue.main.async {
                self?.isICloudAvailable = available
                print("☁️ iCloud available: \(available)")
            }
        }
    }
    
    @objc private func handleICloudAccountChange() {
        print("☁️ iCloud account changed, rechecking availability")
        checkICloudAvailability()
        
        if isICloudAvailable {
            // Optionally auto-restore when iCloud becomes available
            loadBackupMetadata()
        }
    }
    
    // MARK: - Backup Operations
    
    /// Backup database to iCloud
    func backupToICloud(completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard isICloudAvailable else {
            let error = NSError(
                domain: "iCloudManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "iCloud is not available"]
            )
            completion?(.failure(error))
            return
        }
        
        guard let iCloudURL = iCloudContainerURL else {
            let error = NSError(
                domain: "iCloudManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not access iCloud container"]
            )
            completion?(.failure(error))
            return
        }
        
        DispatchQueue.main.async {
            self.isBackingUp = true
            self.backupError = nil
        }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Create iCloud Documents directory if it doesn't exist
                if !self.fileManager.fileExists(atPath: iCloudURL.path) {
                    try self.fileManager.createDirectory(
                        at: iCloudURL,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                }
                
                // Check if local database exists
                guard self.fileManager.fileExists(atPath: self.localDatabaseURL.path) else {
                    throw NSError(
                        domain: "iCloudManager",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Local database not found"]
                    )
                }
                
                // Get database file attributes
                let attributes = try self.fileManager.attributesOfItem(atPath: self.localDatabaseURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // Get detection count
                let detectionCount = DatabaseManager.shared.getDetectionCount()
                
                // Copy database to iCloud
                if let iCloudDBURL = self.iCloudDatabaseURL {
                    // Remove existing backup
                    if self.fileManager.fileExists(atPath: iCloudDBURL.path) {
                        try self.fileManager.removeItem(at: iCloudDBURL)
                    }
                    
                    // Copy new backup
                    try self.fileManager.copyItem(at: self.localDatabaseURL, to: iCloudDBURL)
                    
                    // Also backup the WAL and SHM files if they exist
                    self.backupSQLiteAuxiliaryFiles(to: iCloudURL)
                }
                
                // Create backup metadata
                let metadata = BackupMetadata(
                    backupDate: Date(),
                    detectionCount: detectionCount,
                    databaseSize: fileSize,
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                )
                
                // Save metadata
                if let metadataURL = self.backupMetadataURL {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(metadata)
                    try data.write(to: metadataURL)
                }
                
                DispatchQueue.main.async {
                    self.lastBackupDate = Date()
                    self.isBackingUp = false
                    print("☁️ Backup completed: \(detectionCount) detections, \(self.formatBytes(fileSize))")
                    completion?(.success(()))
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isBackingUp = false
                    self.backupError = error.localizedDescription
                    print("❌ Backup failed: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    /// Backup SQLite auxiliary files (WAL, SHM)
    private func backupSQLiteAuxiliaryFiles(to iCloudURL: URL) {
        let walURL = localDatabaseURL.appendingPathExtension("wal")
        let shmURL = localDatabaseURL.appendingPathExtension("shm")
        
        let iCloudWalURL = iCloudURL.appendingPathComponent("flockfinder_backup.sqlite-wal")
        let iCloudShmURL = iCloudURL.appendingPathComponent("flockfinder_backup.sqlite-shm")
        
        // WAL file
        if fileManager.fileExists(atPath: walURL.path) {
            try? fileManager.removeItem(at: iCloudWalURL)
            try? fileManager.copyItem(at: walURL, to: iCloudWalURL)
        }
        
        // SHM file
        if fileManager.fileExists(atPath: shmURL.path) {
            try? fileManager.removeItem(at: iCloudShmURL)
            try? fileManager.copyItem(at: shmURL, to: iCloudShmURL)
        }
    }
    
    // MARK: - Restore Operations
    
    /// Restore database from iCloud
    func restoreFromICloud(completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard isICloudAvailable else {
            let error = NSError(
                domain: "iCloudManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "iCloud is not available"]
            )
            completion?(.failure(error))
            return
        }
        
        guard let iCloudDBURL = iCloudDatabaseURL else {
            let error = NSError(
                domain: "iCloudManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not access iCloud backup"]
            )
            completion?(.failure(error))
            return
        }
        
        DispatchQueue.main.async {
            self.isRestoring = true
            self.backupError = nil
        }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check if backup exists
                guard self.fileManager.fileExists(atPath: iCloudDBURL.path) else {
                    throw NSError(
                        domain: "iCloudManager",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "No backup found in iCloud"]
                    )
                }
                
                // Close existing database connection
                // Note: You may need to add a close() method to DatabaseManager
                
                // Backup current local database (just in case)
                let backupLocalURL = self.localDatabaseURL.appendingPathExtension("pre-restore")
                if self.fileManager.fileExists(atPath: self.localDatabaseURL.path) {
                    try? self.fileManager.removeItem(at: backupLocalURL)
                    try? self.fileManager.copyItem(at: self.localDatabaseURL, to: backupLocalURL)
                }
                
                // Remove current local database
                if self.fileManager.fileExists(atPath: self.localDatabaseURL.path) {
                    try self.fileManager.removeItem(at: self.localDatabaseURL)
                }
                
                // Copy from iCloud to local
                try self.fileManager.copyItem(at: iCloudDBURL, to: self.localDatabaseURL)
                
                // Restore auxiliary files if they exist
                self.restoreSQLiteAuxiliaryFiles()
                
                DispatchQueue.main.async {
                    self.lastRestoreDate = Date()
                    self.isRestoring = false
                    print("☁️ Restore completed")
                    completion?(.success(()))
                    
                    // Post notification to reload data
                    NotificationCenter.default.post(name: .databaseRestored, object: nil)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isRestoring = false
                    self.backupError = error.localizedDescription
                    print("❌ Restore failed: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    /// Restore SQLite auxiliary files (WAL, SHM)
    private func restoreSQLiteAuxiliaryFiles() {
        guard let iCloudURL = iCloudContainerURL else { return }
        
        let walURL = localDatabaseURL.appendingPathExtension("wal")
        let shmURL = localDatabaseURL.appendingPathExtension("shm")
        
        let iCloudWalURL = iCloudURL.appendingPathComponent("flockfinder_backup.sqlite-wal")
        let iCloudShmURL = iCloudURL.appendingPathComponent("flockfinder_backup.sqlite-shm")
        
        // WAL file
        if fileManager.fileExists(atPath: iCloudWalURL.path) {
            try? fileManager.removeItem(at: walURL)
            try? fileManager.copyItem(at: iCloudWalURL, to: walURL)
        }
        
        // SHM file
        if fileManager.fileExists(atPath: iCloudShmURL.path) {
            try? fileManager.removeItem(at: shmURL)
            try? fileManager.copyItem(at: iCloudShmURL, to: shmURL)
        }
    }
    
    // MARK: - Metadata
    
    /// Load backup metadata
    func loadBackupMetadata() {
        guard let metadataURL = backupMetadataURL,
              fileManager.fileExists(atPath: metadataURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(BackupMetadata.self, from: data)
            
            DispatchQueue.main.async {
                self.lastBackupDate = metadata.backupDate
            }
            
            print("☁️ Last backup: \(metadata.backupDate), \(metadata.detectionCount) detections")
            
        } catch {
            print("⚠️ Failed to load backup metadata: \(error.localizedDescription)")
        }
    }
    
    /// Check if backup exists in iCloud
    func hasBackup() -> Bool {
        guard let iCloudDBURL = iCloudDatabaseURL else { return false }
        return fileManager.fileExists(atPath: iCloudDBURL.path)
    }
    
    /// Get backup file size
    func getBackupSize() -> Int64? {
        guard let iCloudDBURL = iCloudDatabaseURL,
              fileManager.fileExists(atPath: iCloudDBURL.path) else {
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: iCloudDBURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    // MARK: - Automatic Backup
    
    /// Enable automatic backup (called after detections are saved)
    func scheduleAutomaticBackup() {
        // Only backup if iCloud is available and settings allow it
        guard isICloudAvailable else { return }
        
        // Check if we've backed up recently (don't backup too frequently)
        if let lastBackup = lastBackupDate,
           Date().timeIntervalSince(lastBackup) < 3600 { // Less than 1 hour
            return
        }
        
        // Schedule backup in background
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.backupToICloud()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let databaseRestored = Notification.Name("databaseRestored")
}
