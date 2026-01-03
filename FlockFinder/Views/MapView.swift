import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @StateObject private var appSettings = AppSettings.shared
    
    @State private var region: MKCoordinateRegion {
        didSet {
            print("🗺️ Region changed to: \(region.center.latitude), \(region.center.longitude) - span: \(region.span.latitudeDelta)")
        }
    }
    @State private var detections: [FlockDetection] = []
    @State private var selectedDetection: FlockDetection?
    @State private var showingDetail = false
    @State private var hasInitializedLocation = false
    @State private var mapRotation: Double = 0.0  // For heading-up mode
    
    // Initialize region based on current location if available
    init() {
        // Start with a default region, will update in onAppear
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }
    
    // Filter out invalid coordinates
    var validDetections: [FlockDetection] {
        detections.filter { $0.isValidLocation }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, 
                    showsUserLocation: true,
                    annotationItems: validDetections) { detection in
                    MapAnnotation(coordinate: detection.coordinate) {
                        DetectionMapPin(detection: detection)
                            .onTapGesture {
                                selectedDetection = detection
                                showingDetail = true
                            }
                    }
                }
                .ignoresSafeArea(edges: .top)
                .rotationEffect(.degrees(-mapRotation))  // Rotate map for heading-up mode
                
                // Floating controls
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // Map orientation toggle
                            Button(action: toggleMapOrientation) {
                                Image(systemName: appSettings.mapOrientationMode.icon)
                                    .font(.title2)
                                    .foregroundColor(appSettings.mapOrientationMode == .heading ? .green : .blue)
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            
                            // Center on user location
                            Button(action: centerOnUser) {
                                Image(systemName: "location.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            
                            // Refresh detections
                            Button(action: loadDetections) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        }
                        .padding()
                    }
                }
                
                // Detection count overlay
                VStack {
                    HStack {
                        Label("\(validDetections.count) detections", systemImage: "camera.fill")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        Spacer()
                    }
                    .padding()
                    Spacer()
                }
                
                // Location status overlay
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "location.slash.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("Location Access Denied")
                                .font(.headline)
                            Text("Enable location access in Settings to see your position on the map.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Button(action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Open Settings")
                                    .font(.caption)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding()
                    }
                } else if locationManager.authorizationStatus == .notDetermined {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Requesting location permission...")
                                .font(.caption)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding()
                    }
                } else if !locationManager.isTracking {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Location tracking stopped. Tap the location button to enable.")
                                .font(.caption)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding()
                    }
                } else if locationManager.isTracking && locationManager.currentLocation == nil {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Acquiring GPS signal...")
                                .font(.caption)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding()
                    }
                }
            }
            .navigationTitle("Detection Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("🗺️ MapView appeared")
                print("📍 Current location available: \(locationManager.currentLocation != nil)")
                if let loc = locationManager.currentLocation {
                    print("📍 Location coords: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
                }
                print("📍 Is tracking: \(locationManager.isTracking)")
                
                loadDetections()
                
                // Force immediate centering with slight delay to ensure map is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let location = locationManager.currentLocation {
                        print("✅ Centering on user location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                        withAnimation(.easeInOut(duration: 0.5)) {
                            region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                            )
                        }
                        hasInitializedLocation = true
                    } else {
                        print("⚠️ No location yet, waiting for updates...")
                        // Ensure location tracking is started
                        if !locationManager.isTracking {
                            locationManager.startTracking()
                        }
                    }
                }
            }
            .onDisappear {
                // Reset initialization flag so map re-centers when returning
                hasInitializedLocation = false
                print("🗺️ MapView disappeared, reset for next appearance")
            }
            .onChange(of: locationManager.currentLocation) { newLocation in
                // Auto-center on first location update
                if !hasInitializedLocation, let location = newLocation {
                    print("🗺️ First location received, centering map")
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )
                    }
                    hasInitializedLocation = true
                } else if !hasInitializedLocation {
                    // No location yet, check if we have detections to show
                    if !validDetections.isEmpty {
                        print("🗺️ No location, centering on detections")
                        centerOnDetections()
                        hasInitializedLocation = true
                    }
                }
                
                // Update map rotation for heading-up mode
                if appSettings.mapOrientationMode == .heading, let location = newLocation {
                    updateMapRotation(heading: location.course)
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let detection = selectedDetection {
                    DetectionDetailView(detection: detection)
                }
            }
        }
    }
    
    private func centerOnUser() {
        print("🗺️ centerOnUser() called")
        
        // First check if we have location permission
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            print("❌ Location permission not granted: \(locationManager.authorizationStatus)")
            // Try to center on detections instead
            if !validDetections.isEmpty {
                centerOnDetections()
            }
            return
        }
        
        print("✅ Location permission granted")
        
        // Start tracking if not already
        if !locationManager.isTracking {
            print("🗺️ Starting location tracking")
            locationManager.startTracking()
        }
        
        // Center on user if we have a valid location
        if let location = locationManager.currentLocation {
            print("✅ Centering on user location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
            hasInitializedLocation = true
        } else {
            print("⚠️ No current location available yet")
            // If we have detections but no user location, center on detections
            if !validDetections.isEmpty {
                print("🗺️ Centering on \(validDetections.count) detections instead")
                centerOnDetections()
            } else {
                print("⚠️ No detections to center on either, will wait for location")
            }
        }
    }
    
    private func centerOnDetections() {
        guard !validDetections.isEmpty else {
            print("⚠️ No valid detections to center on")
            return
        }
        
        print("🗺️ Centering on \(validDetections.count) detections")
        
        // Calculate bounding box for all detections
        let coordinates = validDetections.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.5)
        )
        
        print("✅ Detection bounds: center(\(center.latitude), \(center.longitude)), span(\(span.latitudeDelta), \(span.longitudeDelta))")
        
        withAnimation {
            region = MKCoordinateRegion(center: center, span: span)
        }
        hasInitializedLocation = true
    }
    
    private func loadDetections() {
        detections = databaseManager.fetchAllDetections()
        print("🗺️ Loaded \(detections.count) total detections (\(validDetections.count) valid)")
        
        // If we don't have location yet and we just loaded detections, try to center on them
        if !hasInitializedLocation && locationManager.currentLocation == nil && !validDetections.isEmpty {
            centerOnDetections()
        }
    }
    
    // MARK: - Map Orientation Methods
    
    /// Toggle between north-up and heading-up map orientation
    private func toggleMapOrientation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if appSettings.mapOrientationMode == .north {
                appSettings.mapOrientationMode = .heading
                // Immediately update rotation if we have location
                if let location = locationManager.currentLocation {
                    updateMapRotation(heading: location.course)
                }
            } else {
                appSettings.mapOrientationMode = .north
                // Return to north-up
                mapRotation = 0.0
            }
        }
        
        print("🗺️ Map orientation changed to: \(appSettings.mapOrientationMode.rawValue)")
    }
    
    /// Update map rotation based on heading
    private func updateMapRotation(heading: Double) {
        guard appSettings.mapOrientationMode == .heading else {
            mapRotation = 0.0
            return
        }
        
        // Only update if heading is valid (not -1)
        guard heading >= 0 else { return }
        
        withAnimation(.linear(duration: 0.5)) {
            mapRotation = heading
        }
    }
}

