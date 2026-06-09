-- ============================================
-- Water Sensor Leak Detection Alerts - SQL
-- ============================================
-- This SQL creates alerts and notifications when water sensors detect leaks
-- 
-- DETECTION THRESHOLD: 25%
-- - 1-25% = DRY state (no leak, OK) → Buzzer OFF, Valve can open
-- - 25-100% = WET state (leak detected) → Buzzer ON, Valve CLOSED, LCD shows "LEAK"
--
-- SENSORS WORK INDEPENDENTLY:
-- - Each sensor can trigger leak detection separately
-- - Sensor 1 detects leak (>= 25%) → Saves to database, closes valve, sounds buzzer
-- - Sensor 2 detects leak (>= 25%) → Saves to database, closes valve, sounds buzzer
-- - Both sensors detect → High severity leak
--
-- LCD DISPLAY:
-- - Shows "LEAK: SENSOR 1" when Sensor 1 detects
-- - Shows "LEAK: SENSOR 2" when Sensor 2 detects
-- - Shows "!!! LEAK !!!" when both sensors detect
-- - Shows sensor percentages on line 2
--
-- BUZZER:
-- - Turns ON immediately when any sensor detects leak (>= 25%)
-- - Beeps every 500ms while leak is active
-- - Turns OFF when sensors return to dry (< 25%)

