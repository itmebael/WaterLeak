-- ESP32 Leak Detection System - SQL Setup
-- This script ensures all tables and policies are set up for ESP32 devices
-- Run this in Supabase SQL Editor after running the main database setup

BEGIN;

-- ============================================
-- 1. ENSURE TABLES EXIST
-- ============================================

-- SENSOR_READINGS TABLE (for ESP32 to send sensor data)
CREATE TABLE IF NOT EXISTS sensor_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_id UUID REFERENCES pipeline_segments(id) ON DELETE CASCADE,
    reading_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    pressure_psi DECIMAL(5,2),
    flow_rate_lpm DECIMAL(5,2), -- liters per minute
    temperature_celsius DECIMAL(4,2),
    humidity_percent DECIMAL(4,2),
    vibration_level DECIMAL(4,2),
    sensor_status VARCHAR(50) DEFAULT 'normal', -- 'normal', 'warning', 'error'
    battery_level DECIMAL(3,2), -- 0.00 to 1.00
    signal_strength INTEGER, -- 0-100
    raw_data JSONB, -- Store additional sensor data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- WATER_LEAK_DETECTIONS TABLE (for ESP32 to report leaks)
CREATE TABLE IF NOT EXISTS water_leak_detections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    segment_id UUID REFERENCES pipeline_segments(id) ON DELETE SET NULL,
    detection_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    leak_type VARCHAR(100) NOT NULL, -- 'continuous', 'intermittent', 'drip', 'burst'
    severity VARCHAR(50) NOT NULL, -- 'low', 'medium', 'high', 'critical'
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'resolved', 'investigating'
    location_description TEXT,
    estimated_water_loss_liters DECIMAL(10,2),
    estimated_water_loss_rate DECIMAL(5,2), -- liters per hour
    pressure_drop DECIMAL(5,2),
    flow_rate_anomaly DECIMAL(5,2),
    sensor_data JSONB, -- Store raw sensor readings
    confidence_score DECIMAL(3,2), -- 0.00 to 1.00
    is_false_positive BOOLEAN DEFAULT false,
    resolved_date TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- LEAK_NOTIFICATIONS TABLE (for ESP32 to create notifications)
