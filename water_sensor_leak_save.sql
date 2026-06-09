-- ============================================
-- Water Sensor Leak Detection - Save Leaks SQL
-- ============================================
-- This SQL file provides functions to save and manage water sensor leak detections
--
-- DETECTION THRESHOLD: 25%
-- - 1-25% = DRY state (no leak, OK) → Buzzer OFF, Valve can open
-- - 25-100% = WET state (leak detected) → Buzzer ON, Valve CLOSED, LCD shows "LEAK"
--
-- SENSORS WORK INDEPENDENTLY:
-- - Each sensor can trigger leak detection separately
-- - Sensor 1 detects leak (>= 25%) → Saves to database, closes valve, sounds buzzer, LCD shows "LEAK: SENSOR 1"
-- - Sensor 2 detects leak (>= 25%) → Saves to database, closes valve, sounds buzzer, LCD shows "LEAK: SENSOR 2"
-- - Both sensors detect → High severity leak, LCD shows "!!! LEAK !!!"
--
-- DATA STORAGE:
-- - Regular status updates (every 5 seconds) → water_connection_control.sensor_data (JSONB)
-- - Leak detections (when >= 25%) → water_leak_detections table
--
-- Run this in your Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. Function: Save Water Sensor Leak Detection
-- ============================================
-- Saves a new leak detection record when sensors detect water (>= 25%)
CREATE OR REPLACE FUNCTION save_water_sensor_leak(
    p_property_id UUID,
    p_segment_id UUID DEFAULT NULL,
    p_sensor1_percent NUMERIC,
    p_sensor2_percent NUMERIC,
    p_sensor1_detected BOOLEAN,
    p_sensor2_detected BOOLEAN,
    p_sensor1_value INTEGER DEFAULT NULL,
    p_sensor2_value INTEGER DEFAULT NULL,
    p_flow_rate NUMERIC DEFAULT 0,
    p_valve_status TEXT DEFAULT 'closed',
    p_location_description TEXT DEFAULT 'Kitchen - Water Sensor Detection'
)
RETURNS UUID AS $$
DECLARE
    v_leak_id UUID;
    v_severity VARCHAR;
    v_triggered_by TEXT;
BEGIN
    -- Determine severity based on which sensors detected
    IF p_sensor1_detected AND p_sensor2_detected THEN
        v_severity := 'high';
        v_triggered_by := 'Both Sensors (S1 & S2)';
    ELSIF p_sensor1_detected THEN
        v_severity := 'medium';
        v_triggered_by := 'Sensor 1 Only';
    ELSIF p_sensor2_detected THEN
        v_severity := 'medium';
        v_triggered_by := 'Sensor 2 Only';
    ELSE
        -- No leak detected, return NULL
        RETURN NULL;
    END IF;
    
    -- Insert leak detection record
    INSERT INTO water_leak_detections (
        property_id,
        segment_id,
        leak_type,
        severity,
        status,
        location_description,
        estimated_water_loss_rate,
        flow_rate_anomaly,
        confidence_score,
        sensor_data
    ) VALUES (
        p_property_id,
        p_segment_id,
        'water_sensor',
        v_severity,
        'active',
        p_location_description,
        0.0, -- Unknown for sensor detection
        p_flow_rate,
        0.95, -- High confidence for direct sensor detection
        jsonb_build_object(
            'water_sensor_1_value', p_sensor1_value,
            'water_sensor_1_percent', p_sensor1_percent,
            'water_sensor_1_detected', p_sensor1_detected,
            'water_sensor_2_value', p_sensor2_value,
            'water_sensor_2_percent', p_sensor2_percent,
            'water_sensor_2_detected', p_sensor2_detected,
            'flow_rate_lpm', p_flow_rate,
            'valve_status', p_valve_status,
            'detection_method', 'water_sensor',
            'triggered_by', v_triggered_by,
            'threshold_used', 25.0
        )
    )
    RETURNING id INTO v_leak_id;
    
    RETURN v_leak_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 2. Function: Resolve Water Sensor Leak
