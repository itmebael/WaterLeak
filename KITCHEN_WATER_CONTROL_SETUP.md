# Kitchen Water Control System Setup

This guide is specifically for setting up the ESP32 water control system for the **Kitchen** area.

## Hardware Setup

### Pin Connections

```
Component          ESP32 Pin
----------------   ---------
Flow Sensor        GPIO 27
Buzzer             GPIO 25
Valve Relay        GPIO 26
LCD SDA            GPIO 21 (I2C)
LCD SCL            GPIO 22 (I2C)
```

### Valve Control

- **HIGH (1)** = Valve CLOSED
- **LOW (0)** = Valve OPEN

## Configuration

### 1. WiFi Setup

```cpp
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
```

### 2. Supabase Configuration

```cpp
const char* supabaseUrl = "https://YOUR_PROJECT_ID.supabase.co";
const char* supabaseKey = "YOUR_SUPABASE_ANON_KEY";
```

### 3. Kitchen-Specific IDs

Get the kitchen segment ID from your database:

```sql
-- Find kitchen segment
SELECT id, name, location 
FROM pipeline_segments 
WHERE location LIKE '%kitchen%' OR name LIKE '%kitchen%';

-- Get property ID
SELECT id, property_name 
FROM properties;
```

Update in code:

```cpp
const char* deviceId = "ESP_KITCHEN_001";  // Already set
const char* segmentId = "your-kitchen-segment-uuid";
const char* propertyId = "your-property-uuid";
```

## How It Works

### Automatic Kitchen Leak Detection

1. **Leak Detected** (0.2 - 2.0 L/min):
   - Kitchen valve automatically CLOSES
   - Buzzer sounds
   - Leak reported to Supabase with location "Kitchen"
   - LCD shows "KITCHEN LEAK!"

2. **Normal Flow** (≥ 2.0 L/min):
   - Kitchen valve automatically OPENS
   - Normal kitchen water usage
   - No alarms

3. **No Flow** (< 0.2 L/min):
   - Kitchen valve CLOSES
   - System ready

### Remote Kitchen Valve Control

Control the kitchen valve from Supabase:

```sql
-- Open kitchen valve
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'open_valve', 'pending');

-- Close kitchen valve
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'close_valve', 'pending');

-- Enable auto control
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'enable_auto', 'pending');
```

## Database Setup

### 1. Run SQL Scripts

Make sure you've run:
- `esp32_leak_detection_sql.sql` - For sensor readings and leak detections
- `water_connection_control.sql` - For valve control

### 2. Create Kitchen Segment (if not exists)

```sql
-- Insert kitchen segment if it doesn't exist
INSERT INTO pipeline_segments (
    property_id,
    name,
    location,
    segment_type,
    diameter,
    material,
    age_years
)
VALUES (
    'your-property-id',
    'Kitchen Line',
    'Kitchen',
    'main',
    '0.5',
    'copper',
    5
)
ON CONFLICT DO NOTHING;
```

### 3. Register Kitchen Device

The device will auto-register when ESP32 starts, or manually:

```sql
INSERT INTO water_connection_control (
    device_id,
    device_name,
    location,
    valve_status,
    is_online
)
VALUES (
    'ESP_KITCHEN_001',
    'Kitchen Water Line',
    'Kitchen',
    'closed',
    true
);
```

## LCD Display

### Normal Operation
```
Kitchen: 5.20L/m
Total: 125.5L OPEN
```

### Leak Detected
```
KITCHEN LEAK!
Flow: 0.50 L/m
```

## Testing

### 1. Test Kitchen Flow Sensor

1. Turn on kitchen faucet
2. Check Serial Monitor for flow readings
3. Verify LCD shows kitchen flow rate
4. Check Supabase for sensor readings

### 2. Test Kitchen Leak Detection

1. Create small drip in kitchen (0.2-2.0 L/min)
2. Kitchen valve should close automatically
3. Buzzer should sound
4. LCD should show "KITCHEN LEAK!"
5. Check Supabase for leak detection with location "Kitchen"

### 3. Test Normal Kitchen Usage

1. Turn on kitchen faucet normally (≥ 2.0 L/min)
2. Kitchen valve should open
3. System should operate normally
4. No alarms

### 4. Test Remote Control

1. Send command to open kitchen valve
2. ESP32 should detect within 3 seconds
3. Kitchen valve should open
4. Verify in Supabase

## Integration with Flutter App

The Flutter app will automatically:
- ✅ Display kitchen water flow
- ✅ Show kitchen leak alerts
- ✅ Allow remote kitchen valve control
- ✅ Display kitchen water usage
- ✅ Show kitchen-specific notifications

## Kitchen-Specific Features

✅ **Kitchen Leak Detection** - Detects leaks in kitchen water line  
✅ **Kitchen Valve Control** - Automatic and remote control  
✅ **Kitchen Monitoring** - Real-time kitchen water usage  
✅ **Kitchen Alerts** - Buzzer and LCD alerts for kitchen leaks  
✅ **Kitchen Data** - All data tagged with "Kitchen" location  

## Troubleshooting

### Kitchen Valve Not Responding

1. Check relay wiring (GPIO 26)
2. Verify valve is connected to kitchen line
3. Test relay manually
4. Check power supply

### Kitchen Flow Sensor Issues

1. Verify sensor is on kitchen water line
2. Check wiring (GPIO 27)
3. Test calibration factor
4. Check for air bubbles in sensor

### Kitchen Leak False Alarms

1. Adjust leak threshold if needed:
   ```cpp
   const float leakThreshold = 0.2;   // Increase if too sensitive
   const float startThreshold = 2.0;  // Adjust based on normal kitchen usage
   ```

2. Check for actual leaks in kitchen
3. Verify sensor is reading correctly

## Next Steps

1. ✅ Upload code to ESP32
2. ✅ Configure WiFi and Supabase
3. ✅ Get kitchen segment_id from database
4. ✅ Run SQL scripts
5. ✅ Test kitchen system
6. ✅ Monitor in Flutter app

Your kitchen water control system is ready!