CREATE TABLE IF NOT EXISTS leak_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    leak_detection_id UUID REFERENCES water_leak_detections(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL, -- NULL for system notifications
    notification_type VARCHAR(100) NOT NULL, -- 'email', 'sms', 'push', 'in_app'
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(50) NOT NULL, -- 'low', 'medium', 'high', 'critical'
    is_read BOOLEAN DEFAULT false,
    is_sent BOOLEAN DEFAULT false,
    sent_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- Sensor readings indexes
CREATE INDEX IF NOT EXISTS idx_sensor_readings_segment_id ON sensor_readings(segment_id);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_timestamp ON sensor_readings(reading_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_segment_timestamp ON sensor_readings(segment_id, reading_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_status ON sensor_readings(sensor_status);

-- Leak detections indexes
CREATE INDEX IF NOT EXISTS idx_water_leak_detections_property_id ON water_leak_detections(property_id);
CREATE INDEX IF NOT EXISTS idx_water_leak_detections_segment_id ON water_leak_detections(segment_id);
CREATE INDEX IF NOT EXISTS idx_water_leak_detections_status ON water_leak_detections(status);
CREATE INDEX IF NOT EXISTS idx_water_leak_detections_date ON water_leak_detections(detection_date DESC);
CREATE INDEX IF NOT EXISTS idx_water_leak_detections_property_status ON water_leak_detections(property_id, status);

-- Leak notifications indexes
CREATE INDEX IF NOT EXISTS idx_leak_notifications_leak_id ON leak_notifications(leak_detection_id);
CREATE INDEX IF NOT EXISTS idx_leak_notifications_user_id ON leak_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_leak_notifications_is_read ON leak_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_leak_notifications_created_at ON leak_notifications(created_at DESC);

-- ============================================
-- 3. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_leak_detections ENABLE ROW LEVEL SECURITY;
ALTER TABLE leak_notifications ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. DROP EXISTING POLICIES (if any)
-- ============================================

-- Sensor readings policies
DROP POLICY IF EXISTS "Anyone can view sensor readings" ON sensor_readings;
DROP POLICY IF EXISTS "Anyone can insert sensor readings" ON sensor_readings;
DROP POLICY IF EXISTS "Anyone can update sensor readings" ON sensor_readings;
DROP POLICY IF EXISTS "Users can view own sensor readings" ON sensor_readings;
DROP POLICY IF EXISTS "Users can insert own sensor readings" ON sensor_readings;

-- Leak detections policies
DROP POLICY IF EXISTS "Anyone can view leak detections" ON water_leak_detections;
DROP POLICY IF EXISTS "Anyone can insert leak detections" ON water_leak_detections;
DROP POLICY IF EXISTS "Anyone can update leak detections" ON water_leak_detections;
DROP POLICY IF EXISTS "Users can view own leak detections" ON water_leak_detections;
DROP POLICY IF EXISTS "Users can insert own leak detections" ON water_leak_detections;
DROP POLICY IF EXISTS "Users can update own leak detections" ON water_leak_detections;

-- Leak notifications policies
DROP POLICY IF EXISTS "Anyone can view leak notifications" ON leak_notifications;
DROP POLICY IF EXISTS "Anyone can insert leak notifications" ON leak_notifications;
DROP POLICY IF EXISTS "Anyone can update leak notifications" ON leak_notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON leak_notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON leak_notifications;

-- ============================================
-- 5. CREATE RLS POLICIES (Allow ESP32 devices to insert data)
-- ============================================

-- SENSOR_READINGS POLICIES
-- Allow anyone (including ESP32 devices) to insert sensor readings
CREATE POLICY "Anyone can insert sensor readings" ON sensor_readings
    FOR INSERT
    WITH CHECK (true);

-- Allow anyone to view sensor readings
CREATE POLICY "Anyone can view sensor readings" ON sensor_readings
    FOR SELECT
    USING (true);

-- Allow anyone to update sensor readings (for corrections)
CREATE POLICY "Anyone can update sensor readings" ON sensor_readings
    FOR UPDATE
    USING (true);

-- WATER_LEAK_DETECTIONS POLICIES
-- Allow anyone (including ESP32 devices) to insert leak detections
CREATE POLICY "Anyone can insert leak detections" ON water_leak_detections
    FOR INSERT
    WITH CHECK (true);

-- Allow anyone to view leak detections
CREATE POLICY "Anyone can view leak detections" ON water_leak_detections
    FOR SELECT
    USING (true);

-- Allow anyone to update leak detections (for status changes, resolution)
CREATE POLICY "Anyone can update leak detections" ON water_leak_detections
    FOR UPDATE
    USING (true);

-- LEAK_NOTIFICATIONS POLICIES
-- Allow anyone (including ESP32 devices) to insert notifications
CREATE POLICY "Anyone can insert leak notifications" ON leak_notifications
    FOR INSERT
    WITH CHECK (true);

-- Allow anyone to view notifications
CREATE POLICY "Anyone can view leak notifications" ON leak_notifications
    FOR SELECT
    USING (true);

-- Allow anyone to update notifications (for read status, sent status)
CREATE POLICY "Anyone can update leak notifications" ON leak_notifications
    FOR UPDATE
    USING (true);

-- ============================================
-- 6. CREATE TRIGGER FOR UPDATED_AT
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for water_leak_detections
DROP TRIGGER IF EXISTS update_water_leak_detections_updated_at ON water_leak_detections;
CREATE TRIGGER update_water_leak_detections_updated_at
    BEFORE UPDATE ON water_leak_detections
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 7. GRANT PERMISSIONS
-- ============================================

-- Grant permissions to authenticated users
GRANT ALL ON sensor_readings TO authenticated;
GRANT ALL ON water_leak_detections TO authenticated;
GRANT ALL ON leak_notifications TO authenticated;

-- Grant permissions to anonymous users (for ESP32 devices using anon key)
GRANT ALL ON sensor_readings TO anon;
GRANT ALL ON water_leak_detections TO anon;
GRANT ALL ON leak_notifications TO anon;

-- ============================================
-- 8. CREATE HELPER FUNCTIONS (Optional)
-- ============================================

-- Function to get latest sensor reading for a segment
CREATE OR REPLACE FUNCTION get_latest_sensor_reading(p_segment_id UUID)
RETURNS TABLE (
    id UUID,
    segment_id UUID,
    reading_timestamp TIMESTAMP WITH TIME ZONE,
    pressure_psi DECIMAL,
    flow_rate_lpm DECIMAL,
    sensor_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sr.id,
        sr.segment_id,
        sr.reading_timestamp,
        sr.pressure_psi,
        sr.flow_rate_lpm,
        sr.sensor_status
    FROM sensor_readings sr
    WHERE sr.segment_id = p_segment_id
    ORDER BY sr.reading_timestamp DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get active leaks for a property
CREATE OR REPLACE FUNCTION get_active_leaks(p_property_id UUID)
RETURNS TABLE (
    id UUID,
    detection_date TIMESTAMP WITH TIME ZONE,
    leak_type VARCHAR,
    severity VARCHAR,
    location_description TEXT,
    estimated_water_loss_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wld.id,
        wld.detection_date,
        wld.leak_type,
        wld.severity,
        wld.location_description,
        wld.estimated_water_loss_rate
    FROM water_leak_detections wld
    WHERE wld.property_id = p_property_id
    AND wld.status = 'active'
    ORDER BY wld.detection_date DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if tables exist
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' 
-- AND table_name IN ('sensor_readings', 'water_leak_detections', 'leak_notifications');

-- Check RLS policies
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename IN ('sensor_readings', 'water_leak_detections', 'leak_notifications');

-- Test insert (replace with actual UUIDs from your database)
-- INSERT INTO sensor_readings (segment_id, pressure_psi, flow_rate_lpm, sensor_status)
-- VALUES ('YOUR_SEGMENT_ID', 45.5, 5.2, 'normal');

-- ============================================
-- NOTES FOR ESP32 CONFIGURATION
-- ============================================

-- 1. ESP32 devices use the Supabase "anon" key for authentication
-- 2. The RLS policies allow anonymous inserts, so ESP32 can send data without user authentication
-- 3. Make sure segment_id and property_id in ESP32 code match actual UUIDs in your database
-- 4. To find segment_id and property_id:
--    SELECT id, name FROM pipeline_segments;
--    SELECT id, property_name FROM properties;
-- 5. Update ESP32 code with these UUIDs:
--    const char* segmentId = "your-segment-uuid-here";
--    const char* propertyId = "your-property-uuid-here";




