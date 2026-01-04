# Data Export

FlockFinder supports exporting your detection data in multiple formats for analysis, backup, or sharing.

## Export Formats

| Format | Extension | Best For |
|--------|-----------|----------|
| **CSV** | `.csv` | Spreadsheets, data analysis |
| **JSON** | `.json` | Programming, APIs, backups |
| **GPX** | `.gpx` | Mapping apps, GPS devices |

## How to Export

1. Open the **History** tab
2. Tap the **Export** button (share icon)
3. Select your desired format
4. Choose destination (Files, AirDrop, etc.)

## CSV Format

Comma-separated values compatible with Excel, Google Sheets, and data analysis tools.

### Columns

| Column | Type | Description |
|--------|------|-------------|
| `id` | Integer | Unique detection ID |
| `device_type` | String | Camera type (e.g., "Flock Safety") |
| `mac_address` | String | Device MAC address |
| `ssid` | String | WiFi network name |
| `rssi` | Integer | Signal strength (dBm) |
| `confidence` | Float | Detection confidence (0-1) |
| `latitude` | Float | GPS latitude |
| `longitude` | Float | GPS longitude |
| `speed` | Float | Speed (m/s) |
| `heading` | Float | Compass heading (degrees) |
| `activity` | String | Motion activity type |
| `timestamp` | ISO 8601 | Detection time |

### Example

```csv
id,device_type,mac_address,ssid,rssi,confidence,latitude,longitude,speed,heading,activity,timestamp
1,Flock Safety,3C:71:BF:12:34:56,FLOCK-S3-1234,-62,0.98,37.7749,-122.4194,12.5,270.0,automotive,2024-01-15T14:30:00Z
2,Ring,A4:83:E7:AB:CD:EF,Ring Doorbell Pro,-71,0.85,37.7751,-122.4189,0.0,0.0,stationary,2024-01-15T14:35:00Z
```

## JSON Format

Structured data format ideal for programmatic access and full data fidelity.

### Schema

```json
{
  "export_date": "2024-01-15T15:00:00Z",
  "app_version": "1.0.0",
  "total_detections": 2,
  "detections": [
    {
      "id": 1,
      "device_type": "Flock Safety",
      "mac_address": "3C:71:BF:12:34:56",
      "ssid": "FLOCK-S3-1234",
      "rssi": -62,
      "confidence": 0.98,
      "location": {
        "latitude": 37.7749,
        "longitude": -122.4194
      },
      "motion": {
        "speed": 12.5,
        "heading": 270.0,
        "activity": "automotive"
      },
      "timestamp": "2024-01-15T14:30:00Z"
    }
  ]
}
```

## GPX Format

GPS Exchange Format for mapping applications and GPS devices.

### Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="FlockFinder iOS">
  <metadata>
    <name>FlockFinder Detections</name>
    <time>2024-01-15T15:00:00Z</time>
  </metadata>
  
  <wpt lat="37.7749" lon="-122.4194">
    <ele>0</ele>
    <time>2024-01-15T14:30:00Z</time>
    <name>Flock Safety</name>
    <desc>MAC: 3C:71:BF:12:34:56, RSSI: -62, Confidence: 98%</desc>
    <type>Flock Safety</type>
  </wpt>
  
  <wpt lat="37.7751" lon="-122.4189">
    <ele>0</ele>
    <time>2024-01-15T14:35:00Z</time>
    <name>Ring</name>
    <desc>MAC: A4:83:E7:AB:CD:EF, RSSI: -71, Confidence: 85%</desc>
    <type>Ring</type>
  </wpt>
</gpx>
```

### Compatible Apps

GPX files can be imported into:

- Apple Maps (via Files app)
- Google Maps (My Maps)
- Gaia GPS
- AllTrails
- Garmin Connect
- Strava

## Filtering Before Export

Use the History view filters to export subsets of data:

| Filter | Description |
|--------|-------------|
| **Date Range** | Export detections within specific dates |
| **Device Type** | Export only certain camera types |
| **Search** | Export detections matching search terms |

!!! tip "Large Exports"
    For exports with many detections, JSON format is most efficient for large datasets.

## Sharing Options

After export, iOS shows the share sheet with options:

- **AirDrop** - Send to nearby Apple devices
- **Files** - Save to iCloud Drive or local storage
- **Email** - Attach to email message
- **Messages** - Share via iMessage/SMS
- **Third-party apps** - Any app that accepts the file type

## Data Analysis

### Opening in Excel

1. Export as CSV
2. Open Excel and select **File > Import**
3. Choose the CSV file
4. Data will populate in columns

### Opening in Python

```python
import pandas as pd

# CSV
df = pd.read_csv('flockfinder_export.csv')

# JSON
import json
with open('flockfinder_export.json') as f:
    data = json.load(f)
df = pd.DataFrame(data['detections'])
```

### Visualizing on Map

```python
import folium

# Create map centered on first detection
m = folium.Map(location=[df['latitude'].mean(), df['longitude'].mean()], zoom_start=12)

# Add markers
for _, row in df.iterrows():
    folium.Marker(
        [row['latitude'], row['longitude']],
        popup=f"{row['device_type']}: {row['timestamp']}"
    ).add_to(m)

m.save('detections_map.html')
```

## Privacy Notice

!!! warning "Location Data"
    Exported files contain precise GPS coordinates. Consider the privacy implications before sharing exported data.

**Recommendations:**

- Only share with trusted parties
- Consider removing or obfuscating exact locations
- Don't post raw exports publicly

## iCloud Backup

If iCloud sync is enabled, your detection database automatically backs up to iCloud. This is separate from manual exports and provides automatic device-to-device sync.

See [iCloud Setup Guide](icloud-setup.md) for configuration.

## Next Steps

- [Configure iCloud sync](icloud-setup.md)
- [View detection types](detection-types.md)
- [Explore the map view](architecture.md)
