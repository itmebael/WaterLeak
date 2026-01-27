-- Kitchen Water Control System - SQL Setup
-- This script sets up the database for ESP32 kitchen water control
-- Run this in Supabase SQL Editor

BEGIN;

-- ============================================
-- 1. ENSURE WATER_CONNECTION_CONTROL TABLE EXISTS
-- ============================================

CREATE TABLE IF NOT EXISTS water_connection_control (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR(100) NOT NULL UNIQUE,
  device_name TEXT NOT NULL,
  valve_status TEXT NOT NULL DEFAULT 'closed',
  water_flow DECIMAL(10, 2) DEFAULT 0.00,
  pressure DECIMAL(5, 2) DEFAULT 0.00,
  temperature DECIMAL(4, 2) DEFAULT 0.00,
  is_online BOOLEAN DEFAULT false,
  last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  location TEXT,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT water_connection_control_valve_status_check CHECK (
    valve_status = ANY (ARRAY['open'::text, 'closed'::text])
  )
);

-- ============================================
-- 2. ENSURE WATER_CONNECTION_COMMANDS TABLE EXISTS
-- ============================================

CREATE TABLE IF NOT EXISTS water_connection_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR(100) NOT NULL,
  command_type TEXT NOT NULL,
  command_data JSONB,
  status TEXT NOT NULL DEFAULT 'pending',
  executed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT water_connection_commands_status_check CHECK (
    status = ANY (ARRAY['pending'::text, 'executed'::text, 'failed'::text])
  )
);

-- ============================================
-- 3. ENSURE SENSOR_READINGS TABLE EXISTS
-- ============================================

CREATE TABLE IF NOT EXISTS sensor_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  segment_id UUID REFERENCES pipeline_segments(id) ON DELETE CASCADE,
  reading_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  pressure_psi DECIMAL(5,2),
  flow_rate_lpm DECIMAL(5,2),
  temperature_celsius DECIMAL(4,2),
  humidity_percent DECIMAL(4,2),
  vibration_level DECIMAL(4,2),
  sensor_status VARCHAR(50) DEFAULT 'normal',
  battery_level DECIMAL(3,2),
  signal_strength INTEGER,
  raw_data JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 4. ENSURE WATER_LEAK_DETECTIONS TABLE EXISTS
-- ============================================

CREATE TABLE IF NOT EXISTS water_leak_detections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  segment_id UUID REFERENCES pipeline_segments(id) ON DELETE SET NULL,
  detection_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  leak_type VARCHAR(100) NOT NULL,
  severity VARCHAR(50) NOT NULL,
  status VARCHAR(50) DEFAULT 'active',
  location_description TEXT,
  estimated_water_loss_liters DECIMAL(10,2),
  estimated_water_loss_rate DECIMAL(5,2),
  pressure_drop DECIMAL(5,2),
  flow_rate_anomaly DECIMAL(5,2),
  sensor_data JSONB,
  confidence_score DECIMAL(3,2),
  is_false_positive BOOLEAN DEFAULT false,
  resolved_date TIMESTAMP WITH TIME ZONE,
  resolution_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 5. CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- Water connection control indexes
CREATE INDEX IF NOT EXISTS idx_water_control_device_id ON water_connection_control(device_id);
CREATE INDEX IF NOT EXISTS idx_water_control_location ON water_connection_control(location);
CREATE INDEX IF NOT EXISTS idx_water_control_is_online ON water_connection_control(is_online);

-- Commands indexes
CREATE INDEX IF NOT EXISTS idx_commands_device_id ON water_connection_commands(device_id);
CREATE INDEX IF NOT EXISTS idx_commands_status ON water_connection_commands(status);
CREATE INDEX IF NOT EXISTS idx_commands_device_status ON water_connection_commands(device_id, status);

