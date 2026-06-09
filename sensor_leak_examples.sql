-- ============================================
-- Sensor Leak Detection Examples - SQL
-- ============================================
-- Examples showing how sensor data appears in the database
-- and how to view it in your Flutter app

-- ============================================
-- 1. INSERT Examples - Creating Sample Leak Data
-- ============================================

-- Example 1: Both sensors detect leak (≥25%)
INSERT INTO public.water_leak_detections (
    property_id, segment_id, detection_date, leak_type, severity, 
    status, location_description, sensor_data, confidence_score
) VALUES (
    (SELECT id FROM properties LIMIT 1), -- Use existing property ID
    (SELECT id FROM pipeline_segments LIMIT 1),   -- Use existing segment ID
    NOW(), 'water_sensor', 'high',
    'active', 'Kitchen Sink', 
    '{
        "detection_method": "water_sensor",
        "water_sensor_1_percent": "45.5",
        "water_sensor_2_percent": "78.2",
        "water_sensor_1_detected": true,
        "water_sensor_2_detected": true
    }'::jsonb,
    0.92
);

-- Example 2: Only Sensor 1 detects leak (≥25%)
INSERT INTO public.water_leak_detections (
    property_id, segment_id, detection_date, leak_type, severity, 
    status, location_description, sensor_data, confidence_score
) VALUES (
    (SELECT id FROM properties LIMIT 1), -- Use existing property ID
    (SELECT id FROM pipeline_segments LIMIT 1),   -- Use existing segment ID
    NOW(), 'water_sensor', 'medium',
    'active', 'Bathroom Floor', 
    '{
        "detection_method": "water_sensor",
        "water_sensor_1_percent": "67.8",
        "water_sensor_2_percent": "12.3",
        "water_sensor_1_detected": true,
        "water_sensor_2_detected": false
    }'::jsonb,
    0.85
);

-- Example 3: Only Sensor 2 detects leak (≥25%)
INSERT INTO public.water_leak_detections (
    property_id, segment_id, detection_date, leak_type, severity, 
    status, location_description, sensor_data, confidence_score
) VALUES (
    (SELECT id FROM properties LIMIT 1), -- Use existing property ID
    (SELECT id FROM pipeline_segments LIMIT 1),   -- Use existing segment ID
    NOW(), 'water_sensor', 'medium',
    'active', 'Laundry Room', 
    '{
        "detection_method": "water_sensor",
        "water_sensor_1_percent": "18.2",
        "water_sensor_2_percent": "32.7",
        "water_sensor_1_detected": false,
        "water_sensor_2_detected": true
    }'::jsonb,
    0.88
);

-- Example 4: No leak (both sensors <25%)
INSERT INTO public.water_leak_detections (
    property_id, segment_id, detection_date, leak_type, severity, 
    status, location_description, sensor_data, confidence_score
) VALUES (
    (SELECT id FROM properties LIMIT 1), -- Use existing property ID
    (SELECT id FROM pipeline_segments LIMIT 1),   -- Use existing segment ID
    NOW(), 'water_sensor', 'low',
    'resolved', 'Under Sink', 
    '{
        "detection_method": "water_sensor",
        "water_sensor_1_percent": "15.2",
        "water_sensor_2_percent": "8.7",
        "water_sensor_1_detected": false,
        "water_sensor_2_detected": false
    }'::jsonb,
    0.75
);

-- ============================================
-- 2. SELECT Examples - Viewing Sensor Data
-- ============================================

-- View all water sensor leaks with percentages
SELECT 
    id,
    property_id,
    detection_date,
    leak_type,
    severity,
    status,
    location_description,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC AS sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC AS sensor2_percent,
    (sensor_data->>'water_sensor_1_detected')::BOOLEAN AS sensor1_detected,
    (sensor_data->>'water_sensor_2_detected')::BOOLEAN AS sensor2_detected,
    confidence_score
FROM public.water_leak_detections 
WHERE leak_type = 'water_sensor'
ORDER BY detection_date DESC
LIMIT 10;