-- ============================================
-- 1. View: Active Water Sensor Leaks
-- ============================================
-- Shows all active leaks detected by water sensors with sensor identification
CREATE OR REPLACE VIEW active_water_sensor_leaks AS
SELECT 
    id,
    property_id,
    segment_id,
    detection_date,
    leak_type,
    severity,
    status,
    location_description,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
    (sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
    (sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
    sensor_data->>'detection_method' as detection_method,
    confidence_score,
    -- Determine which sensor(s) triggered the leak
    CASE 
        WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
         AND (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Both Sensors'
        WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'Sensor 1'
        WHEN (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Sensor 2'
        ELSE 'Unknown'
    END as triggered_by,
    created_at
FROM water_leak_detections
WHERE status = 'active'
  AND leak_type = 'water_sensor'
  AND (sensor_data->>'detection_method')::text = 'water_sensor'
ORDER BY detection_date DESC;

-- ============================================
-- 2. Function: Get Water Sensor Alerts
-- ============================================
-- Returns all active water sensor alerts for a property or all properties
-- Shows which sensor(s) triggered the detection
CREATE OR REPLACE FUNCTION get_water_sensor_alerts(
    p_property_id UUID DEFAULT NULL
)
RETURNS TABLE (
    leak_id UUID,
    property_id UUID,
    detection_date TIMESTAMPTZ,
    severity VARCHAR,
    location_description TEXT,
    sensor1_percent NUMERIC,
    sensor2_percent NUMERIC,
    sensor1_detected BOOLEAN,
    sensor2_detected BOOLEAN,
    triggered_by TEXT,
    confidence_score NUMERIC,
    minutes_since_detection BIGINT,
    alert_message TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wld.id,
        wld.property_id,
        wld.detection_date,
        wld.severity::VARCHAR,
        wld.location_description,
        (wld.sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
        (wld.sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
        (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
        (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
        CASE 
            WHEN (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
             AND (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Both Sensors (S1 & S2)'
            WHEN (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'Sensor 1'
            WHEN (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Sensor 2'
            ELSE 'Unknown'
        END as triggered_by,
        wld.confidence_score,
        EXTRACT(EPOCH FROM (NOW() - wld.detection_date)) / 60 as minutes_since_detection,
        format(
            '🚨 WATER LEAK at %s - Triggered by: %s | S1: %.1f%% | S2: %.1f%% | Severity: %s',
            COALESCE(wld.location_description, 'Unknown'),
            CASE 
                WHEN (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
                 AND (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Both Sensors'
                WHEN (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'Sensor 1'
                WHEN (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Sensor 2'
                ELSE 'Unknown'
            END,
            COALESCE((wld.sensor_data->>'water_sensor_1_percent')::NUMERIC, 0),
            COALESCE((wld.sensor_data->>'water_sensor_2_percent')::NUMERIC, 0),
            wld.severity
        ) as alert_message
    FROM water_leak_detections wld
    WHERE wld.status = 'active'
      AND wld.leak_type = 'water_sensor'
      AND (wld.sensor_data->>'detection_method')::text = 'water_sensor'
      AND (p_property_id IS NULL OR wld.property_id = p_property_id)
    ORDER BY wld.detection_date DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. Function: Alert on New Water Sensor Detection
-- ============================================
-- Trigger function that logs alerts when water sensors detect leaks
CREATE OR REPLACE FUNCTION log_water_sensor_alert()
RETURNS TRIGGER AS $$
DECLARE
    v_sensor1_percent NUMERIC;
    v_sensor2_percent NUMERIC;
    v_alert_message TEXT;
    v_triggered_by TEXT;
BEGIN
    -- Only process water sensor detections
    IF NEW.leak_type = 'water_sensor' 
       AND (NEW.sensor_data->>'detection_method')::text = 'water_sensor' 
       AND NEW.status = 'active' THEN
        
        -- Extract sensor percentages
        v_sensor1_percent := (NEW.sensor_data->>'water_sensor_1_percent')::NUMERIC;
        v_sensor2_percent := (NEW.sensor_data->>'water_sensor_2_percent')::NUMERIC;
        
    -- Determine which sensor(s) triggered with percentage-based logic
    -- Threshold is 25% (>= 25% = WET/LEAK, < 25% = DRY/OK)
    IF COALESCE(v_sensor1_percent, 0) >= 25.0 AND COALESCE(v_sensor2_percent, 0) >= 25.0 THEN
        v_triggered_by := 'BOTH sensors WET (25-100%), leak detected';
    ELSIF COALESCE(v_sensor1_percent, 0) >= 25.0 THEN
        v_triggered_by := 'SENSOR 1 WET (25-100%), leak detected';
    ELSIF COALESCE(v_sensor2_percent, 0) >= 25.0 THEN
        v_triggered_by := 'SENSOR 2 WET (25-100%), leak detected';
    ELSE
        v_triggered_by := 'Unknown trigger';
    END IF;
        
        -- Build alert message with sensor identification
        v_alert_message := format(
            '🚨 WATER LEAK DETECTED at %s! ' ||
            'Triggered by: %s | ' ||
            'Sensor 1: %s%% | Sensor 2: %s%% | ' ||
            'Severity: %s | Confidence: %s%%',
            COALESCE(NEW.location_description, 'Unknown Location'),
            v_triggered_by,
            COALESCE(ROUND(v_sensor1_percent::numeric, 1)::text, '0.0'),
            COALESCE(ROUND(v_sensor2_percent::numeric, 1)::text, '0.0'),
            NEW.severity,
            COALESCE(ROUND((NEW.confidence_score * 100)::numeric, 0)::text, '0')
        );
        
        -- Log to console (in production, you might want to send email/SMS)
        RAISE NOTICE '%', v_alert_message;
        
        -- You can also insert into a notifications table here if you have one
        -- INSERT INTO notifications (property_id, type, message, severity, created_at)
        -- VALUES (NEW.property_id, 'water_sensor_leak', v_alert_message, NEW.severity, NOW());
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. Trigger: Auto-alert on Water Sensor Detection
-- ============================================
-- Automatically triggers alert when water sensor leak is detected
DROP TRIGGER IF EXISTS trigger_water_sensor_alert ON water_leak_detections;
CREATE TRIGGER trigger_water_sensor_alert
    AFTER INSERT ON water_leak_detections
    FOR EACH ROW
    WHEN (NEW.leak_type = 'water_sensor' AND NEW.status = 'active')
    EXECUTE FUNCTION log_water_sensor_alert();

-- ============================================
-- 5. Query: Recent Water Sensor Detections (Last 24 Hours)
-- ============================================
-- Get all water sensor detections from the last 24 hours
/*
SELECT 
    id,
    property_id,
    detection_date,
    severity,
    location_description,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
    (sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
    (sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
    confidence_score,
    status,
    EXTRACT(EPOCH FROM (NOW() - detection_date)) / 3600 as hours_ago
FROM water_leak_detections
WHERE leak_type = 'water_sensor'
  AND detection_date >= NOW() - INTERVAL '24 hours'
ORDER BY detection_date DESC;
*/

-- ============================================
-- 6. Query: Water Sensor Detection Statistics
-- ============================================
-- Statistics about water sensor detections
/*
SELECT 
    COUNT(*) as total_detections,
    COUNT(*) FILTER (WHERE status = 'active') as active_detections,
    COUNT(*) FILTER (WHERE status = 'resolved') as resolved_detections,
    COUNT(*) FILTER (WHERE severity = 'high') as high_severity,
    COUNT(*) FILTER (WHERE severity = 'medium') as medium_severity,
    AVG((sensor_data->>'water_sensor_1_percent')::NUMERIC) as avg_sensor1_percent,
    AVG((sensor_data->>'water_sensor_2_percent')::NUMERIC) as avg_sensor2_percent,
    AVG(confidence_score) as avg_confidence
FROM water_leak_detections
WHERE leak_type = 'water_sensor'
  AND detection_date >= NOW() - INTERVAL '30 days';
*/

-- ============================================
-- 7. Query: Properties with Active Water Sensor Leaks
-- ============================================
-- List all properties that currently have active water sensor leaks
/*
SELECT DISTINCT
    p.id as property_id,
    p.name as property_name,
    p.address,
    COUNT(wld.id) as active_leak_count,
    MAX(wld.detection_date) as latest_detection
FROM properties p
INNER JOIN water_leak_detections wld ON p.id = wld.property_id
WHERE wld.leak_type = 'water_sensor'
  AND wld.status = 'active'
GROUP BY p.id, p.name, p.address
ORDER BY latest_detection DESC;
*/

-- ============================================
-- 8. Function: Get Water Sensor Status Summary
-- ============================================
-- Returns summary of water sensor status for a device/property
CREATE OR REPLACE FUNCTION get_water_sensor_status(
    p_property_id UUID DEFAULT NULL
)
RETURNS TABLE (
    property_id UUID,
    active_leaks_count BIGINT,
    latest_detection_date TIMESTAMPTZ,
    sensor1_avg_percent NUMERIC,
    sensor2_avg_percent NUMERIC,
    sensor1_detections_count BIGINT,
    sensor2_detections_count BIGINT,
    both_sensors_detections_count BIGINT,
    high_severity_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wld.property_id,
        COUNT(*) FILTER (WHERE wld.status = 'active') as active_leaks_count,
        MAX(wld.detection_date) as latest_detection_date,
        AVG((wld.sensor_data->>'water_sensor_1_percent')::NUMERIC) as sensor1_avg_percent,
        AVG((wld.sensor_data->>'water_sensor_2_percent')::NUMERIC) as sensor2_avg_percent,
        COUNT(*) FILTER (WHERE (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
                            AND (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = false) as sensor1_detections_count,
        COUNT(*) FILTER (WHERE (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true 
                            AND (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = false) as sensor2_detections_count,
        COUNT(*) FILTER (WHERE (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
                            AND (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true) as both_sensors_detections_count,
        COUNT(*) FILTER (WHERE wld.severity = 'high' AND wld.status = 'active') as high_severity_count
    FROM water_leak_detections wld
    WHERE wld.leak_type = 'water_sensor'
      AND (p_property_id IS NULL OR wld.property_id = p_property_id)
      AND wld.detection_date >= NOW() - INTERVAL '7 days'
    GROUP BY wld.property_id
    ORDER BY latest_detection_date DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9. View: All Leak Types (Water Sensor + Flow-based)
-- ============================================
-- Combined view showing both water sensor and flow-based leaks
CREATE OR REPLACE VIEW all_active_leaks AS
SELECT 
    id,
    property_id,
    segment_id,
    detection_date,
    leak_type,
    severity,
    status,
    location_description,
    CASE 
        WHEN leak_type = 'water_sensor' THEN
            CASE 
                WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
                 AND (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Both Sensors (S1 & S2)'
                WHEN (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'Sensor 1'
                WHEN (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Sensor 2'
                ELSE 'Unknown'
            END
        WHEN leak_type = 'drip' THEN 'Flow-based Detection'
        ELSE 'Other'
    END as detection_source,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
    (sensor_data->>'flow_rate_lpm')::NUMERIC as flow_rate_lpm,
    confidence_score,
    created_at
FROM water_leak_detections
WHERE status = 'active'
ORDER BY detection_date DESC;

-- ============================================
-- 10. Function: Get Leaks by Sensor
-- ============================================
-- Get leaks detected by a specific sensor (1, 2, or both)
CREATE OR REPLACE FUNCTION get_leaks_by_sensor(
    p_sensor_number INTEGER DEFAULT NULL, -- 1, 2, or NULL for both
    p_property_id UUID DEFAULT NULL
)
RETURNS TABLE (
    leak_id UUID,
    property_id UUID,
    detection_date TIMESTAMPTZ,
    triggered_by TEXT,
    sensor1_percent NUMERIC,
    sensor2_percent NUMERIC,
    severity VARCHAR,
    location_description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wld.id,
        wld.property_id,
        wld.detection_date,
        CASE 
            WHEN (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
             AND (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Both Sensors'
            WHEN (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true THEN 'Sensor 1'
            WHEN (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true THEN 'Sensor 2'
            ELSE 'Unknown'
        END as triggered_by,
        (wld.sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
        (wld.sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
        wld.severity::VARCHAR,
        wld.location_description
    FROM water_leak_detections wld
    WHERE wld.status = 'active'
      AND wld.leak_type = 'water_sensor'
      AND (wld.sensor_data->>'detection_method')::text = 'water_sensor'
      AND (p_property_id IS NULL OR wld.property_id = p_property_id)
      AND (
          p_sensor_number IS NULL OR
          (p_sensor_number = 1 AND (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true) OR
          (p_sensor_number = 2 AND (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true) OR
          (p_sensor_number = 3 AND (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN = true 
                                 AND (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN = true)
      )
    ORDER BY wld.detection_date DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- USAGE EXAMPLES:
-- ============================================
-- 
-- 1. Get all active water sensor alerts:
--    SELECT * FROM get_water_sensor_alerts();
--
-- 2. Get alerts for a specific property:
--    SELECT * FROM get_water_sensor_alerts('9de4e6db-74ac-4b68-a0d1-290ba7fb50ae');
--
-- 3. View active water sensor leaks (shows which sensor triggered):
--    SELECT * FROM active_water_sensor_leaks;
--
-- 4. View all active leaks (water sensor + flow-based):
--    SELECT * FROM all_active_leaks;
--
-- 5. Get water sensor status summary:
--    SELECT * FROM get_water_sensor_status();
--
-- 6. Get status for specific property:
--    SELECT * FROM get_water_sensor_status('9de4e6db-74ac-4b68-a0d1-290ba7fb50ae');
--
-- 7. Get leaks detected by Sensor 1 only:
--    SELECT * FROM get_leaks_by_sensor(1);
--
-- 8. Get leaks detected by Sensor 2 only:
--    SELECT * FROM get_leaks_by_sensor(2);
--
-- 9. Get leaks detected by both sensors:
--    SELECT * FROM get_leaks_by_sensor(3);
--
-- 10. Get all sensor leaks for a property:
--     SELECT * FROM get_leaks_by_sensor(NULL, '9de4e6db-74ac-4b68-a0d1-290ba7fb50ae');
--
-- ============================================

