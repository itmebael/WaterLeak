-- Example Data for Water Leak Detection System
-- This file contains sample INSERT statements for testing and development
-- Run this in Supabase SQL Editor after setting up the database schema

BEGIN;

-- ============================================
-- 1. USERS / PROPERTIES / PIPELINE SEGMENTS (OPTIONAL)
-- ============================================
-- Your Supabase schema can vary (example: some projects have `full_name` only and no `first_name`/`last_name`).
-- To avoid errors, this sample script DOES NOT insert into `users`, `properties`, or `pipeline_segments` by default.
-- If you want to insert users too, use ONE of the following (uncomment the one that matches your table):
--
-- (A) If your `public.users` has full_name:
-- INSERT INTO public.users (id, email, full_name, phone, role, created_at)
-- VALUES
--   ('550e8400-e29b-41d4-a716-446655440000', 'admin@waterleak.com', 'Admin User', '+63 912 345 6789', 'admin', NOW() - INTERVAL '30 days')
-- ON CONFLICT (id) DO NOTHING;
--
-- (B) If your `public.users` has first_name + last_name:
-- INSERT INTO public.users (id, email, first_name, last_name, phone, role, created_at)
-- VALUES
--   ('550e8400-e29b-41d4-a716-446655440000', 'admin@waterleak.com', 'Admin', 'User', '+63 912 345 6789', 'admin', NOW() - INTERVAL '30 days')
-- ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 4. WATER CONNECTION CONTROL (Example Devices)
-- ============================================

INSERT INTO water_connection_control (
  id, device_id, device_name, valve_status, water_flow, pressure, temperature,
  is_online, last_heartbeat, location, user_id, property_id, total_water_used, created_at, updated_at
)
VALUES
  (
    '880e8400-e29b-41d4-a716-446655440000',
    'ESP_KITCHEN_001',
    'Kitchen Water Controller',
    'closed',
    0.00,
    45.50,
    25.30,
    true,
    NOW() - INTERVAL '30 seconds',
    'Kitchen',
    NULL,
    NULL,
    1250.75,
    NOW() - INTERVAL '20 days',
    NOW() - INTERVAL '30 seconds'
  ),
  (
    '880e8400-e29b-41d4-a716-446655440001',
    'ESP_BATHROOM_001',
    'Bathroom Water Controller',
    'open',
    12.50,
    42.00,
    24.80,
    true,
    NOW() - INTERVAL '1 minute',
    'Bathroom',
    NULL,
    NULL,
    890.25,
    NOW() - INTERVAL '20 days',
    NOW() - INTERVAL '1 minute'
  ),
  (
    '880e8400-e29b-41d4-a716-446655440002',
    'ESP_GARDEN_001',
    'Garden Water Controller',
    'closed',
    0.00,
    40.00,
    28.50,
    false,
    NOW() - INTERVAL '5 minutes',
    'Garden',
    NULL,
    NULL,
    450.00,
    NOW() - INTERVAL '20 days',
    NOW() - INTERVAL '5 minutes'
  ),
  (
    '880e8400-e29b-41d4-a716-446655440003',
    'ESP_KITCHEN_002',
    'Kitchen Water Controller',
    'closed',
    0.00,
    44.20,
    26.10,
    true,
    NOW() - INTERVAL '45 seconds',
    'Kitchen',
    NULL,
    NULL,
    2100.50,
    NOW() - INTERVAL '15 days',
    NOW() - INTERVAL '45 seconds'
  ),
  (
    '880e8400-e29b-41d4-a716-446655440004',
    'ESP_KITCHEN_003',
    'Kitchen Water Controller',
    'open',
    8.30,
    46.00,
    27.20,
    true,
    NOW() - INTERVAL '20 seconds',
    'Kitchen',
    NULL,
    NULL,
    3200.25,
    NOW() - INTERVAL '10 days',
    NOW() - INTERVAL '20 seconds'
  )
ON CONFLICT (device_id) DO UPDATE SET
  device_name = EXCLUDED.device_name,
  valve_status = EXCLUDED.valve_status,
  water_flow = EXCLUDED.water_flow,
  pressure = EXCLUDED.pressure,
  temperature = EXCLUDED.temperature,
  is_online = EXCLUDED.is_online,
  last_heartbeat = EXCLUDED.last_heartbeat,
  location = EXCLUDED.location,
  user_id = EXCLUDED.user_id,
  property_id = EXCLUDED.property_id,
  total_water_used = EXCLUDED.total_water_used,
  updated_at = EXCLUDED.updated_at;

