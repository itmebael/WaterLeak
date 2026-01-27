-- Kitchen Valve Control Commands
-- Quick reference for controlling ESP_KITCHEN_001

-- ============================================
-- OPEN KITCHEN VALVE (Recommended Method)
-- ============================================
-- This sends a command to ESP32, which will physically open the valve
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'open_valve', 'pending');

-- Also update status directly (for immediate UI update)
UPDATE water_connection_control
SET 
  valve_status = 'open',
  is_online = true,
  last_heartbeat = NOW(),
  updated_at = NOW()
WHERE device_id = 'ESP_KITCHEN_001';

-- ============================================
-- CLOSE KITCHEN VALVE
-- ============================================
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'close_valve', 'pending');

UPDATE water_connection_control
SET 
  valve_status = 'closed',
  is_online = true,
  last_heartbeat = NOW(),
  updated_at = NOW()
WHERE device_id = 'ESP_KITCHEN_001';

-- ============================================
-- ENABLE AUTO CONTROL
-- ============================================
INSERT INTO water_connection_commands (device_id, command_type, status)
VALUES ('ESP_KITCHEN_001', 'enable_auto', 'pending');

-- ============================================
-- SET DEVICE ONLINE/OFFLINE
-- ============================================
-- Set online
UPDATE water_connection_control
SET 
  is_online = true,
  last_heartbeat = NOW(),
  updated_at = NOW()
WHERE device_id = 'ESP_KITCHEN_001';

-- Set offline
UPDATE water_connection_control
SET 
  is_online = false,
  updated_at = NOW()
WHERE device_id = 'ESP_KITCHEN_001';

-- ============================================
-- CHECK STATUS
-- ============================================
SELECT 
  device_id,
  device_name,
  valve_status,
  water_flow,
  is_online,
  last_heartbeat,
  location,
  created_at,
  updated_at
FROM water_connection_control
WHERE device_id = 'ESP_KITCHEN_001';

-- ============================================
-- VIEW RECENT COMMANDS
-- ============================================
SELECT 
  id,
  command_type,
  status,
  created_at,
  executed_at,
  error_message
FROM water_connection_commands
WHERE device_id = 'ESP_KITCHEN_001'
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- CLEAR OLD COMMANDS (Optional)
-- ============================================
-- Delete executed commands older than 24 hours
DELETE FROM water_connection_commands
WHERE device_id = 'ESP_KITCHEN_001'
  AND status = 'executed'
  AND executed_at < NOW() - INTERVAL '24 hours';



