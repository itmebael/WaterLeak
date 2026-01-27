-- Open Kitchen Valve and Set Online
-- Run this in Supabase SQL Editor

-- Method 1: Direct Update (Quick but ESP32 won't automatically sync)
UPDATE water_connection_control
SET 
  valve_status = 'open',
  is_online = true,
  last_heartbeat = NOW(),
  updated_at = NOW()
WHERE device_id = 'ESP_KITCHEN_001';

-- Method 2: Send Command to ESP32 (Recommended - ESP32 will execute and sync)
-- This is better because ESP32 will physically open the valve
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'open_valve', 'pending')
ON CONFLICT DO NOTHING;

-- Verify the update
SELECT 
  device_id,
  device_name,
  valve_status,
  water_flow,
  is_online,
  last_heartbeat,
  location,
  updated_at
FROM water_connection_control
WHERE device_id = 'ESP_KITCHEN_001';

-- Check if command was sent
SELECT 
  command_type,
  status,
  created_at,
  executed_at
FROM water_connection_commands
WHERE device_id = 'ESP_KITCHEN_001'
ORDER BY created_at DESC
LIMIT 1;



