# Water Connection Control Setup Guide

This guide explains how to set up ESP8266/ESP32 devices to control water valves remotely through Supabase.

## Files Included

1. **water_connection_control.sql** - Database schema for water connection control
2. **arduino_esp_water_control.ino** - Arduino code for ESP8266/ESP32

## Hardware Requirements

### Components Needed:
- **ESP8266** (NodeMCU, Wemos D1 Mini) or **ESP32**
- **Relay Module** (5V, single channel) - Controls solenoid valve
- **Solenoid Valve** (12V DC or 24V AC depending on your water system)
- **Water Flow Sensor** (YF-S201 or similar) - Optional but recommended
- **Power Supply** - 5V for ESP, 12V/24V for solenoid valve
- **Breadboard and jumper wires**
- **Resistors** (if needed for voltage level shifting)

### Pin Connections:

```
ESP8266/ESP32 Pin    Component
------------------   -----------
GPIO 5 (D1)         Relay IN (controls valve)
GPIO 4 (D2)         Flow Sensor Signal (pulse input)
GPIO 2              Built-in LED (status indicator)
3.3V                Relay VCC
GND                 Relay GND, Flow Sensor GND
A0                  Pressure Sensor (optional)
```

### Relay to Solenoid Valve:
```
Relay Module        Solenoid Valve
-----------        ---------------
NO (Normally Open) Valve Positive (+)
COM (Common)       Power Supply Positive (+)
Power Supply GND   Valve Negative (-)
```

## Software Setup

### 1. Install Arduino IDE Libraries

Open Arduino IDE and install these libraries via Library Manager:

- **ESP8266WiFi** (or **WiFi.h** for ESP32)
- **ESP8266HTTPClient** (or **HTTPClient.h** for ESP32)
- **ArduinoJson** (v6.x) - **Important: Use version 6.x, not 7.x**

For ESP32, you may also need:
- **WiFiClientSecure**

### 2. Configure Arduino Code

Edit `arduino_esp_water_control.ino` and update these values:

```cpp
// WiFi Credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Supabase Configuration
const char* supabaseUrl = "https://YOUR_PROJECT_ID.supabase.co";
const char* supabaseKey = "YOUR_SUPABASE_ANON_KEY";

// Device Configuration
const char* deviceId = "ESP_001";  // Unique for each device
const char* deviceName = "Main Water Line";
const char* location = "Main Entry";
```

**Important:** Get your Supabase URL and Anon Key from:
- Supabase Dashboard → Settings → API
- URL: `https://ituksombwexvutmxcmsv.supabase.co`
- Anon Key: Found in your `supabase_config.dart` file

### 3. Adjust Pin Numbers (if needed)

If your hardware uses different pins, modify these in the code:

```cpp
#define VALVE_RELAY_PIN 5      // Change if using different pin
#define FLOW_SENSOR_PIN 4      // Change if using different pin
#define STATUS_LED_PIN 2       // Change if using different pin
```

### 4. Flow Sensor Calibration

If using a different flow sensor, adjust the calibration constant:

```cpp
#define FLOW_PULSE_PER_LITER 450  // YF-S201: 450 pulses/L
```

Check your sensor datasheet for the correct value.

## Database Setup

### 1. Run SQL Script

1. Open Supabase Dashboard
2. Go to **SQL Editor**
3. Copy and paste the entire contents of `water_connection_control.sql`
4. Click **Run** to execute

This will create:
- `water_connection_control` table - Device status and control
- `water_connection_commands` table - Command queue for ESP devices
- `water_connection_logs` table - Historical events and data
- All necessary RLS policies and indexes

### 2. Verify Tables

Check that the tables were created:
- Go to **Table Editor** in Supabase
- You should see the three new tables

## Uploading Code to ESP

### 1. Select Board

In Arduino IDE:
- **Tools → Board → ESP8266 Boards → NodeMCU 1.0** (for ESP8266)
- **Tools → Board → ESP32 Dev Module** (for ESP32)

### 2. Select Port

- **Tools → Port → COMx** (Windows) or **/dev/ttyUSBx** (Linux/Mac)