// MARK: - Detection Map Pin
struct DetectionMapPin: View {
    let detection: FlockDetection
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: detection.deviceType.icon)
                .font(.caption)
                .foregroundColor(.white)
                .padding(8)
                .background(detection.deviceType.color)
                .clipShape(Circle())
            
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(detection.deviceType.color)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
    }
}

// MARK: - Detection Detail View
struct DetectionDetailView: View {
    let detection: FlockDetection
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Device Info") {
                    LabeledContent("Type", value: detection.deviceType.rawValue)
                    LabeledContent("MAC Address", value: detection.macAddress ?? "Unknown")
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
                        LabeledContent("Accuracy", value: String(format: "%.1f m", detection.accuracy))
                    } else {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.secondary)
                            Text("Location data not available")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Motion") {
                    LabeledContent("Speed", value: String(format: "%.1f mph", detection.speed * 2.237))
                    LabeledContent("Heading", value: String(format: "%.0f°", detection.heading))
                }
                
                Section("Timestamp") {
                    LabeledContent("Detected", value: detection.timestamp.formatted())
                }
                
                if detection.isValidLocation {
                    Section {
                        Button(action: shareDetection) {
                            Label("Share Location", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: openInMaps) {
                            Label("Open in Maps", systemImage: "map")
                        }
                    }
                }
            }
            .navigationTitle("Detection Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareDetection() {
        guard detection.isValidLocation else { return }
        // Share functionality
    }
    
    private func openInMaps() {
        guard detection.isValidLocation else { return }
        let coordinate = detection.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = "Flock Detection: \(detection.deviceType.rawValue)"
        mapItem.openInMaps()
    }
}

#Preview {
    MapView()
        .environmentObject(LocationManager())
        .environmentObject(DatabaseManager.shared)
}
