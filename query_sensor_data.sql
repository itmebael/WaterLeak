-- ============================================
-- Query Sensor Data from water_connection_control
-- ============================================
-- This SQL shows where sensor readings are saved
-- Run this in Supabase SQL Editor

-- ============================================
-- 1. View Current Sensor Readings
-- ============================================
-- Shows the latest sensor data for all devices
SELECT 
  device_id,
  device_name,
  location,
  valve_status,
  water_flow,
  total_water_used,
  is_online,
  last_heartbeat,
  -- Extract sensor data from JSONB
  sensor_data->>'water_sensor_1_value' AS sensor1_adc,
  sensor_data->>'water_sensor_1_percent' AS sensor1_percent,
  sensor_data->>'water_sensor_1_detected' AS sensor1_detected,
  sensor_data->>'water_sensor_2_value' AS sensor2_adc,
  sensor_data->>'water_sensor_2_percent' AS sensor2_percent,
  sensor_data->>'water_sensor_2_detected' AS sensor2_detected,
  sensor_data->>'water_leak_detected' AS leak_detected,
  -- Show full JSONB for debugging
  sensor_data,
  updated_at
FROM water_connection_control
ORDER BY last_heartbeat DESC;

-- ============================================
-- 2. View Sensor Data for Specific Device
-- ============================================
-- Replace 'ESP_KITCHEN_001' with your device_id
SELECT 
  device_id,
  device_name,
  valve_status,
  sensor_data->>'water_sensor_1_value' AS "S1 ADC",
  sensor_data->>'water_sensor_1_percent' AS "S1 %",
  sensor_data->>'water_sensor_1_detected' AS "S1 Leak",
  sensor_data->>'water_sensor_2_value' AS "S2 ADC",
  sensor_data->>'water_sensor_2_percent' AS "S2 %",
  sensor_data->>'water_sensor_2_detected' AS "S2 Leak",
  sensor_data->>'water_leak_detected' AS "Overall Leak",
  last_heartbeat,
  updated_at
FROM water_connection_control
WHERE device_id = 'ESP_KITCHEN_001';

-- ============================================
-- 3. View Full JSONB Sensor Data
-- ============================================
SELECT 
  device_id,
  sensor_data,  -- Full JSONB object
  last_heartbeat
FROM water_connection_control
WHERE device_id = 'ESP_KITCHEN_001';

-- ============================================
-- 4. Check if sensor_data column exists
-- ============================================
-- Run this first to verify the column exists
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'water_connection_control' 
AND column_name = 'sensor_data';

-- ============================================
-- 5. Query Sensor History (if history table has sensor_data)
-- ============================================
-- This queries the history table if it has sensor_data column
SELECT 
  device_id,
  recorded_at,
  valve_status,
  sensor_data->>'water_sensor_1_percent' AS sensor1_percent,
  sensor_data->>'water_sensor_2_percent' AS sensor2_percent,
  sensor_data->>'water_leak_detected' AS leak_detected
FROM water_connection_control_history
WHERE device_id = 'ESP_KITCHEN_001'
ORDER BY recorded_at DESC
LIMIT 100;

-- ============================================
-- 6. Find Devices with Active Leaks
-- ============================================
-- Shows devices where sensors detect water (>= 25%)
SELECT 
  device_id,
  device_name,
  location,
  sensor_data->>'water_sensor_1_percent' AS sensor1_percent,
  sensor_data->>'water_sensor_2_percent' AS sensor2_percent,
  sensor_data->>'water_leak_detected' AS leak_detected,
  valve_status,
  last_heartbeat
FROM water_connection_control
WHERE sensor_data->>'water_leak_detected' = 'true'
ORDER BY last_heartbeat DESC;

-- ============================================
-- 7. Example JSONB Structure
-- ============================================
-- The sensor_data JSONB column contains:
-- {
--   "water_sensor_1_value": 0,           // ADC value (0-4095)
--   "water_sensor_1_percent": 0.0,       // Percentage (0-100%)
--   "water_sensor_1_detected": false,    // true if >= 25%
--   "water_sensor_2_value": 0,           // ADC value (0-4095)
--   "water_sensor_2_percent": 0.0,       // Percentage (0-100%)
--   "water_sensor_2_detected": false,    // true if >= 25%
--   "water_leak_detected": false         // Overall leak status
-- }