-- ============================================
-- 5. EMERGENCY CONTACTS (Example Contacts)
-- ============================================

INSERT INTO emergency_contacts (id, name, phone, email, contact_type, address, is_primary, user_id, created_at)
VALUES
  (
    '990e8400-e29b-41d4-a716-446655440000',
    'Catbalogan Plumbing Services',
    '+63 912 555 1001',
    'plumbing@catbalogan.com',
    'plumber',
    'Catbalogan City, Samar',
    true,
    NULL,
    NOW() - INTERVAL '25 days'
  ),
  (
    '990e8400-e29b-41d4-a716-446655440001',
    'Emergency Water Repair',
    '+63 912 555 1002',
    'emergency@waterrepair.com',
    'emergency',
    'Catbalogan City, Samar',
    true,
    NULL,
    NOW() - INTERVAL '25 days'
  ),
  (
    '990e8400-e29b-41d4-a716-446655440002',
    'Juan Plumber',
    '+63 912 555 1003',
    'juan.plumber@example.com',
    'plumber',
    'Catbalogan City, Samar',
    false,
    NULL,
    NOW() - INTERVAL '20 days'
  ),
  (
    '990e8400-e29b-41d4-a716-446655440003',
    '24/7 Water Emergency',
    '+63 912 555 1004',
    'emergency24@water.com',
    'emergency',
    'Catbalogan City, Samar',
    false,
    NULL,
    NOW() - INTERVAL '18 days'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 6. WATER CONNECTION COMMANDS (Example Commands)
-- ============================================

INSERT INTO water_connection_commands (id, device_id, command_type, command_data, status, executed_at, created_at, created_by)
VALUES
  (
    'aa0e8400-e29b-41d4-a716-446655440000',
    'ESP_KITCHEN_001',
    'toggle_valve',
    '{"action": "open"}'::jsonb,
    'executed',
    NOW() - INTERVAL '2 hours',
    NOW() - INTERVAL '2 hours',
    NULL
  ),
  (
    'aa0e8400-e29b-41d4-a716-446655440001',
    'ESP_KITCHEN_001',
    'toggle_valve',
    '{"action": "close"}'::jsonb,
    'executed',
    NOW() - INTERVAL '1 hour',
    NOW() - INTERVAL '1 hour',
    NULL
  ),
  (
    'aa0e8400-e29b-41d4-a716-446655440002',
    'ESP_BATHROOM_001',
    'toggle_valve',
    '{"action": "open"}'::jsonb,
    'executed',
    NOW() - INTERVAL '30 minutes',
    NOW() - INTERVAL '30 minutes',
    NULL
  ),
  (
    'aa0e8400-e29b-41d4-a716-446655440003',
    'ESP_KITCHEN_002',
    'toggle_valve',
    '{"action": "close"}'::jsonb,
    'pending',
    NULL,
    NOW() - INTERVAL '5 minutes',
    NULL
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 7. SENSOR READINGS (Example Sensor Data)
-- ============================================

INSERT INTO sensor_readings (
  id, segment_id, reading_timestamp, pressure_psi, flow_rate_lpm, temperature_celsius,
  humidity_percent, vibration_level, sensor_status, battery_level, signal_strength, raw_data, created_at
)
VALUES
  (
    'bb0e8400-e29b-41d4-a716-446655440000',
    NULL,
    NOW() - INTERVAL '10 minutes',
    45.50,
    0.00,
    25.30,
    65.00,
    0.10,
    'normal',
    0.95,
    85,
    '{"pulses": 0, "flow_detected": false}'::jsonb,
    NOW() - INTERVAL '10 minutes'
  ),
  (
    'bb0e8400-e29b-41d4-a716-446655440001',
    NULL,
    NOW() - INTERVAL '5 minutes',
    42.00,
    12.50,
    24.80,
    68.00,
    0.25,
    'normal',
    0.92,
    80,
    '{"pulses": 125, "flow_detected": true}'::jsonb,
    NOW() - INTERVAL '5 minutes'
  ),
  (
    'bb0e8400-e29b-41d4-a716-446655440002',
    NULL,
    NOW() - INTERVAL '1 minute',
    44.20,
    0.00,
    26.10,
    70.00,
    0.05,
    'normal',
    0.90,
    88,
    '{"pulses": 0, "flow_detected": false}'::jsonb,
    NOW() - INTERVAL '1 minute'
  ),
  (
    'bb0e8400-e29b-41d4-a716-446655440003',
    NULL,
    NOW() - INTERVAL '30 seconds',
    46.00,
    8.30,
    27.20,
    72.00,
    0.15,
    'normal',
    0.88,
    82,
    '{"pulses": 83, "flow_detected": true}'::jsonb,
    NOW() - INTERVAL '30 seconds'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 8. WATER LEAK DETECTIONS (Example Leak Events)
-- ============================================

INSERT INTO water_leak_detections (
  id, property_id, segment_id, detection_date, leak_type, severity, status,
  location_description, estimated_water_loss_liters, estimated_water_loss_rate,
  pressure_drop, flow_rate_anomaly, sensor_data, confidence_score, is_false_positive,
  resolved_date, resolution_notes, created_at, updated_at
)
VALUES
  (
    'cc0e8400-e29b-41d4-a716-446655440000',
    NULL,
    NULL,
    NOW() - INTERVAL '3 days',
    'flow_based',
    'high',
    'resolved',
    'Kitchen sink area',
    150.50,
    0.8,
    2.50,
    0.75,
    '{"flow_rate": 0.8, "valve_status": "closed", "duration_minutes": 120}'::jsonb,
    0.95,
    false,
    NOW() - INTERVAL '2 days',
    'Leak fixed by replacing faulty faucet washer',
    NOW() - INTERVAL '3 days',
    NOW() - INTERVAL '2 days'
  ),
  (
    'cc0e8400-e29b-41d4-a716-446655440001',
    NULL,
    NULL,
    NOW() - INTERVAL '1 day',
    'flow_based',
    'medium',
    'active',
    'Kitchen pipe connection',
    45.25,
    0.5,
    1.20,
    0.45,
    '{"flow_rate": 0.5, "valve_status": "closed", "duration_minutes": 60}'::jsonb,
    0.85,
    false,
    NULL,
    NULL,
    NOW() - INTERVAL '1 day',
    NOW() - INTERVAL '1 day'
  ),
  (
    'cc0e8400-e29b-41d4-a716-446655440002',
    NULL,
    NULL,
    NOW() - INTERVAL '5 hours',
    'flow_based',
    'low',
    'active',
    'Kitchen area - minor drip',
    8.50,
    0.2,
    0.50,
    0.15,
    '{"flow_rate": 0.2, "valve_status": "closed", "duration_minutes": 30}'::jsonb,
    0.70,
    false,
    NULL,
    NULL,
    NOW() - INTERVAL '5 hours',
    NOW() - INTERVAL '5 hours'
  ),
  (
    'cc0e8400-e29b-41d4-a716-446655440003',
    NULL,
    NULL,
    NOW() - INTERVAL '7 days',
    'flow_based',
    'high',
    'resolved',
    'Bathroom pipe burst',
    500.00,
    2.5,
    5.00,
    2.00,
    '{"flow_rate": 2.5, "valve_status": "closed", "duration_minutes": 200}'::jsonb,
    0.98,
    false,
    NOW() - INTERVAL '6 days',
    'Emergency repair completed. Pipe replaced and tested.',
    NOW() - INTERVAL '7 days',
    NOW() - INTERVAL '6 days'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 9. WATER CONNECTION CONTROL HISTORY (Example Time-Series Data)
-- ============================================

INSERT INTO water_connection_control_history (
  device_id, device_name, valve_status, water_flow, pressure, temperature,
  is_online, last_heartbeat, location, user_id, property_id, total_water_used, recorded_at, source
)
VALUES
  -- Kitchen device history (last 24 hours)
  ('ESP_KITCHEN_001', 'Kitchen Water Controller', 'open', 15.50, 45.00, 25.00, true, NOW() - INTERVAL '24 hours', 'Kitchen', NULL, NULL, 1200.00, NOW() - INTERVAL '24 hours', 'manual'),
  ('ESP_KITCHEN_001', 'Kitchen Water Controller', 'open', 12.30, 45.20, 25.10, true, NOW() - INTERVAL '23 hours', 'Kitchen', NULL, NULL, 1215.50, NOW() - INTERVAL '23 hours', 'trigger'),
  ('ESP_KITCHEN_001', 'Kitchen Water Controller', 'closed', 0.00, 45.50, 25.30, true, NOW() - INTERVAL '22 hours', 'Kitchen', NULL, NULL, 1230.25, NOW() - INTERVAL '22 hours', 'trigger'),
  ('ESP_KITCHEN_001', 'Kitchen Water Controller', 'closed', 0.00, 45.30, 25.20, true, NOW() - INTERVAL '21 hours', 'Kitchen', NULL, NULL, 1230.25, NOW() - INTERVAL '21 hours', 'trigger'),
  ('ESP_KITCHEN_001', 'Kitchen Water Controller', 'open', 8.75, 44.80, 25.50, true, NOW() - INTERVAL '20 hours', 'Kitchen', NULL, NULL, 1245.00, NOW() - INTERVAL '20 hours', 'trigger'),
  ('ESP_KITCHEN_001', 'Kitchen Water Controller', 'closed', 0.00, 45.50, 25.30, true, NOW() - INTERVAL '1 hour', 'Kitchen', NULL, NULL, 1248.50, NOW() - INTERVAL '1 hour', 'trigger'),
  ('ESP_KITCHEN_001', 'Kitchen Water Controller', 'closed', 0.00, 45.50, 25.30, true, NOW() - INTERVAL '30 minutes', 'Kitchen', NULL, NULL, 1250.75, NOW() - INTERVAL '30 minutes', 'trigger'),
  
  -- Bathroom device history
  ('ESP_BATHROOM_001', 'Bathroom Water Controller', 'closed', 0.00, 42.50, 24.50, true, NOW() - INTERVAL '2 hours', 'Bathroom', NULL, NULL, 880.00, NOW() - INTERVAL '2 hours', 'trigger'),
  ('ESP_BATHROOM_001', 'Bathroom Water Controller', 'open', 12.50, 42.00, 24.80, true, NOW() - INTERVAL '1 hour', 'Bathroom', NULL, NULL, 890.25, NOW() - INTERVAL '1 hour', 'trigger'),
  
  -- Kitchen device 2 history
  ('ESP_KITCHEN_002', 'Kitchen Water Controller', 'open', 10.20, 44.00, 26.00, true, NOW() - INTERVAL '3 hours', 'Kitchen', NULL, NULL, 2095.00, NOW() - INTERVAL '3 hours', 'trigger'),
  ('ESP_KITCHEN_002', 'Kitchen Water Controller', 'closed', 0.00, 44.20, 26.10, true, NOW() - INTERVAL '1 hour', 'Kitchen', NULL, NULL, 2100.50, NOW() - INTERVAL '1 hour', 'trigger'),
  
  -- Kitchen device 3 history
  ('ESP_KITCHEN_003', 'Kitchen Water Controller', 'open', 8.30, 46.00, 27.20, true, NOW() - INTERVAL '30 minutes', 'Kitchen', NULL, NULL, 3195.00, NOW() - INTERVAL '30 minutes', 'trigger'),
  ('ESP_KITCHEN_003', 'Kitchen Water Controller', 'open', 8.30, 46.00, 27.20, true, NOW() - INTERVAL '20 minutes', 'Kitchen', NULL, NULL, 3200.25, NOW() - INTERVAL '20 minutes', 'trigger');

COMMIT;

-- ============================================
-- VERIFICATION QUERIES (Optional - Run to check data)
-- ============================================

-- Check users
-- SELECT * FROM public.users LIMIT 20;

-- Check properties
-- SELECT id, property_name, address, city, user_id FROM properties;

-- Check devices
-- SELECT device_id, device_name, valve_status, water_flow, is_online, location FROM water_connection_control;

-- Check contacts
-- SELECT name, phone, contact_type, address FROM emergency_contacts;

-- Check leak detections
-- SELECT detection_date, leak_type, severity, status, location_description, estimated_water_loss_liters FROM water_leak_detections ORDER BY detection_date DESC;

-- Check history (last 10 records)
-- SELECT device_id, valve_status, water_flow, total_water_used, recorded_at FROM water_connection_control_history ORDER BY recorded_at DESC LIMIT 10;

