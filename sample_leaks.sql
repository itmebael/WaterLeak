-- Sample Leak Detection Records
-- 2 example leak detections for testing
-- Run this in Supabase SQL Editor

BEGIN;

INSERT INTO water_leak_detections (
  id, property_id, segment_id, detection_date, leak_type, severity, status,
  location_description, estimated_water_loss_liters, estimated_water_loss_rate,
  pressure_drop, flow_rate_anomaly, sensor_data, confidence_score, is_false_positive,
  resolved_date, resolution_notes, created_at, updated_at
)
VALUES
  -- Sample 1: Active High Severity Leak
  (
    gen_random_uuid(),
    NULL,  -- Replace with actual property_id if you have one
    NULL,  -- Replace with actual segment_id if you have one
    NOW() - INTERVAL '2 hours',
    'flow_based',
    'high',
    'active',
    'Kitchen sink pipe connection - continuous water flow detected',
    85.50,
    1.2,
    3.50,
    1.10,
    '{"flow_rate": 1.2, "valve_status": "closed", "duration_minutes": 71, "device_id": "ESP_KITCHEN_001"}'::jsonb,
    0.92,
    false,
    NULL,
    NULL,
    NOW() - INTERVAL '2 hours',
    NOW() - INTERVAL '2 hours'
  ),
  -- Sample 2: Resolved Medium Severity Leak
  (
    gen_random_uuid(),
    NULL,  -- Replace with actual property_id if you have one
    NULL,  -- Replace with actual segment_id if you have one
    NOW() - INTERVAL '5 days',
    'flow_based',
    'medium',
    'resolved',
    'Bathroom faucet base - slow drip detected',
    45.25,
    0.6,
    1.80,
    0.55,
    '{"flow_rate": 0.6, "valve_status": "closed", "duration_minutes": 75, "device_id": "ESP_BATHROOM_001"}'::jsonb,
    0.88,
    false,
    NOW() - INTERVAL '4 days',
    'Leak resolved by tightening faucet connection and replacing worn O-ring. System tested and verified no further leaks.',
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days'
  )
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- Verification query (optional)
-- SELECT 
--   id, 
--   detection_date, 
--   leak_type, 
--   severity, 
--   status, 
--   location_description, 
--   estimated_water_loss_liters,
--   resolved_date
-- FROM water_leak_detections 
-- ORDER BY detection_date DESC 
-- LIMIT 10;










