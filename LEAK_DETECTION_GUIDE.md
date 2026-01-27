# Water Leak Detection System Guide

This guide explains how the water leak detection system works and how to set it up with ESP devices.

## How Leak Detection Works

The system uses **multiple detection methods** to identify water leaks with high accuracy:

### 1. Direct Leak Sensor Detection
- **Sensor Type**: Conductive sensor, moisture sensor, or float switch
- **How it works**: Sensor detects water/moisture directly at the sensor location
- **Best for**: Detecting leaks in specific areas (under sinks, near appliances, basements)
- **Advantage**: Immediate detection when water touches sensor
- **Limitation**: Only detects leaks at sensor location

### 2. Flow-Based Detection
- **Sensor Type**: Water flow sensor (YF-S201 or similar)
- **How it works**: Detects unexpected water flow when no water should be running
- **Detection Logic**:
  - **Suspicious Flow**: Flow > 10 L/min for 3+ minutes
  - **Critical Flow**: Flow > 25 L/min for 1+ minute
  - **Pattern Detection**: Multiple flow spikes in short time
- **Best for**: Detecting leaks in main water lines
- **Advantage**: Can detect leaks anywhere in the system
- **Limitation**: May trigger false alarms during normal water usage

### 3. Pressure-Based Detection
- **Sensor Type**: Pressure sensor (MPX5010DP or similar)
- **How it works**: Monitors water pressure - sudden drops indicate leaks
- **Detection Logic**:
  - Pressure drop > 5 PSI indicates potential leak
  - Pressure below minimum threshold (e.g., 10 PSI) indicates leak
- **Best for**: Detecting burst pipes or major leaks
- **Advantage**: Very sensitive to major leaks
- **Limitation**: May not detect slow, small leaks

### 4. Pattern-Based Detection
- **How it works**: Analyzes flow patterns over time
- **Detection Logic**:
  - Sustained abnormal flow patterns
  - Multiple suspicious flow spikes
  - Flow when valve should be closed
- **Best for**: Detecting intermittent leaks
- **Advantage**: Reduces false positives
- **Limitation**: Requires historical data

## Detection Algorithm (from Flutter App)

The Flutter app uses this algorithm (from `dashboard_view.dart`):

```dart
// Suspicious threshold: 15 L/min
// Critical threshold: 25 L/min
// Sustained window: 3 minutes for suspicious, 1 minute for critical
// Pattern detection: 5+ suspicious spikes + 2+ critical spikes
```

The Arduino code implements similar logic for real-time detection.

## Hardware Setup

### Required Components

1. **ESP8266/ESP32** - Main microcontroller
2. **Water Leak Sensor** - Direct leak detection
   - Conductive sensor (detects water contact)
   - Moisture sensor (detects humidity/moisture)
   - Float switch (detects water level)
3. **Water Flow Sensor** (Optional but recommended)
   - YF-S201 or similar
   - Measures flow rate in L/min
4. **Pressure Sensor** (Optional but recommended)
   - MPX5010DP or similar
   - Measures water pressure in PSI
5. **Relay Module** (For automatic shutoff)
   - Controls solenoid valve
6. **Solenoid Valve** (For automatic shutoff)
   - 12V DC or 24V AC
7. **Buzzer** (Optional - for local alerts)

### Pin Connections

```
ESP8266/ESP32 Pin    Component
------------------   -----------
GPIO 0 (D3)         Leak Sensor (Digital Input)
GPIO 4 (D2)         Flow Sensor Signal (Pulse Input)
A0                  Pressure Sensor (Analog Input)
GPIO 5 (D1)         Relay IN (Valve Control)
GPIO 2              Built-in LED (Status)
GPIO 14 (D5)        Buzzer (Optional)
3.3V                Sensor VCC
GND                 Sensor GND, Relay GND
```

### Leak Sensor Wiring

**Conductive Sensor:**
```
Sensor Wire 1 → GPIO 0 (D3)
Sensor Wire 2 → GND
(When water bridges wires, GPIO reads LOW)
```

**Moisture Sensor:**
```
VCC → 3.3V
GND → GND
DO (Digital Out) → GPIO 0 (D3)
AO (Analog Out) → Not used (can use for sensitivity)
```

**Float Switch:**
```
Common → GPIO 0 (D3)
Normally Open → 3.3V (via pull-up)
(When float rises, switch closes, GPIO reads LOW)
```

## Software Setup

### 1. Install Libraries

In Arduino IDE, install:
- **ESP8266WiFi** (or **WiFi.h** for ESP32)
- **ESP8266HTTPClient** (or **HTTPClient.h** for ESP32)
- **ArduinoJson** (v6.x)

### 2. Configure Code

Edit `arduino_esp_leak_detection.ino`:

```cpp
// WiFi
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Supabase
const char* supabaseUrl = "https://YOUR_PROJECT_ID.supabase.co";
const char* supabaseKey = "YOUR_SUPABASE_ANON_KEY";

// Device IDs (link to your database)
const char* deviceId = "LEAK_SENSOR_001";
const char* segmentId = "SEGMENT_001";  // From pipeline_segments table
const char* propertyId = "PROPERTY_001"; // From properties table
```

### 3. Adjust Detection Thresholds

Customize based on your water system:

```cpp
#define MIN_PRESSURE_PSI 10.0          // Minimum normal pressure
#define MAX_FLOW_LPM 15.0              // Maximum normal flow
#define SUSPICIOUS_FLOW_LPM 10.0       // Suspicious flow threshold
#define CRITICAL_FLOW_LPM 25.0         // Critical flow threshold
#define PRESSURE_DROP_THRESHOLD 5.0    // PSI drop indicating leak
```

### 4. Calibrate Sensors

