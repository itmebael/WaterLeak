-- ============================================
-- Water Sensor Status Queries - Real-time Monitoring
-- ============================================
-- Query sensor readings from water_connection_control table
-- Sensor data is saved every 5 seconds in sensor_data JSONB field
--
-- DETECTION THRESHOLD: 25%
-- - 1-25% = DRY (OK)
-- - 25-100% = WET (LEAK)
-- ============================================

-- ============================================
-- 1. Get Current Sensor Status
-- ============================================
-- View current sensor readings and leak status
CREATE OR REPLACE VIEW current_water_sensor_status AS
SELECT 
    device_id,
    device_name,
    location,
    valve_status,
    water_flow,
    total_water_used,
    is_online,
    last_heartbeat,
    (sensor_data->>'water_sensor_1_value')::INTEGER as sensor1_adc,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
    (sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
    (sensor_data->>'water_sensor_2_value')::INTEGER as sensor2_adc,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
    (sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
    (sensor_data->>'water_leak_detected')::BOOLEAN as leak_detected,
    CASE 
        WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
         AND (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Both Sensors (High)'
        WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'Sensor 1 Only (Medium)'
        WHEN (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Sensor 2 Only (Medium)'
        ELSE 'No Leak (OK)'
    END as leak_status,
    CASE 
        WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
         AND (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN '!!! LEAK !!!'
        WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'LEAK: SENSOR 1'
        WHEN (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'LEAK: SENSOR 2'
        ELSE 'Normal'
    END as lcd_display,
    EXTRACT(EPOCH FROM (NOW() - last_heartbeat)) as seconds_since_heartbeat
FROM water_connection_control
WHERE is_online = true
ORDER BY last_heartbeat DESC;

-- ============================================
-- 2. Get Devices with Active Leaks
-- ============================================
-- Shows devices where sensors are currently detecting leaks (>= 25%)
CREATE OR REPLACE VIEW devices_with_active_leaks AS
SELECT 
    device_id,
    device_name,
    location,
    valve_status,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
    (sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
    (sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
    CASE 
        WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
         AND (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN '!!! LEAK !!!'
        WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'LEAK: SENSOR 1'
        WHEN (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'LEAK: SENSOR 2'
        ELSE 'OK'
    END as lcd_display,
    last_heartbeat
FROM water_connection_control
WHERE is_online = true
  AND (
      (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true
      OR (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true
  )
ORDER BY last_heartbeat DESC;

-- ============================================
-- 3. Function: Get Sensor Status for Device
-- ============================================
CREATE OR REPLACE FUNCTION get_device_sensor_status(
    p_device_id VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    device_id VARCHAR,
    device_name TEXT,
    sensor1_percent NUMERIC,
    sensor2_percent NUMERIC,
    sensor1_detected BOOLEAN,
    sensor2_detected BOOLEAN,
    leak_detected BOOLEAN,
    leak_status TEXT,
    lcd_display TEXT,
    valve_status TEXT,
    buzzer_status TEXT,
    last_update TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wcc.device_id,
        wcc.device_name,
        (wcc.sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
        (wcc.sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
        (wcc.sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
        (wcc.sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
        (wcc.sensor_data->>'water_leak_detected')::BOOLEAN as leak_detected,
        CASE 
            WHEN (wcc.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
             AND (wcc.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Both Sensors (High)'
            WHEN (wcc.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'Sensor 1 Only (Medium)'
            WHEN (wcc.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Sensor 2 Only (Medium)'
            ELSE 'No Leak (OK)'
        END as leak_status,
        CASE 
            WHEN (wcc.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
             AND (wcc.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN '!!! LEAK !!!'
            WHEN (wcc.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'LEAK: SENSOR 1'
            WHEN (wcc.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'LEAK: SENSOR 2'
            ELSE 'Normal'
        END as lcd_display,
        wcc.valve_status,
        CASE 
            WHEN (wcc.sensor_data->>'water_leak_detected')::BOOLEAN = true THEN 'ON (Beeping)'
            ELSE 'OFF'
        END as buzzer_status,
        wcc.last_heartbeat as last_update
    FROM water_connection_control wcc
    WHERE wcc.is_online = true
      AND (p_device_id IS NULL OR wcc.device_id = p_device_id)
    ORDER BY wcc.last_heartbeat DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. Function: Get Sensor History from water_connection_control_history
-- ============================================
-- If sensor_data column exists in history table
CREATE OR REPLACE FUNCTION get_sensor_history(
    p_device_id VARCHAR DEFAULT NULL,
    p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
    recorded_at TIMESTAMPTZ,
    device_id VARCHAR,
    sensor1_percent NUMERIC,
    sensor2_percent NUMERIC,
    sensor1_detected BOOLEAN,
    sensor2_detected BOOLEAN,
    leak_detected BOOLEAN,
    valve_status TEXT,
    water_flow NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wcch.recorded_at,
        wcch.device_id,
        (wcch.sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
        (wcch.sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
        (wcch.sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
        (wcch.sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
        (wcch.sensor_data->>'water_leak_detected')::BOOLEAN as leak_detected,
        wcch.valve_status,
        wcch.water_flow
    FROM water_connection_control_history wcch
    WHERE wcch.recorded_at >= NOW() - (p_hours || ' hours')::INTERVAL
      AND (p_device_id IS NULL OR wcch.device_id = p_device_id)
      AND wcch.sensor_data IS NOT NULL
    ORDER BY wcch.recorded_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- USAGE EXAMPLES:
-- ============================================
-- 
-- 1. View current sensor status for all devices:
--    SELECT * FROM current_water_sensor_status;
--
-- 2. View devices with active leaks:
--    SELECT * FROM devices_with_active_leaks;
--
-- 3. Get sensor status for specific device:
--    SELECT * FROM get_device_sensor_status('ESP_KITCHEN_001');
--
-- 4. Get sensor history (last 24 hours):
--    SELECT * FROM get_sensor_history('ESP_KITCHEN_001', 24);
--
-- 5. Check if device has leak:
--    SELECT 
--      device_id,
--      (sensor_data->>'water_leak_detected')::BOOLEAN as has_leak,
--      (sensor_data->>'water_sensor_1_percent')::NUMERIC as s1_percent,
--      (sensor_data->>'water_sensor_2_percent')::NUMERIC as s2_percent
--    FROM water_connection_control
--    WHERE device_id = 'ESP_KITCHEN_001';
--
-- 6. Monitor sensor readings in real-time:
--    SELECT 
--      device_id,
--      last_heartbeat,
--      sensor_data->>'water_sensor_1_percent' as s1_percent,
--      sensor_data->>'water_sensor_2_percent' as s2_percent,
--      sensor_data->>'water_leak_detected' as leak,
--      valve_status
--    FROM water_connection_control
--    WHERE device_id = 'ESP_KITCHEN_001'
--    ORDER BY last_heartbeat DESC
--    LIMIT 1;
--
-- ============================================