### 3. Upload

- Click **Upload** button
- Wait for compilation and upload to complete
- Open **Serial Monitor** (115200 baud) to see status

## Testing

### 1. Initial Test

1. Power on the ESP device
2. Open Serial Monitor (115200 baud)
3. You should see:
   - WiFi connection status
   - Device registration message
   - "System ready..." message

### 2. Test Valve Control

**Method 1: Via Supabase Dashboard**
1. Go to Supabase → Table Editor → `water_connection_commands`
2. Insert a new row:
   ```json
   {
     "device_id": "ESP_001",
     "command_type": "open_valve",
     "status": "pending"
   }
   ```
3. The ESP should detect and execute the command within 5 seconds
4. Check Serial Monitor for confirmation

**Method 2: Via Flutter App**
- Use the app's valve control interface to send commands

### 3. Monitor Status

Check device status in Supabase:
- `water_connection_control` table shows current valve state, flow rate, and online status
- `water_connection_logs` table shows all events (valve changes, flow detection, heartbeats)

## How It Works

### Command Flow:
1. **App/User** → Inserts command into `water_connection_commands` table
2. **ESP Device** → Polls commands table every 5 seconds
3. **ESP Device** → Executes command (opens/closes valve)
4. **ESP Device** → Updates command status to "executed"
5. **ESP Device** → Updates `water_connection_control` with new status
6. **ESP Device** → Logs event in `water_connection_logs`

### Data Flow:
1. **Flow Sensor** → Sends pulses to ESP (interrupt-driven)
2. **ESP Device** → Calculates flow rate every second
3. **ESP Device** → Sends heartbeat every 30 seconds with current status
4. **Supabase** → Stores all data for app to display

## Troubleshooting

### ESP Won't Connect to WiFi
- Check SSID and password
- Ensure WiFi is 2.4GHz (ESP doesn't support 5GHz)
- Check signal strength

### ESP Can't Connect to Supabase
- Verify Supabase URL and API key
- Check internet connection
- Verify RLS policies allow access

### Valve Not Responding
- Check relay wiring
- Verify solenoid valve power supply
- Test relay with multimeter
- Check Serial Monitor for error messages

### Flow Sensor Not Working
- Verify wiring (signal, VCC, GND)
- Check if sensor needs pull-up resistor
- Verify interrupt pin is correct
- Test sensor separately

### Commands Not Executing
- Check `water_connection_commands` table for pending commands
- Verify device_id matches in code and database
- Check Serial Monitor for command detection messages
- Verify RLS policies allow ESP to read/write

## Security Notes

⚠️ **Important Security Considerations:**

1. **API Key**: The anon key in Arduino code is readable. For production:
   - Use environment variables or secure storage
   - Consider using service role key with restricted access
   - Implement device authentication

2. **HTTPS**: The code uses `setInsecure()` for HTTPS. For production:
   - Use proper SSL certificates
   - Implement certificate pinning

3. **RLS Policies**: Current setup allows public access. For production:
   - Implement user-based RLS policies
   - Add device authentication tokens
   - Restrict command creation to authenticated users

## Multiple Devices

To set up multiple ESP devices:

1. **Change device_id** in each Arduino sketch:
   - Device 1: `"ESP_001"`
   - Device 2: `"ESP_002"`
   - Device 3: `"ESP_003"`
   - etc.

2. **Update device_name and location** for each device

3. **Upload code** to each ESP device

4. Each device will automatically register in the database

## Advanced Features

### Adding Pressure Sensor
1. Connect pressure sensor to A0
2. Add reading code in `loop()`
3. Include in `updateDeviceStatus()` JSON

### Adding Temperature Sensor
1. Connect DS18B20 or similar
2. Add OneWire library
3. Include reading in status updates

### Emergency Shutoff
- Add physical button connected to ESP
- On button press, close all valves
- Send emergency alert to Supabase

## Support

For issues or questions:
1. Check Serial Monitor output
2. Verify Supabase table data
3. Check WiFi and internet connectivity
4. Review RLS policies in Supabase




