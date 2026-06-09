-- Example SQL: Sensor Leak Detection History
-- Shows how sensor percentage data appears in leak history

-- 1. Sample data insertion with sensor percentages
INSERT INTO public.water_leak_detections (
    property_id,
    segment_id,
    detection_date,
    leak_type,
    severity,
    status,
    location_description,
    sensor_data,
    confidence_score
) VALUES 
-- Example 1: Both sensors detect leak (>= 25%)
(
    (SELECT id FROM properties LIMIT 1),
    (SELECT id FROM pipeline_segments WHERE segment_name LIKE '%kitchen%' LIMIT 1),
    NOW() - INTERVAL '2 hours',
    'water_sensor',
    'high',
    'active',
    'Under kitchen sink',
    '{
        "water_sensor_1_percent": 45.5,
        "water_sensor_2_percent": 78.2,
        "water_sensor_1_detected": true,
        "water_sensor_2_detected": true,
        "detection_method": "water_sensor",
        "valve_status": "closed",
        "buzzer_status": "on"
    }'::jsonb,
    0.95
),

-- Example 2: Only sensor 1 detects leak
(
    (SELECT id FROM properties LIMIT 1),
    (SELECT id FROM pipeline_segments WHERE segment_name LIKE '%bathroom%' LIMIT 1),
    NOW() - INTERVAL '1 hour',
    'water_sensor',
    'medium',
    'active',
    'Bathroom floor',
    '{
        "water_sensor_1_percent": 67.8,
        "water_sensor_2_percent": 12.3,
        "water_sensor_1_detected": true,
        "water_sensor_2_detected": false,
        "detection_method": "water_sensor",
        "valve_status": "closed",
        "buzzer_status": "on"
    }'::jsonb,
    0.88
),

-- Example 3: Only sensor 2 detects leak  
(
    (SELECT id FROM properties LIMIT 1),
    (SELECT id FROM pipeline_segments WHERE segment_name LIKE '%garden%' LIMIT 1),
    NOW() - INTERVAL '30 minutes',
    'water_sensor',
    'medium',
    'active',
    'Garden irrigation',
    '{
        "water_sensor_1_percent": 18.2,
        "water_sensor_2_percent": 32.7,
        "water_sensor_1_detected": false,
        "water_sensor_2_detected": true,
        "detection_method": "water_sensor",
        "valve_status": "closed", 
        "buzzer_status": "on"
    }'::jsonb,
    0.82
);

-- 2. Query to view leak history with sensor information
SELECT 
    id,
    detection_date,
    leak_type,
    severity,
    status,
    location_description,
    
    -- Extract sensor data with clear formatting
    (sensor_data->>'water_sensor_1_percent')::NUMERIC AS sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC AS sensor2_percent,
    (sensor_data->>'water_sensor_1_detected')::BOOLEAN AS sensor1_detected,
    (sensor_data->>'water_sensor_2_detected')::BOOLEAN AS sensor2_detected,
    
    -- Determine which sensors triggered (25% threshold)
    CASE 
        WHEN (sensor_data->>'water_sensor_1_percent')::NUMERIC >= 25.0 
         AND (sensor_data->>'water_sensor_2_percent')::NUMERIC >= 25.0 
        THEN 'BOTH sensors WET (25-100%)'
        WHEN (sensor_data->>'water_sensor_1_percent')::NUMERIC >= 25.0 
        THEN 'SENSOR 1 WET (25-100%)'
        WHEN (sensor_data->>'water_sensor_2_percent')::NUMERIC >= 25.0 
        THEN 'SENSOR 2 WET (25-100%)'
        ELSE 'No sensor above threshold'
    END AS triggered_by,
    
    -- Additional sensor info
    sensor_data->>'valve_status' AS valve_status,
    sensor_data->>'buzzer_status' AS buzzer_status,
    
    confidence_score,
    created_at
    
FROM public.water_leak_detections
WHERE leak_type = 'water_sensor'
  AND status = 'active'
ORDER BY detection_date DESC;

-- 3. Query for leak notifications (what users see)
SELECT 
    ln.id,
    ln.title,
    ln.message,
    ln.severity,
    ln.created_at,
    
    -- Sensor info from the leak detection
    (wld.sensor_data->>'water_sensor_1_percent')::NUMERIC AS sensor1_percent,
    (wld.sensor_data->>'water_sensor_2_percent')::NUMERIC AS sensor2_percent,
    (wld.sensor_data->>'water_sensor_1_detected')::BOOLEAN AS sensor1_detected,
    (wld.sensor_data->>'water_sensor_2_detected')::BOOLEAN AS sensor2_detected,
    
    -- Formatted sensor status
    CASE 
        WHEN (wld.sensor_data->>'water_sensor_1_percent')::NUMERIC >= 25.0 
         AND (wld.sensor_data->>'water_sensor_2_percent')::NUMERIC >= 25.0 
        THEN 'BOTH sensors detected leak'
        WHEN (wld.sensor_data->>'water_sensor_1_percent')::NUMERIC >= 25.0 
        THEN 'Sensor 1 detected leak'
        WHEN (wld.sensor_data->>'water_sensor_2_percent')::NUMERIC >= 25.0 
        THEN 'Sensor 2 detected leak'
        ELSE 'Unknown trigger'
    END AS sensor_status
    
FROM public.leak_notifications ln
JOIN public.water_leak_detections wld ON ln.leak_detection_id = wld.id
WHERE wld.leak_type = 'water_sensor'
ORDER BY ln.created_at DESC
LIMIT 10;

-- 4. Query for leak history with action details
SELECT 
    lh.id,
    lh.action_taken,
    lh.action_description,
    lh.action_date,
    lh.performed_by,
    lh.notes,
    
    -- Sensor info from the related leak detection
    (wld.sensor_data->>'water_sensor_1_percent')::NUMERIC AS sensor1_percent_at_detection,
    (wld.sensor_data->>'water_sensor_2_percent')::NUMERIC AS sensor2_percent_at_detection,
    wld.location_description,
    wld.detection_date
    
FROM public.leak_history lh
JOIN public.water_leak_detections wld ON lh.leak_detection_id = wld.id
WHERE wld.leak_type = 'water_sensor'
ORDER BY lh.action_date DESC
LIMIT 10;