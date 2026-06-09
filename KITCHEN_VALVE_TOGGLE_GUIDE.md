# How to Toggle Kitchen Valve On/Off

There are **3 ways** to toggle the kitchen valve:

## Method 1: Via Supabase SQL (Direct Control)

### Open Kitchen Valve

Run this SQL in Supabase SQL Editor:

```sql
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'open_valve', 'pending');
```

The ESP32 will detect this command within 3 seconds and open the valve.

### Close Kitchen Valve

```sql
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'close_valve', 'pending');
```

### Enable Auto Control

```sql
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'enable_auto', 'pending');
```

### Check Current Status

```sql
SELECT device_id, device_name, valve_status, water_flow, is_online, last_heartbeat
FROM water_connection_control
WHERE device_id = 'ESP_KITCHEN_001';
```

## Method 2: Via Flutter App (Switch View)

The Flutter app has a kitchen toggle switch, but it currently updates the `device_status` table. To make it work with ESP32, we need to update the code to send commands to `water_connection_commands` table.

### Current Flutter App Toggle

1. Open the app
2. Go to **Switch View** (water switch controls)
3. Toggle the **Kitchen** switch ON/OFF
4. Currently updates `device_status` table

### Update Flutter Code to Work with ESP32

The `_updateDeviceStatusForLocation` function needs to be updated to send commands to ESP32. Here's what needs to be changed:

```dart
Future<void> _updateDeviceStatusForLocation(String location, bool isOn) async {
  if (location.toLowerCase() == 'kitchen') {
    // Send command to ESP32 kitchen device
    try {
      await _supabaseService.sendValveCommand(
        deviceId: 'ESP_KITCHEN_001',
        commandType: isOn ? 'open_valve' : 'close_valve',
      );
      print('✅ Kitchen valve command sent: ${isOn ? "OPEN" : "CLOSED"}');
    } catch (e) {
      print('❌ Failed to send kitchen command: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to control kitchen valve: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } else {
    // Existing code for other locations
    // ...
  }
}
```

You'll also need to add this method to `SupabaseService`:

```dart
Future<void> sendValveCommand({
  required String deviceId,
  required String commandType,
}) async {
  await _client
      .from('water_connection_commands')
      .insert({
        'device_id': deviceId,
        'command_type': commandType,
        'status': 'pending',
      });
}
```

## Method 3: Direct Update (Not Recommended)

You can directly update the valve status, but ESP32 won't automatically sync:

```sql
UPDATE water_connection_control
SET valve_status = 'open'  -- or 'closed'
WHERE device_id = 'ESP_KITCHEN_001';
```

**Note:** This method doesn't send a command to ESP32, so the physical valve won't change. Use Method 1 instead.

## How ESP32 Responds

1. **ESP32 checks for commands** every 3 seconds
2. When it finds a pending command:
   - Executes the command (opens/closes valve)
   - Updates command status to "executed"
   - Updates `water_connection_control` table with new status
   - Updates LCD display

## Verify Valve Status

### Check in Supabase

```sql
-- Check device status
SELECT device_id, valve_status, water_flow, is_online, last_heartbeat
FROM water_connection_control
WHERE device_id = 'ESP_KITCHEN_001';

-- Check recent commands
SELECT command_type, status, executed_at, created_at
FROM water_connection_commands
WHERE device_id = 'ESP_KITCHEN_001'
ORDER BY created_at DESC
LIMIT 5;
```

### Check ESP32 Serial Monitor

Open Serial Monitor (115200 baud) and you'll see:
- `Received command: open_valve` or `close_valve`
- `Valve OPENED` or `Valve CLOSED`
- Status updates

### Check LCD Display

The LCD on ESP32 will show:
- **Normal**: `Kitchen: X.XX L/m` with `OPEN` or `CLOSED` status
- **Leak**: `KITCHEN LEAK!`

## Troubleshooting

### Valve Not Responding

1. **Check ESP32 is online**:
   ```sql
   SELECT is_online, last_heartbeat 
   FROM water_connection_control 
   WHERE device_id = 'ESP_KITCHEN_001';
   ```
   - If `is_online = false` or `last_heartbeat` is old, ESP32 is not connected

2. **Check command status**:
   ```sql
   SELECT status, error_message 
   FROM water_connection_commands 
   WHERE device_id = 'ESP_KITCHEN_001' 
   ORDER BY created_at DESC 
   LIMIT 1;
   ```
   - If status is "failed", check error_message

3. **Check Serial Monitor** on ESP32 for error messages

4. **Verify WiFi connection** - ESP32 must be connected to WiFi

5. **Verify Supabase connection** - Check ESP32 Serial Monitor for connection errors

### Commands Not Executing

1. Make sure command status is `'pending'` (not already executed)
2. Check device_id matches exactly: `'ESP_KITCHEN_001'`
3. Verify ESP32 is checking commands (check Serial Monitor)
4. Check RLS policies allow ESP32 to read commands

## Quick Reference

| Action | SQL Command |
|--------|-------------|
| **Open Kitchen Valve** | `INSERT INTO water_connection_commands (device_id, command_type, status) VALUES ('ESP_KITCHEN_001', 'open_valve', 'pending');` |
| **Close Kitchen Valve** | `INSERT INTO water_connection_commands (device_id, command_type, status) VALUES ('ESP_KITCHEN_001', 'close_valve', 'pending');` |
| **Enable Auto Control** | `INSERT INTO water_connection_commands (device_id, command_type, status) VALUES ('ESP_KITCHEN_001', 'enable_auto', 'pending');` |
| **Check Status** | `SELECT valve_status, water_flow, is_online FROM water_connection_control WHERE device_id = 'ESP_KITCHEN_001';` |

## Integration with Flutter App

To make the Flutter app toggle work with ESP32, update the `switch_view.dart` file to send commands to `water_connection_commands` table instead of (or in addition to) updating `device_status` table.

The ESP32 will automatically sync its status back to `water_connection_control` table, which the Flutter app can read to show current valve status.