**Flow Sensor Calibration:**
- Check your sensor datasheet for pulses per liter
- YF-S201: ~450 pulses per liter
- Adjust `FLOW_PULSE_PER_LITER` if different

**Pressure Sensor Calibration:**
- Formula depends on your sensor model
- MPX5010DP: `PSI = (Voltage - 0.2) / 0.09`
- Adjust formula in `readPressure()` function

## Database Integration

### Tables Used

1. **sensor_readings** - Stores sensor data
   - `segment_id` - Links to pipeline segment
   - `pressure_psi` - Current pressure
   - `flow_rate_lpm` - Current flow rate
   - `sensor_status` - 'normal', 'warning', 'error'

2. **water_leak_detections** - Stores detected leaks
   - `property_id` - Property where leak detected
   - `segment_id` - Pipeline segment
   - `leak_type` - 'continuous', 'intermittent', 'drip', 'burst'
   - `severity` - 'low', 'medium', 'high', 'critical'
   - `status` - 'active', 'resolved', 'investigating'
   - `estimated_water_loss_rate` - L/hour
   - `pressure_drop` - PSI drop
   - `flow_rate_anomaly` - Anomalous flow rate

3. **leak_notifications** - User notifications
   - Created automatically when leak detected
   - Shown in Flutter app

### Automatic Actions

When leak is detected:
1. ✅ Leak logged to `water_leak_detections` table
2. ✅ Notification created in `leak_notifications` table
3. ✅ Sensor readings updated with 'warning' status
4. ✅ Valve automatically closed (if `autoShutoffEnabled = true`)
5. ✅ LED and buzzer activated for local alert

## Testing

### Test Direct Leak Sensor

1. Upload code to ESP
2. Open Serial Monitor (115200 baud)
3. Touch leak sensor with wet finger/water
4. Should see: "⚠️ DIRECT LEAK SENSOR TRIGGERED!"
5. Check Supabase for leak detection entry

### Test Flow-Based Detection

1. Ensure valve is closed (or simulate closed state)
2. Create water flow > 15 L/min
3. Wait 3+ minutes
4. Should see: "⚠️ SUSPICIOUS FLOW DETECTED"
5. Check Supabase for leak detection

### Test Pressure-Based Detection

1. Note current pressure reading
2. Simulate pressure drop (open valve downstream)
3. If pressure drops > 5 PSI, leak should be detected
4. Check Supabase for leak detection

### Test Automatic Shutoff

1. Trigger leak detection
2. Verify relay activates (valve closes)
3. Check Serial Monitor for "🛑 EMERGENCY SHUTOFF ACTIVATED!"

## False Positive Prevention

The system includes several mechanisms to reduce false positives:

1. **Sustained Detection**: Leaks must be detected for a minimum duration
2. **Multiple Methods**: Requires confirmation from multiple sensors when possible
3. **Pattern Analysis**: Looks for abnormal patterns, not just single readings
4. **Cooldown Period**: Prevents duplicate alerts for same leak

### Adjusting Sensitivity

**Reduce False Positives:**
- Increase `SUSPICIOUS_FLOW_LPM` threshold
- Increase `PRESSURE_DROP_THRESHOLD`
- Increase sustained duration requirements
- Disable auto-shutoff for testing

**Increase Sensitivity:**
- Decrease thresholds
- Reduce sustained duration requirements
- Enable all detection methods

## Troubleshooting

### Leak Not Detected

1. **Check sensor wiring** - Verify connections
2. **Check thresholds** - May be too high for your system
3. **Check Serial Monitor** - Look for sensor readings
4. **Verify Supabase connection** - Check WiFi and API key
5. **Test sensors individually** - Verify each sensor works

### False Alarms

1. **Adjust thresholds** - Increase detection thresholds
2. **Check normal usage patterns** - Account for normal water usage
3. **Review detection logic** - May need to exclude certain times
4. **Calibrate sensors** - Ensure accurate readings

### No Data in Supabase

1. **Check WiFi connection** - Verify ESP is connected
2. **Check Supabase URL and key** - Verify credentials
3. **Check RLS policies** - Ensure policies allow inserts
4. **Check Serial Monitor** - Look for HTTP error codes
5. **Verify table names** - Match exactly with database

### Valve Not Closing

1. **Check relay wiring** - Verify connections
2. **Test relay manually** - Ensure relay works
3. **Check solenoid valve** - Verify valve power supply
4. **Check `autoShutoffEnabled`** - Must be `true`
5. **Verify relay logic** - HIGH = closed, LOW = open

## Integration with Flutter App

The Flutter app automatically:
- ✅ Displays leak detections in real-time
- ✅ Shows notifications when leaks detected
- ✅ Displays sensor readings and status
- ✅ Allows manual leak resolution
- ✅ Shows leak history and statistics

No additional Flutter code needed - the app reads from Supabase tables that the ESP device writes to.

## Advanced Features

### Multiple Sensors

To use multiple leak sensors:
1. Connect additional sensors to different GPIO pins
2. Add detection logic for each sensor
3. Include sensor ID in leak reports

### Remote Valve Control

The ESP can also receive valve control commands from Supabase (see `arduino_esp_water_control.ino` for reference).

### Battery Backup

For critical applications:
- Use battery backup for ESP
- Use low-power mode when possible
- Monitor battery level in sensor readings

## Security Notes

⚠️ **Important:**
- Leak detection is critical - ensure reliable WiFi connection
- Consider redundant sensors for critical areas
- Test regularly to ensure system is working
- Keep Supabase credentials secure
- Use HTTPS in production (proper SSL certificates)

## Support

For issues:
1. Check Serial Monitor output
2. Verify Supabase table data
3. Test sensors individually
4. Review detection thresholds
5. Check wiring and connections