-- View only active leaks with 25% threshold logic
SELECT 
    id,
    detection_date,
    location_description,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC AS sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC AS sensor2_percent,
    -- 25% threshold detection logic
    CASE 
        WHEN (sensor_data->>'water_sensor_1_percent')::NUMERIC >= 25.0 
         AND (sensor_data->>'water_sensor_2_percent')::NUMERIC >= 25.0 
        THEN 'BOTH sensors WET (25-100%)'
        WHEN (sensor_data->>'water_sensor_1_percent')::NUMERIC >= 25.0 
        THEN 'SENSOR 1 WET (25-100%)'
        WHEN (sensor_data->>'water_sensor_2_percent')::NUMERIC >= 25.0 
        THEN 'SENSOR 2 WET (25-100%)'
        ELSE 'No leak detected'
    END AS triggered_by,
    severity,
    confidence_score
FROM public.water_leak_detections 
WHERE leak_type = 'water_sensor'
  AND status = 'active'
ORDER BY detection_date DESC
LIMIT 10;

-- ============================================
-- 3. UPDATE Examples - Resolving Leaks
-- ============================================

-- Resolve a leak (mark as resolved)
UPDATE public.water_leak_detections 
SET status = 'resolved', 
    updated_at = NOW()
WHERE id = (SELECT id FROM water_leak_detections WHERE leak_type = 'water_sensor' LIMIT 1);

-- Update sensor data for testing
UPDATE public.water_leak_detections 
SET sensor_data = '{
    "detection_method": "water_sensor",
    "water_sensor_1_percent": "38.9",
    "water_sensor_2_percent": "22.1",
    "water_sensor_1_detected": true,
    "water_sensor_2_detected": false
}'::jsonb,
updated_at = NOW()
WHERE id = (SELECT id FROM water_leak_detections WHERE leak_type = 'water_sensor' LIMIT 1);

-- ============================================
-- 4. Test Data for Flutter App
-- ============================================

-- Insert test data that will appear in your Flutter app
INSERT INTO public.water_leak_detections (
    property_id, segment_id, detection_date, leak_type, severity, 
    status, location_description, sensor_data, confidence_score
) VALUES 
-- Multiple leaks for testing
(
    (SELECT id FROM properties LIMIT 1), -- Use existing property ID
    (SELECT id FROM pipeline_segments LIMIT 1),   -- Use existing segment ID
    NOW() - INTERVAL '2 hours', 'water_sensor', 'high',
    'active', 'Test Kitchen', 
    '{"detection_method": "water_sensor", "water_sensor_1_percent": "55.5", "water_sensor_2_percent": "82.3", "water_sensor_1_detected": true, "water_sensor_2_detected": true}'::jsonb,
    0.95
),
(
    (SELECT id FROM properties LIMIT 1), -- Use existing property ID
    (SELECT id FROM pipeline_segments LIMIT 1),   -- Use existing segment ID
    NOW() - INTERVAL '1 hour', 'water_sensor', 'medium',
    'active', 'Test Bathroom', 
    '{"detection_method": "water_sensor", "water_sensor_1_percent": "71.2", "water_sensor_2_percent": "14.8", "water_sensor_1_detected": true, "water_sensor_2_detected": false}'::jsonb,
    0.87
),
(
    (SELECT id FROM properties LIMIT 1), -- Use existing property ID
    (SELECT id FROM pipeline_segments LIMIT 1),   -- Use existing segment ID
    NOW() - INTERVAL '30 minutes', 'water_sensor', 'medium',
    'active', 'Test Laundry', 
    '{"detection_method": "water_sensor", "water_sensor_1_percent": "19.5", "water_sensor_2_percent": "41.7", "water_sensor_1_detected": false, "water_sensor_2_detected": true}'::jsonb,
    0.89
);

-- View the test data
SELECT 
    id,
    detection_date,
    location_description,
    (sensor_data->>'water_sensor_1_percent')::NUMERIC AS sensor1_percent,
    (sensor_data->>'water_sensor_2_percent')::NUMERIC AS sensor2_percent,
    CASE 
        WHEN (sensor_data->>'water_sensor_1_percent')::NUMERIC >= 25.0 
         AND (sensor_data->>'water_sensor_2_percent')::NUMERIC >= 25.0 
        THEN 'BOTH sensors WET (25-100%)'
        WHEN (sensor_data->>'water_sensor_1_percent')::NUMERIC >= 25.0 
        THEN 'SENSOR 1 WET (25-100%)'
        WHEN (sensor_data->>'water_sensor_2_percent')::NUMERIC >= 25.0 
        THEN 'SENSOR 2 WET (25-100%)'
        ELSE 'No leak detected'
    END AS triggered_by,
    severity,
    status
FROM public.water_leak_detections 
WHERE location_description LIKE 'Test%'
ORDER BY detection_date DESC;