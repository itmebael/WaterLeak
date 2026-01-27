-- ============================================
-- VIEW KITCHEN DEVICE DATA IN REAL-TIME
-- Run this in Supabase SQL Editor
-- 
-- IMPORTANT: First run add_total_water_used_column.sql to add the column!
-- ============================================

-- View current kitchen device status (with total water used)
-- Note: If you get an error about total_water_used not existing,
-- run add_total_water_used_column.sql first!
SELECT 
  device_id,
  device_name,
  location,
  valve_status,
  water_flow,
  COALESCE(total_water_used, 0.00) as total_water_used,  -- Use COALESCE in case column doesn't exist yet
  is_online,
  last_heartbeat,
  updated_at,
  created_at
FROM water_connection_control
WHERE device_id = 'ESP_KITCHEN_001'
ORDER BY updated_at DESC
LIMIT 1;

-- View recent updates (last 10 updates) with total
SELECT 
  device_id,
  valve_status,
  water_flow,
  COALESCE(total_water_used, 0.00) as total_water_used,
  is_online,
  last_heartbeat,
  updated_at
FROM water_connection_control
WHERE device_id = 'ESP_KITCHEN_001'
ORDER BY updated_at DESC
LIMIT 10;

-- View all kitchen devices with total water used
SELECT 
  device_id,
  device_name,
  location,
  valve_status,
  water_flow,
  COALESCE(total_water_used, 0.00) as total_water_used,
  is_online,
  last_heartbeat,
  updated_at
FROM water_connection_control
WHERE location ILIKE '%kitchen%'
ORDER BY updated_at DESC;

-- View sensor readings from kitchen
SELECT 
  reading_timestamp,
  flow_rate_lpm,
  sensor_status
FROM sensor_readings
WHERE segment_id = 'e6f043d2-f3ed-4ff4-b1d4-fb925434b7aa'  -- Your kitchen segment ID
ORDER BY reading_timestamp DESC
LIMIT 20;

-- View real-time flow data (live monitoring)
SELECT 
  reading_timestamp,
  flow_rate_lpm,
  sensor_status,
  EXTRACT(EPOCH FROM (NOW() - reading_timestamp)) as seconds_ago
FROM sensor_readings
WHERE segment_id = 'e6f043d2-f3ed-4ff4-b1d4-fb925434b7aa'
  AND reading_timestamp > NOW() - INTERVAL '1 hour'
ORDER BY reading_timestamp DESC;

