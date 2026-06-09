# Water Connection Control Integration Guide

This guide explains how to use the integrated ESP32 code that connects your water valve control system to Supabase.

## Hardware Setup

### Pin Connections (Your Configuration)

```
Component          ESP32 Pin
----------------   ---------
Flow Sensor        GPIO 27
Buzzer             GPIO 25
Valve Relay        GPIO 26
LCD SDA            GPIO 21 (I2C)
LCD SCL            GPIO 22 (I2C)
```

### Valve Control Logic

- **HIGH (1)** = Valve CLOSED (relay active)
- **LOW (0)** = Valve OPEN (relay inactive)

This matches your original code logic.

## Code Configuration

### 1. Update WiFi Credentials

```cpp
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
```

### 2. Update Supabase Configuration

```cpp
const char* supabaseUrl = "https://YOUR_PROJECT_ID.supabase.co";
const char* supabaseKey = "YOUR_SUPABASE_ANON_KEY";
```

Get these from:
- Supabase Dashboard → Settings → API
- Or from your `supabase_config.dart` file

### 3. Get Database IDs

Run these queries in Supabase SQL Editor:

```sql
-- Get segment ID
SELECT id, name FROM pipeline_segments;

-- Get property ID
SELECT id, property_name FROM properties;
```

Update in code:

```cpp
const char* segmentId = "your-segment-uuid-here";
const char* propertyId = "your-property-uuid-here";
```

### 4. Adjust Flow Calibration

If your flow sensor calibration is different:

```cpp
const float calibrationFactor = 7.5; // Adjust based on your sensor
```

### 5. Adjust Leak Thresholds

```cpp
const float leakThreshold = 0.2;   // L/min - leak detected
const float startThreshold = 2.0; // L/min - normal flow
```

## How It Works

### Automatic Leak Detection

1. **Leak Detected** (0.2 - 2.0 L/min):
   - Valve automatically CLOSES
   - Buzzer sounds
   - Leak reported to Supabase
   - LCD shows "LEAK DETECTED!"

2. **Normal Flow** (≥ 2.0 L/min):
   - Valve automatically OPENS
   - Buzzer off
   - System operates normally

3. **No Flow** (< 0.2 L/min):
   - Valve CLOSES
   - Buzzer off
   - System ready

### Remote Control via Supabase

You can control the valve remotely by inserting a command in Supabase:

```sql
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_WATER_001', 'open_valve', 'pending');
```

Available commands:
- `open_valve` - Opens valve manually
- `close_valve` - Closes valve manually
- `enable_auto` - Re-enables automatic control
- `get_status` - Updates device status

### Data Sent to Supabase

1. **Sensor Readings** (every 5 seconds):
   - Flow rate
   - Sensor status
   - Timestamp

2. **Device Status** (every 5 seconds):
   - Valve status (open/closed)
   - Current flow rate
   - Online status
   - Last heartbeat

3. **Leak Detections** (when detected):
   - Leak type
   - Severity
   - Flow rate anomaly
   - Location
   - Timestamp

## Database Setup

Make sure you've run the SQL scripts:

1. **Main database setup**: `setup_database.sql` or `esp32_leak_detection_sql.sql`
2. **Water connection control**: `water_connection_control.sql`

## Testing

### 1. Test Flow Sensor

1. Upload code to ESP32
2. Open Serial Monitor (115200 baud)
3. Run water through sensor
4. Check Serial Monitor for flow readings
5. Verify LCD displays flow rate

### 2. Test Leak Detection

1. Create small leak (drip) - flow between 0.2-2.0 L/min
2. Valve should close automatically
3. Buzzer should sound
4. LCD should show "LEAK DETECTED!"
5. Check Supabase for leak detection entry

### 3. Test Remote Control

1. Insert command in Supabase:
   ```sql
   INSERT INTO water_connection_commands (device_id, command_type, status)
   VALUES ('ESP_WATER_001', 'open_valve', 'pending');
   ```
2. ESP32 should detect command within 3 seconds
3. Valve should open
4. Command status should update to "executed"

### 4. Test Normal Flow

1. Create normal flow (≥ 2.0 L/min)
2. Valve should open automatically
3. System should operate normally
4. No alarms

## LCD Display

### Normal Operation
```
Flow: 5.20 L/m
Total: 125.5L OPEN
```

### Leak Detected
```
LEAK DETECTED!
Flow: 0.50 L/m
```

## Troubleshooting

### Flow Sensor Not Working

1. Check wiring (GPIO 27)
2. Verify interrupt is attached
3. Check calibration factor
4. Test with Serial Monitor

### Valve Not Responding

1. Check relay wiring (GPIO 26)
2. Verify relay logic (HIGH = closed)
3. Test relay manually
4. Check power supply

### WiFi Not Connecting

1. Check SSID and password
2. Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz in station mode)
3. Check signal strength
4. Verify credentials

### Supabase Connection Failed

1. Check Supabase URL and API key
2. Verify RLS policies allow inserts
3. Check Serial Monitor for HTTP error codes
4. Verify segment_id and property_id are correct UUIDs

### Commands Not Executing

1. Check `water_connection_commands` table
2. Verify device_id matches in code and database
3. Check command status (should be "pending")
4. Verify RLS policies allow reads

## Features

✅ **Automatic Leak Detection** - Detects leaks based on flow rate  
✅ **Automatic Valve Control** - Opens/closes valve based on flow  
✅ **Remote Control** - Control valve via Supabase commands  
✅ **Real-time Monitoring** - Data sent to Supabase every 5 seconds  
✅ **LCD Display** - Shows current status and flow rate  
✅ **Buzzer Alarm** - Sounds when leak detected  
✅ **WiFi Connectivity** - Connects to your WiFi network  
✅ **Supabase Integration** - Full integration with your database  

## Next Steps

1. Upload code to ESP32
2. Configure WiFi and Supabase credentials
3. Get segment_id and property_id from database
4. Run SQL scripts in Supabase
5. Test the system
6. Monitor in Flutter app

The system is now fully integrated and ready to use!












