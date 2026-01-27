# Arduino ESP8266 Water Leak Sensor Setup

## Hardware Requirements
- ESP8266 (NodeMCU, Wemos D1 Mini, or similar)
- Water leak sensor (conductive sensor, moisture sensor, or float switch)
- Breadboard and jumper wires
- Power supply (USB or external 3.3V)

## Circuit Connection
```
ESP8266 Pin    Water Leak Sensor
3.3V          VCC
GND           GND
D2            Signal (Digital Input)
```

## Arduino Code Setup

### 1. Install Required Libraries
In Arduino IDE, install these libraries:
- ESP8266WiFi
- ESP8266HTTPClient

### 2. Update Configuration
Replace the placeholders in your Arduino code:

```cpp
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* supabaseUrl = "https://YOUR_PROJECT_ID.supabase.co/rest/v1/events";
const char* supabaseKey = "YOUR_SUPABASE_SERVICE_KEY";
```

### 3. Database Schema
Make sure your Supabase database has an `events` table with this structure:

```sql
CREATE TABLE events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_type TEXT NOT NULL,
  message TEXT NOT NULL,
  sensor_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  metadata JSONB
);
```

### 4. Testing the Sensor
1. Upload the code to your ESP8266
2. Open Serial Monitor (115200 baud)
3. Check WiFi connection status
4. Test by triggering the water leak sensor
5. Verify data appears in Supabase dashboard

## Flutter Integration

The Flutter app will automatically:
- Display real-time sensor status
- Show recent water leak events
- Provide alerts when leaks are detected
- Allow manual refresh of sensor data

## Troubleshooting

### Common Issues:
1. **WiFi Connection Failed**: Check SSID/password and WiFi signal strength
2. **Supabase Connection Failed**: Verify URL and API key
3. **Sensor Not Responding**: Check wiring and sensor power
4. **Data Not Appearing**: Check Supabase table permissions and RLS policies

### Debug Steps:
1. Check Serial Monitor for error messages
2. Verify Supabase API key permissions
3. Test Supabase connection with Postman/curl
4. Check Flutter app logs for connection errors

## Security Notes
- Use environment variables for sensitive data in production
- Implement proper authentication for Arduino commands
- Consider using HTTPS for production deployments
- Set up proper RLS policies in Supabase
