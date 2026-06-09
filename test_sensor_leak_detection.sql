-- Test Sensor-Specific Leak Detection
-- This demonstrates how the system handles sensor data with leaks

-- Sample data with multiple sensors showing leaks
INSERT INTO public.water_connection_control (
    device_id,
    device_name,
    valve_status,
    water_flow,
    pressure,
    temperature,
    is_online,
    location,
    user_id,
    property_id,
    sensor_data
) VALUES (
    'esp32-kitchen-001',
    'Kitchen Water Controller',
    'open',
    2.5, -- water flow
    45.2, -- pressure
    25.1, -- temperature
    true,
    'Under kitchen sink',
    (SELECT id FROM users LIMIT 1), -- sample user
    (SELECT id FROM properties LIMIT 1), -- sample property
    '{
        "sensor1": true,
        "sensor2": false,
        "sensor3": true,
        "sensor4": false,
        "sensor5": true
    }'::jsonb
);

-- Check what was inserted into notifications
SELECT 
    ln.title,
    ln.message,
    ln.severity,
    ln.created_at
FROM leak_notifications ln
ORDER BY ln.created_at DESC
LIMIT 5;

-- Check leak history entries
SELECT 
    lh.action_description,
    lh.notes,
    lh.action_date
FROM leak_history lh
ORDER BY lh.action_date DESC
LIMIT 5;

-- Check the water leak detections
SELECT 
    wld.leak_type,
    wld.severity,
    wld.status,
    wld.sensor_data
FROM water_leak_detections wld
ORDER BY wld.detection_date DESC
LIMIT 5;