-- Sensor readings indexes
CREATE INDEX IF NOT EXISTS idx_sensor_readings_segment_id ON sensor_readings(segment_id);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_timestamp ON sensor_readings(reading_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_status ON sensor_readings(sensor_status);

-- Leak detections indexes
CREATE INDEX IF NOT EXISTS idx_leak_detections_property_id ON water_leak_detections(property_id);
CREATE INDEX IF NOT EXISTS idx_leak_detections_segment_id ON water_leak_detections(segment_id);
CREATE INDEX IF NOT EXISTS idx_leak_detections_status ON water_leak_detections(status);
CREATE INDEX IF NOT EXISTS idx_leak_detections_location ON water_leak_detections(location_description);

-- ============================================
-- 6. ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE water_connection_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_connection_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_leak_detections ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 7. DROP EXISTING POLICIES (if any)
-- ============================================

-- Water connection control policies
DROP POLICY IF EXISTS "Anyone can view water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can insert water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can update water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can delete water connection control" ON water_connection_control;

-- Commands policies
DROP POLICY IF EXISTS "Anyone can view water connection commands" ON water_connection_commands;
DROP POLICY IF EXISTS "Anyone can insert water connection commands" ON water_connection_commands;
DROP POLICY IF EXISTS "Anyone can update water connection commands" ON water_connection_commands;

-- Sensor readings policies
DROP POLICY IF EXISTS "Anyone can view sensor readings" ON sensor_readings;
DROP POLICY IF EXISTS "Anyone can insert sensor readings" ON sensor_readings;
DROP POLICY IF EXISTS "Anyone can update sensor readings" ON sensor_readings;

-- Leak detections policies
DROP POLICY IF EXISTS "Anyone can view leak detections" ON water_leak_detections;
DROP POLICY IF EXISTS "Anyone can insert leak detections" ON water_leak_detections;
DROP POLICY IF EXISTS "Anyone can update leak detections" ON water_leak_detections;

-- ============================================
-- 8. CREATE RLS POLICIES (Allow ESP32 to insert/update)
-- ============================================

-- Water connection control policies
CREATE POLICY "Anyone can view water connection control" ON water_connection_control
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert water connection control" ON water_connection_control
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update water connection control" ON water_connection_control
  FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete water connection control" ON water_connection_control
  FOR DELETE USING (true);

-- Commands policies
CREATE POLICY "Anyone can view water connection commands" ON water_connection_commands
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert water connection commands" ON water_connection_commands
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update water connection commands" ON water_connection_commands
  FOR UPDATE USING (true);

-- Sensor readings policies
CREATE POLICY "Anyone can view sensor readings" ON sensor_readings
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert sensor readings" ON sensor_readings
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update sensor readings" ON sensor_readings
  FOR UPDATE USING (true);

-- Leak detections policies
CREATE POLICY "Anyone can view leak detections" ON water_leak_detections
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert leak detections" ON water_leak_detections
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update leak detections" ON water_leak_detections
  FOR UPDATE USING (true);

-- ============================================
-- 9. CREATE TRIGGER FOR UPDATED_AT
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_water_control_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for water_connection_control
DROP TRIGGER IF EXISTS trigger_update_water_control_updated_at ON water_connection_control;
CREATE TRIGGER trigger_update_water_control_updated_at
  BEFORE UPDATE ON water_connection_control
  FOR EACH ROW
  EXECUTE FUNCTION update_water_control_updated_at();

-- Trigger for water_leak_detections
DROP TRIGGER IF EXISTS trigger_update_leak_detections_updated_at ON water_leak_detections;
CREATE TRIGGER trigger_update_leak_detections_updated_at
  BEFORE UPDATE ON water_leak_detections
  FOR EACH ROW
  EXECUTE FUNCTION update_water_control_updated_at();

-- ============================================
-- 10. GRANT PERMISSIONS
-- ============================================

GRANT ALL ON water_connection_control TO authenticated;
GRANT ALL ON water_connection_control TO anon;
GRANT ALL ON water_connection_commands TO authenticated;
GRANT ALL ON water_connection_commands TO anon;
GRANT ALL ON sensor_readings TO authenticated;
GRANT ALL ON sensor_readings TO anon;
GRANT ALL ON water_leak_detections TO authenticated;
GRANT ALL ON water_leak_detections TO anon;

-- ============================================
-- 11. INSERT/UPDATE KITCHEN DEVICE
-- ============================================

-- Insert kitchen device (or update if exists)
INSERT INTO water_connection_control (
  device_id,
  device_name,
  location,
  valve_status,
  water_flow,
  is_online,
  last_heartbeat
)
VALUES (
  'ESP_KITCHEN_001',
  'Kitchen Water Line',
  'Kitchen',
  'closed',
  0.00,
  false,
  NOW()
)
ON CONFLICT (device_id) 
DO UPDATE SET
  device_name = EXCLUDED.device_name,
  location = EXCLUDED.location,
  updated_at = NOW();

-- ============================================
-- 12. CREATE KITCHEN SEGMENT (if not exists)
-- ============================================

-- First, get a property_id (you need to replace this with actual property ID)
-- This will create a kitchen segment if it doesn't exist
-- You may need to adjust the property_id and other values

DO $$
DECLARE
  v_property_id UUID;
  v_segment_id UUID;
BEGIN
  -- Get first property (or use specific one)
  SELECT id INTO v_property_id FROM properties LIMIT 1;
  
  IF v_property_id IS NOT NULL THEN
    -- Check if kitchen segment exists
    SELECT id INTO v_segment_id 
    FROM pipeline_segments 
    WHERE (location_description ILIKE '%kitchen%' 
           OR segment_name ILIKE '%kitchen%' 
           OR segment_type ILIKE '%kitchen%')
    LIMIT 1;
    
    -- Create kitchen segment if it doesn't exist
    IF v_segment_id IS NULL THEN
      INSERT INTO pipeline_segments (
        property_id,
        segment_name,
        location_description,
        segment_type,
        diameter,
        material
      )
      VALUES (
        v_property_id,
        'Kitchen Line',
        'Kitchen',
        'kitchen',
        '0.5 inch',
        'copper'
      )
      RETURNING id INTO v_segment_id;
      
      RAISE NOTICE 'Kitchen segment created with ID: %', v_segment_id;
    ELSE
      RAISE NOTICE 'Kitchen segment already exists with ID: %', v_segment_id;
    END IF;
  ELSE
    RAISE NOTICE 'No properties found. Please create a property first.';
  END IF;
END $$;

COMMIT;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check kitchen device
-- SELECT * FROM water_connection_control WHERE device_id = 'ESP_KITCHEN_001';

-- Check kitchen segment
-- SELECT id, segment_name, location_description, segment_type 
-- FROM pipeline_segments 
-- WHERE location_description ILIKE '%kitchen%' 
--    OR segment_name ILIKE '%kitchen%' 
--    OR segment_type = 'kitchen';

-- Check RLS policies
-- SELECT tablename, policyname, cmd FROM pg_policies 
-- WHERE tablename IN ('water_connection_control', 'water_connection_commands', 'sensor_readings', 'water_leak_detections');

-- ============================================
-- USAGE EXAMPLES
-- ============================================

-- Send command to open kitchen valve:
-- INSERT INTO water_connection_commands (device_id, command_type, status)
-- VALUES ('ESP_KITCHEN_001', 'open_valve', 'pending');

-- Send command to close kitchen valve:
-- INSERT INTO water_connection_commands (device_id, command_type, status)
-- VALUES ('ESP_KITCHEN_001', 'close_valve', 'pending');

-- Send command to enable auto control:
-- INSERT INTO water_connection_commands (device_id, command_type, status)
-- VALUES ('ESP_KITCHEN_001', 'enable_auto', 'pending');

-- View kitchen device status:
-- SELECT device_id, device_name, valve_status, water_flow, is_online, last_heartbeat
-- FROM water_connection_control
-- WHERE device_id = 'ESP_KITCHEN_001';

-- View kitchen sensor readings:
-- SELECT reading_timestamp, flow_rate_lpm, sensor_status
-- FROM sensor_readings
-- WHERE segment_id IN (
--   SELECT id FROM pipeline_segments 
--   WHERE location_description ILIKE '%kitchen%' 
--      OR segment_name ILIKE '%kitchen%' 
--      OR segment_type = 'kitchen'
-- )
-- ORDER BY reading_timestamp DESC
-- LIMIT 10;

-- View kitchen leak detections:
-- SELECT detection_date, leak_type, severity, flow_rate_anomaly, status
-- FROM water_leak_detections
-- WHERE location_description ILIKE '%kitchen%'
-- ORDER BY detection_date DESC
-- LIMIT 10;

-- ============================================
-- NOTES
-- ============================================

-- 1. ESP32 device uses device_id: 'ESP_KITCHEN_001'
-- 2. Location is set to 'Kitchen' for all kitchen-related data
-- 3. RLS policies allow anonymous inserts (for ESP32 using anon key)
-- 4. Kitchen segment is created automatically if it doesn't exist
-- 5. Make sure to update segment_id and property_id in ESP32 code after running this script