-- ============================================
-- Marks a leak as resolved when sensors return to dry state (< 25%)
CREATE OR REPLACE FUNCTION resolve_water_sensor_leak(
    p_leak_id UUID,
    p_resolution_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE water_leak_detections
    SET 
        status = 'resolved',
        resolved_date = NOW(),
        resolution_notes = COALESCE(p_resolution_notes, 'Sensors returned to dry state (<25%)'),
        updated_at = NOW()
    WHERE id = p_leak_id
      AND status = 'active'
      AND leak_type = 'water_sensor';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. Function: Auto-Resolve Old Leaks
-- ============================================
-- Automatically resolves leaks that have been active for more than X hours
-- and sensors are no longer detecting water
CREATE OR REPLACE FUNCTION auto_resolve_old_water_leaks(
    p_hours_old INTEGER DEFAULT 24
)
RETURNS INTEGER AS $$
DECLARE
    v_resolved_count INTEGER;
BEGIN
    UPDATE water_leak_detections
    SET 
        status = 'resolved',
        resolved_date = NOW(),
        resolution_notes = format('Auto-resolved: Leak was active for more than %s hours', p_hours_old),
        updated_at = NOW()
    WHERE status = 'active'
      AND leak_type = 'water_sensor'
      AND detection_date < NOW() - (p_hours_old || ' hours')::INTERVAL;
    
    GET DIAGNOSTICS v_resolved_count = ROW_COUNT;
    
    RETURN v_resolved_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. View: Recent Water Sensor Leaks (Last 24 Hours)
-- ============================================
CREATE OR REPLACE VIEW recent_water_sensor_leaks AS
SELECT 
    id,
    property_id,
    segment_id,
    detection_date,
    resolved_date,
    severity,
    status,
    location_description,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
    (sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
    (sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
    (sensor_data->>'triggered_by')::TEXT as triggered_by,
    (sensor_data->>'threshold_used')::NUMERIC as threshold_used,
    confidence_score,
    EXTRACT(EPOCH FROM (COALESCE(resolved_date, NOW()) - detection_date)) / 3600 as hours_active
FROM water_leak_detections
WHERE leak_type = 'water_sensor'
  AND detection_date >= NOW() - INTERVAL '24 hours'
ORDER BY detection_date DESC;

-- ============================================
-- 5. Function: Get Leaks by Sensor
-- ============================================
-- Get leaks detected by a specific sensor (1, 2, or both)
CREATE OR REPLACE FUNCTION get_leaks_by_sensor(
    p_sensor_number INTEGER DEFAULT NULL, -- 1, 2, or NULL for both
    p_property_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT 'active' -- 'active', 'resolved', or NULL for all
)
RETURNS TABLE (
    leak_id UUID,
    property_id UUID,
    detection_date TIMESTAMPTZ,
    resolved_date TIMESTAMPTZ,
    triggered_by TEXT,
    sensor1_percent NUMERIC,
    sensor2_percent NUMERIC,
    sensor1_detected BOOLEAN,
    sensor2_detected BOOLEAN,
    severity VARCHAR,
    status VARCHAR,
    location_description TEXT,
    hours_active NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wld.id,
        wld.property_id,
        wld.detection_date,
        wld.resolved_date,
        (wld.sensor_data->>'triggered_by')::TEXT as triggered_by,
        (wld.sensor_data->>'water_sensor_1_percent')::NUMERIC as sensor1_percent,
        (wld.sensor_data->>'water_sensor_2_percent')::NUMERIC as sensor2_percent,
        (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN as sensor1_detected,
        (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN as sensor2_detected,
        wld.severity::VARCHAR,
        wld.status::VARCHAR,
        wld.location_description,
        EXTRACT(EPOCH FROM (COALESCE(wld.resolved_date, NOW()) - wld.detection_date)) / 3600 as hours_active
    FROM water_leak_detections wld
    WHERE wld.leak_type = 'water_sensor'
      AND (p_property_id IS NULL OR wld.property_id = p_property_id)
      AND (p_status IS NULL OR wld.status = p_status)
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
-- 6. Function: Get Leak Statistics by Sensor
-- ============================================
-- Returns statistics about leaks detected by each sensor independently
CREATE OR REPLACE FUNCTION get_sensor_leak_statistics(
    p_property_id UUID DEFAULT NULL,
    p_days INTEGER DEFAULT 30
)
RETURNS TABLE (
    sensor_number INTEGER,
    total_leaks BIGINT,
    active_leaks BIGINT,
    resolved_leaks BIGINT,
    avg_percent_when_detected NUMERIC,
    max_percent_detected NUMERIC,
    min_percent_detected NUMERIC,
    avg_hours_active NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH sensor1_leaks AS (
        SELECT 
            (sensor_data->>'water_sensor_1_percent')::NUMERIC as percent,
            status,
            EXTRACT(EPOCH FROM (COALESCE(resolved_date, NOW()) - detection_date)) / 3600 as hours_active
        FROM water_leak_detections
        WHERE leak_type = 'water_sensor'
          AND (p_property_id IS NULL OR property_id = p_property_id)
          AND detection_date >= NOW() - (p_days || ' days')::INTERVAL
          AND (sensor_data->>'water_sensor_1_detected')::BOOLEAN = true
    ),
    sensor2_leaks AS (
        SELECT 
            (sensor_data->>'water_sensor_2_percent')::NUMERIC as percent,
            status,
            EXTRACT(EPOCH FROM (COALESCE(resolved_date, NOW()) - detection_date)) / 3600 as hours_active
        FROM water_leak_detections
        WHERE leak_type = 'water_sensor'
          AND (p_property_id IS NULL OR property_id = p_property_id)
          AND detection_date >= NOW() - (p_days || ' days')::INTERVAL
          AND (sensor_data->>'water_sensor_2_detected')::BOOLEAN = true
    )
    SELECT 
        1 as sensor_number,
        COUNT(*) as total_leaks,
        COUNT(*) FILTER (WHERE status = 'active') as active_leaks,
        COUNT(*) FILTER (WHERE status = 'resolved') as resolved_leaks,
        AVG(percent) as avg_percent_when_detected,
        MAX(percent) as max_percent_detected,
        MIN(percent) as min_percent_detected,
        AVG(hours_active) as avg_hours_active
    FROM sensor1_leaks
    UNION ALL
    SELECT 
        2 as sensor_number,
        COUNT(*) as total_leaks,
        COUNT(*) FILTER (WHERE status = 'active') as active_leaks,
        COUNT(*) FILTER (WHERE status = 'resolved') as resolved_leaks,
        AVG(percent) as avg_percent_when_detected,
        MAX(percent) as max_percent_detected,
        MIN(percent) as min_percent_detected,
        AVG(hours_active) as avg_hours_active
    FROM sensor2_leaks;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- USAGE EXAMPLES:
-- ============================================
-- 
-- 1. Save a leak detection (called automatically by ESP32):
--    SELECT save_water_sensor_leak(
--        '9de4e6db-74ac-4b68-a0d1-290ba7fb50ae'::UUID,  -- property_id
--        NULL,                                           -- segment_id (optional)
--        30.5,                                           -- sensor1_percent
--        15.2,                                           -- sensor2_percent
--        true,                                           -- sensor1_detected (>=25%)
--        false,                                          -- sensor2_detected (<25%)
--        1250,                                           -- sensor1_value (ADC)
--        3500,                                           -- sensor2_value (ADC)
--        0.0,                                            -- flow_rate
--        'closed',                                       -- valve_status
--        'Kitchen - Sensor 1 detected leak'             -- location_description
--    );
--
-- 2. Resolve a leak:
--    SELECT resolve_water_sensor_leak(
--        'leak-uuid-here'::UUID,
--        'Sensors returned to dry state'
--    );
--
-- 3. Auto-resolve leaks older than 24 hours:
--    SELECT auto_resolve_old_water_leaks(24);
--
-- 4. View recent leaks:
--    SELECT * FROM recent_water_sensor_leaks;
--
-- 5. Get leaks by sensor:
--    SELECT * FROM get_leaks_by_sensor(1);  -- Sensor 1 only
--    SELECT * FROM get_leaks_by_sensor(2);  -- Sensor 2 only
--    SELECT * FROM get_leaks_by_sensor(3);  -- Both sensors
--
-- 6. Get leak statistics:
--    SELECT * FROM get_sensor_leak_statistics();
--    SELECT * FROM get_sensor_leak_statistics('property-uuid', 7);  -- Last 7 days
--
-- ============================================

