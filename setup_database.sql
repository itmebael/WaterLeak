-- Water Leak Detection System Database Setup
-- Run this script in your Supabase SQL editor to create all necessary tables

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    zip_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'Philippines',
    profile_image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. PROPERTIES TABLE
CREATE TABLE IF NOT EXISTS properties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    property_name VARCHAR(255) NOT NULL,
    property_type VARCHAR(100) NOT NULL, -- 'residential', 'commercial', 'industrial'
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    total_area DECIMAL(10,2), -- in square meters
    number_of_floors INTEGER DEFAULT 1,
    year_built INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. PIPELINE_SEGMENTS TABLE
CREATE TABLE IF NOT EXISTS pipeline_segments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    segment_name VARCHAR(255) NOT NULL,
    segment_type VARCHAR(100) NOT NULL, -- 'kitchen', 'bathroom', 'garden', 'main_line', 'irrigation'
    location_description TEXT,
    material VARCHAR(100), -- 'copper', 'pex', 'pvc', 'galvanized'
    diameter VARCHAR(50), -- '0.5 inch', '0.75 inch', '1 inch'
    age_years INTEGER,
    installation_date DATE,
    coordinates JSONB, -- Store pipe coordinates for visualization
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'inactive', 'maintenance'
    pressure_threshold_min DECIMAL(5,2),
    pressure_threshold_max DECIMAL(5,2),
    flow_threshold_min DECIMAL(5,2),
    flow_threshold_max DECIMAL(5,2),
    last_inspection_date DATE,
    next_inspection_date DATE,
    is_monitored BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. WATER_CONSUMPTION_DAILY TABLE
CREATE TABLE IF NOT EXISTS water_consumption_daily (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    segment_id UUID REFERENCES pipeline_segments(id) ON DELETE SET NULL,
    consumption_date DATE NOT NULL,
    total_consumption_liters DECIMAL(10,2) NOT NULL,
    peak_consumption_liters DECIMAL(10,2),
    average_flow_rate DECIMAL(5,2), -- liters per minute
    peak_flow_rate DECIMAL(5,2),
    number_of_usage_events INTEGER DEFAULT 0,
    duration_minutes INTEGER DEFAULT 0,
    cost_php DECIMAL(10,2) DEFAULT 0,
    is_anomaly BOOLEAN DEFAULT false,
    anomaly_score DECIMAL(3,2), -- 0.00 to 1.00
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(property_id, segment_id, consumption_date)
);

-- 5. WATER_CONSUMPTION_WEEKLY TABLE
CREATE TABLE IF NOT EXISTS water_consumption_weekly (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    week_end_date DATE NOT NULL,
    total_consumption_liters DECIMAL(10,2) NOT NULL,
    average_daily_consumption DECIMAL(10,2),
    peak_daily_consumption DECIMAL(10,2),
    total_cost_php DECIMAL(10,2) DEFAULT 0,
    number_of_anomaly_days INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(property_id, week_start_date)
);

-- 6. WATER_CONSUMPTION_MONTHLY TABLE
CREATE TABLE IF NOT EXISTS water_consumption_monthly (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL, -- 1-12
    total_consumption_liters DECIMAL(12,2) NOT NULL,
    average_daily_consumption DECIMAL(10,2),
    peak_daily_consumption DECIMAL(10,2),
    total_cost_php DECIMAL(10,2) DEFAULT 0,
    number_of_anomaly_days INTEGER DEFAULT 0,
    water_savings_liters DECIMAL(10,2) DEFAULT 0,
    money_saved_php DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(property_id, year, month)
);

-- 7. WATER_LEAK_DETECTIONS TABLE
CREATE TABLE IF NOT EXISTS water_leak_detections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    segment_id UUID REFERENCES pipeline_segments(id) ON DELETE SET NULL,
    detection_date TIMESTAMP WITH TIME ZONE NOT NULL,
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

-- 8. LEAK_NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS leak_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    leak_detection_id UUID REFERENCES water_leak_detections(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
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

-- 9. LEAK_HISTORY TABLE
CREATE TABLE IF NOT EXISTS leak_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    leak_detection_id UUID REFERENCES water_leak_detections(id) ON DELETE CASCADE,
    action_taken VARCHAR(255) NOT NULL,
    action_description TEXT,
    action_date TIMESTAMP WITH TIME ZONE NOT NULL,
    performed_by VARCHAR(255), -- 'user', 'system', 'plumber'
    cost_php DECIMAL(10,2) DEFAULT 0,
    repair_duration_minutes INTEGER,
    parts_replaced TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. SENSOR_READINGS TABLE
CREATE TABLE IF NOT EXISTS sensor_readings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    segment_id UUID REFERENCES pipeline_segments(id) ON DELETE CASCADE,
    reading_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
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

-- 11. WATER_SWITCH_CONTROLS TABLE
CREATE TABLE IF NOT EXISTS water_switch_controls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    segment_id UUID REFERENCES pipeline_segments(id) ON DELETE CASCADE,
    switch_name VARCHAR(255) NOT NULL,
    switch_type VARCHAR(100) NOT NULL, -- 'manual', 'automatic', 'scheduled'
    current_status VARCHAR(50) DEFAULT 'off', -- 'on', 'off', 'maintenance'
    last_activated TIMESTAMP WITH TIME ZONE,
    last_deactivated TIMESTAMP WITH TIME ZONE,
    activation_reason TEXT,
    deactivation_reason TEXT,
    is_auto_shutoff_enabled BOOLEAN DEFAULT true,
    auto_shutoff_threshold DECIMAL(5,2), -- liters per minute
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 12. EMERGENCY_CONTACTS TABLE
CREATE TABLE IF NOT EXISTS emergency_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    contact_type VARCHAR(100) NOT NULL, -- 'plumber', 'emergency', 'maintenance', 'developer'
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    company VARCHAR(255),
    address TEXT,
    is_primary BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 13. SYSTEM_SETTINGS TABLE
CREATE TABLE IF NOT EXISTS system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    setting_key VARCHAR(255) NOT NULL,
    setting_value TEXT,
    setting_type VARCHAR(50) DEFAULT 'string', -- 'string', 'number', 'boolean', 'json'
    description TEXT,
    is_system_setting BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, setting_key)
);

-- 13.1 ANNOUNCEMENTS TABLE
CREATE TABLE IF NOT EXISTS announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 14. WATER_SAVINGS_TARGETS TABLE
CREATE TABLE IF NOT EXISTS water_savings_targets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    target_type VARCHAR(100) NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly'
    target_period_start DATE NOT NULL,
    target_period_end DATE NOT NULL,
    target_consumption_liters DECIMAL(10,2) NOT NULL,
    actual_consumption_liters DECIMAL(10,2) DEFAULT 0,
    target_savings_percent DECIMAL(5,2), -- percentage
    target_savings_liters DECIMAL(10,2),
    is_achieved BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 15. MAINTENANCE_SCHEDULES TABLE
CREATE TABLE IF NOT EXISTS maintenance_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    segment_id UUID REFERENCES pipeline_segments(id) ON DELETE SET NULL,
    maintenance_type VARCHAR(100) NOT NULL, -- 'inspection', 'cleaning', 'repair', 'replacement'
    scheduled_date DATE NOT NULL,
    completed_date DATE,
    status VARCHAR(50) DEFAULT 'scheduled', -- 'scheduled', 'in_progress', 'completed', 'cancelled'
    description TEXT,
    assigned_to VARCHAR(255),
    cost_php DECIMAL(10,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 16. DEVICES TABLE
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    device_name TEXT NOT NULL,
    device_status TEXT DEFAULT 'active', -- 'active', 'inactive', 'maintenance', 'offline'
    valve_status TEXT DEFAULT 'CLOSED',
    water_flow DECIMAL(10,2) DEFAULT 0.00,
    device_location TEXT, -- Location where device is placed
    property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
    segment_id UUID REFERENCES pipeline_segments(id) ON DELETE SET NULL,
    notes TEXT
);

-- 17. KITCHEN_VALVE_CONTROL TABLE (for valve control functionality)
CREATE TABLE IF NOT EXISTS kitchen_valve_control (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    valve_status TEXT NOT NULL DEFAULT 'closed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT kitchen_valve_control_valve_status_check CHECK (
        valve_status = ANY (ARRAY['open'::text, 'closed'::text])
    )
);

-- 18. WATER_DATA TABLE (for flow/usage data and valve status)
CREATE TABLE IF NOT EXISTS water_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    flow_rate NUMERIC(12,6), -- liters per minute
    total_used NUMERIC(12,6), -- total water used
    pressure DECIMAL(5,2), -- PSI
    temperature DECIMAL(4,2), -- Celsius
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sensor_id VARCHAR(100),
    location VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valve_status BOOLEAN DEFAULT TRUE
);

-- 19. DEVICE_STATUS TABLE (Legacy/User Requested)
CREATE TABLE IF NOT EXISTS device_status (
    id uuid not null default gen_random_uuid (),
    device_name text not null,
    valve_status text not null default 'CLOSED'::text,
    water_flow numeric(6, 2) null default 0.00,
    status text not null default 'OFFLINE'::text,
    last_update timestamp with time zone null default now(),
    constraint device_status_pkey primary key (id),
    constraint unique_device_name unique (device_name)
) TABLESPACE pg_default;

-- Insert default 3 pipes for visualization
INSERT INTO device_status (device_name, valve_status, water_flow, status)
VALUES 
    ('Main Line', 'OPEN', 12.00, 'ONLINE'),
    ('Kitchen Line', 'OPEN', 5.50, 'ONLINE'),
    ('Bathroom Line', 'OPEN', 4.20, 'ONLINE')
ON CONFLICT (device_name) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_properties_user_id ON properties(user_id);
-- Create indexes conditionally to avoid errors if columns don't exist
DO $$ 
BEGIN
    -- Pipeline segments
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'pipeline_segments' AND column_name = 'property_id') THEN
        CREATE INDEX IF NOT EXISTS idx_pipeline_segments_property_id ON pipeline_segments(property_id);
    END IF;
    
    -- Water consumption daily
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'water_consumption_daily' AND column_name = 'property_id') THEN
        CREATE INDEX IF NOT EXISTS idx_water_consumption_daily_property_date ON water_consumption_daily(property_id, consumption_date);
    END IF;
    
    -- Water consumption weekly
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'water_consumption_weekly' AND column_name = 'property_id') THEN
        CREATE INDEX IF NOT EXISTS idx_water_consumption_weekly_property_week ON water_consumption_weekly(property_id, week_start_date);
    END IF;
    
    -- Water consumption monthly
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'water_consumption_monthly' AND column_name = 'property_id') THEN
        CREATE INDEX IF NOT EXISTS idx_water_consumption_monthly_property_year_month ON water_consumption_monthly(property_id, year, month);
    END IF;
    
    -- Water leak detections
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'water_leak_detections' AND column_name = 'property_id') THEN
        CREATE INDEX IF NOT EXISTS idx_water_leak_detections_property_date ON water_leak_detections(property_id, detection_date);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'water_leak_detections' AND column_name = 'status') THEN
        CREATE INDEX IF NOT EXISTS idx_water_leak_detections_status ON water_leak_detections(status);
    END IF;
    
    -- Leak notifications
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'leak_notifications' AND column_name = 'user_id') THEN
        CREATE INDEX IF NOT EXISTS idx_leak_notifications_user_id ON leak_notifications(user_id);
    END IF;
    
    -- Sensor readings
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'sensor_readings' AND column_name = 'segment_id') THEN
        CREATE INDEX IF NOT EXISTS idx_sensor_readings_segment_timestamp ON sensor_readings(segment_id, reading_timestamp);
    END IF;
    
    -- Emergency contacts
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'emergency_contacts' AND column_name = 'user_id') THEN
        CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON emergency_contacts(user_id);
    END IF;
    
    -- Devices
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'devices' AND column_name = 'created_at') THEN
        CREATE INDEX IF NOT EXISTS idx_devices_created_at ON devices(created_at);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'devices' AND column_name = 'property_id') THEN
        CREATE INDEX IF NOT EXISTS idx_devices_property_id ON devices(property_id);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' AND table_name = 'devices' AND column_name = 'user_id') THEN
        CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);
    END IF;
END $$;

-- Ensure properties table has all required columns
DO $$ 
BEGIN
    -- Add state column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'properties' AND column_name = 'state') THEN
        ALTER TABLE properties ADD COLUMN state VARCHAR(100);
        -- Update existing rows
        UPDATE properties SET state = 'Unknown' WHERE state IS NULL;
        -- Add NOT NULL constraint if needed
        ALTER TABLE properties ALTER COLUMN state SET DEFAULT 'Unknown';
    END IF;
    
    -- Add city column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'properties' AND column_name = 'city') THEN
        ALTER TABLE properties ADD COLUMN city VARCHAR(100);
        UPDATE properties SET city = 'Unknown' WHERE city IS NULL;
        ALTER TABLE properties ALTER COLUMN city SET DEFAULT 'Unknown';
    END IF;
    
    -- Add zip_code column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'properties' AND column_name = 'zip_code') THEN
        ALTER TABLE properties ADD COLUMN zip_code VARCHAR(20);
        UPDATE properties SET zip_code = '0000' WHERE zip_code IS NULL;
        ALTER TABLE properties ALTER COLUMN zip_code SET DEFAULT '0000';
    END IF;
    
    -- Add address column if missing (should exist but check anyway)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'properties' AND column_name = 'address') THEN
        ALTER TABLE properties ADD COLUMN address TEXT;
        UPDATE properties SET address = 'Unknown Address' WHERE address IS NULL;
    END IF;
END $$;

-- Add missing columns to devices table if they don't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'devices' AND column_name = 'user_id') THEN
        ALTER TABLE devices ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'devices' AND column_name = 'device_status') THEN
        ALTER TABLE devices ADD COLUMN device_status TEXT DEFAULT 'active';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'devices' AND column_name = 'device_location') THEN
        ALTER TABLE devices ADD COLUMN device_location TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'devices' AND column_name = 'property_id') THEN
        ALTER TABLE devices ADD COLUMN property_id UUID REFERENCES properties(id) ON DELETE SET NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'devices' AND column_name = 'segment_id') THEN
        ALTER TABLE devices ADD COLUMN segment_id UUID REFERENCES pipeline_segments(id) ON DELETE SET NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'devices' AND column_name = 'notes') THEN
        ALTER TABLE devices ADD COLUMN notes TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'devices' AND column_name = 'valve_status') THEN
        ALTER TABLE devices ADD COLUMN valve_status TEXT DEFAULT 'CLOSED';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'devices' AND column_name = 'water_flow') THEN
        ALTER TABLE devices ADD COLUMN water_flow DECIMAL(10,2) DEFAULT 0.00;
    END IF;
    
    -- Remove UNIQUE constraint on device_name if it exists (to allow same name for different users)
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'devices_device_name_key') THEN
        ALTER TABLE devices DROP CONSTRAINT devices_device_name_key;
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_kitchen_valve_control_status ON kitchen_valve_control(valve_status);
CREATE INDEX IF NOT EXISTS idx_water_data_timestamp ON water_data(created_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to relevant tables
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_properties_updated_at ON properties;
CREATE TRIGGER update_properties_updated_at BEFORE UPDATE ON properties FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_pipeline_segments_updated_at ON pipeline_segments;
CREATE TRIGGER update_pipeline_segments_updated_at BEFORE UPDATE ON pipeline_segments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_water_consumption_daily_updated_at ON water_consumption_daily;
CREATE TRIGGER update_water_consumption_daily_updated_at BEFORE UPDATE ON water_consumption_daily FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_water_consumption_weekly_updated_at ON water_consumption_weekly;
CREATE TRIGGER update_water_consumption_weekly_updated_at BEFORE UPDATE ON water_consumption_weekly FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_water_consumption_monthly_updated_at ON water_consumption_monthly;
CREATE TRIGGER update_water_consumption_monthly_updated_at BEFORE UPDATE ON water_consumption_monthly FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_water_leak_detections_updated_at ON water_leak_detections;
CREATE TRIGGER update_water_leak_detections_updated_at BEFORE UPDATE ON water_leak_detections FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_water_switch_controls_updated_at ON water_switch_controls;
CREATE TRIGGER update_water_switch_controls_updated_at BEFORE UPDATE ON water_switch_controls FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_emergency_contacts_updated_at ON emergency_contacts;
CREATE TRIGGER update_emergency_contacts_updated_at BEFORE UPDATE ON emergency_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_system_settings_updated_at ON system_settings;
CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_announcements_updated_at ON announcements;
CREATE TRIGGER update_announcements_updated_at BEFORE UPDATE ON announcements FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_water_savings_targets_updated_at ON water_savings_targets;
CREATE TRIGGER update_water_savings_targets_updated_at BEFORE UPDATE ON water_savings_targets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_maintenance_schedules_updated_at ON maintenance_schedules;
CREATE TRIGGER update_maintenance_schedules_updated_at BEFORE UPDATE ON maintenance_schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default system settings
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_system_setting) VALUES
('default_pressure_threshold_min', '30.0', 'number', 'Minimum pressure threshold in PSI', true),
('default_pressure_threshold_max', '80.0', 'number', 'Maximum pressure threshold in PSI', true),
('default_flow_threshold_min', '0.5', 'number', 'Minimum flow rate threshold in LPM', true),
('default_flow_threshold_max', '50.0', 'number', 'Maximum flow rate threshold in LPM', true),
('leak_detection_sensitivity', '0.7', 'number', 'Leak detection sensitivity (0.0-1.0)', true),
('notification_cooldown_minutes', '30', 'number', 'Minutes between notifications for same leak', true),
('auto_shutoff_enabled', 'true', 'boolean', 'Enable automatic water shutoff on leak detection', true),
('water_rate_per_liter', '0.05', 'number', 'Water rate per liter in PHP', true)
ON CONFLICT (user_id, setting_key) DO NOTHING;

-- Insert default emergency contacts for Catbalogan
INSERT INTO emergency_contacts (user_id, contact_type, name, phone, email, company, is_primary, is_active) VALUES
(NULL, 'plumber', 'Juan Dela Cruz', '+63 912 345 6789', 'juan.delacruz@email.com', 'Catbalogan Plumbing Services', true, true),
(NULL, 'emergency', 'Catbalogan Water District', '+63 55 251 2345', 'info@catbaloganwater.gov.ph', 'Catbalogan Water District', true, true),
(NULL, 'developer', 'Tech Solutions Inc.', '+63 917 123 4567', 'support@techsolutions.ph', 'Tech Solutions Inc.', true, true)
ON CONFLICT DO NOTHING;

-- Ensure water_data table has all required columns (in case table was created earlier)
DO $$ 
BEGIN
    -- Add columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='water_data' AND column_name='pressure') THEN
        ALTER TABLE water_data ADD COLUMN pressure DECIMAL(5,2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='water_data' AND column_name='temperature') THEN
        ALTER TABLE water_data ADD COLUMN temperature DECIMAL(4,2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='water_data' AND column_name='timestamp') THEN
        ALTER TABLE water_data ADD COLUMN timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='water_data' AND column_name='sensor_id') THEN
        ALTER TABLE water_data ADD COLUMN sensor_id VARCHAR(100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='water_data' AND column_name='location') THEN
        ALTER TABLE water_data ADD COLUMN location VARCHAR(255);
    END IF;
END $$;

-- Insert sample water data for testing
INSERT INTO water_data (flow_rate, total_used, pressure, temperature, sensor_id, location) VALUES
(2.5, 150.25, 45.0, 25.0, 'sensor_001', 'kitchen'),
(1.8, 89.75, 42.0, 24.5, 'sensor_002', 'bathroom'),
(0.0, 0.0, 40.0, 25.2, 'sensor_003', 'garden'),
(3.2, 245.50, 48.0, 24.8, 'sensor_004', 'main_line')
ON CONFLICT DO NOTHING;

-- Insert default kitchen valve control
INSERT INTO kitchen_valve_control (valve_status) VALUES
('closed')
ON CONFLICT DO NOTHING;

-- Enable Row Level Security (RLS) for better security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- Temporarily disable RLS for properties to allow inserts with custom auth
-- ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties DISABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_consumption_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_consumption_weekly ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_consumption_monthly ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_leak_detections ENABLE ROW LEVEL SECURITY;
ALTER TABLE leak_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE leak_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_switch_controls ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_savings_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (basic policies - you may want to customize these)
-- Note: Using custom authentication, so auth.uid() policies won't work
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

-- For custom auth: Allow operations (application layer handles user verification)
CREATE POLICY "Users can view own data" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own data" ON users FOR UPDATE USING (true);

-- Properties policies
-- Note: Using custom authentication system, so auth.uid() won't work
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own properties" ON properties;
DROP POLICY IF EXISTS "Users can insert own properties" ON properties;
DROP POLICY IF EXISTS "Users can update own properties" ON properties;
DROP POLICY IF EXISTS "Users can delete own properties" ON properties;

-- For custom auth: Allow operations when user_id is provided
-- The application layer ensures the correct user_id is set
CREATE POLICY "Users can view own properties" ON properties 
  FOR SELECT USING (true);

-- Allow inserts for any row (application ensures correct user_id)
CREATE POLICY "Users can insert own properties" ON properties 
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own properties" ON properties 
  FOR UPDATE USING (true);

CREATE POLICY "Users can delete own properties" ON properties 
  FOR DELETE USING (true);

-- Emergency contacts policies (allow public read for system contacts)
DROP POLICY IF EXISTS "Anyone can view system emergency contacts" ON emergency_contacts;
DROP POLICY IF EXISTS "Users can view own emergency contacts" ON emergency_contacts;
DROP POLICY IF EXISTS "Users can manage own emergency contacts" ON emergency_contacts;

CREATE POLICY "Anyone can view system emergency contacts" ON emergency_contacts FOR SELECT USING (user_id IS NULL);
CREATE POLICY "Users can view own emergency contacts" ON emergency_contacts FOR SELECT USING (true);
CREATE POLICY "Users can manage own emergency contacts" ON emergency_contacts FOR ALL USING (true);

-- System settings policies
DROP POLICY IF EXISTS "Anyone can view system settings" ON system_settings;
DROP POLICY IF EXISTS "Users can view own settings" ON system_settings;
DROP POLICY IF EXISTS "Users can manage own settings" ON system_settings;

CREATE POLICY "Anyone can view system settings" ON system_settings FOR SELECT USING (is_system_setting = true);
CREATE POLICY "Users can view own settings" ON system_settings FOR SELECT USING (true);
CREATE POLICY "Users can manage own settings" ON system_settings FOR ALL USING (true);

-- Water data policies (allow public read for sensor data)
DROP POLICY IF EXISTS "Anyone can view water data" ON water_data;
DROP POLICY IF EXISTS "Anyone can insert water data" ON water_data;

CREATE POLICY "Anyone can view water data" ON water_data FOR SELECT USING (true);
CREATE POLICY "Anyone can insert water data" ON water_data FOR INSERT WITH CHECK (true);

-- Kitchen valve control policies (allow public access for control)
DROP POLICY IF EXISTS "Anyone can view valve status" ON kitchen_valve_control;
DROP POLICY IF EXISTS "Anyone can update valve status" ON kitchen_valve_control;
DROP POLICY IF EXISTS "Anyone can insert valve status" ON kitchen_valve_control;

CREATE POLICY "Anyone can view valve status" ON kitchen_valve_control FOR SELECT USING (true);
CREATE POLICY "Anyone can update valve status" ON kitchen_valve_control FOR UPDATE USING (true);
CREATE POLICY "Anyone can insert valve status" ON kitchen_valve_control FOR INSERT WITH CHECK (true);

-- Devices policies (allow public access for device management)
DROP POLICY IF EXISTS "Anyone can view devices" ON devices;
DROP POLICY IF EXISTS "Anyone can insert devices" ON devices;
DROP POLICY IF EXISTS "Anyone can update devices" ON devices;
DROP POLICY IF EXISTS "Anyone can delete devices" ON devices;

CREATE POLICY "Anyone can view devices" ON devices FOR SELECT USING (true);
CREATE POLICY "Anyone can insert devices" ON devices FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update devices" ON devices FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete devices" ON devices FOR DELETE USING (true);

COMMIT;
CREATE TABLE IF NOT EXISTS public.device_status (
   id uuid not null default gen_random_uuid (),
   device_name text not null,
   valve_status text not null default 'CLOSED'::text,
   water_flow numeric(6, 2) null default 0.00,
   status text not null default 'OFFLINE'::text,
   last_update timestamp with time zone null default now(),
   constraint device_status_pkey primary key (id),
   constraint unique_device_name unique (device_name)
 ) TABLESPACE pg_default;
ALTER TABLE public.device_status ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS device_status_read ON public.device_status;
DROP POLICY IF EXISTS device_status_write ON public.device_status;
CREATE POLICY device_status_read ON public.device_status FOR SELECT USING (true);
CREATE POLICY device_status_write ON public.device_status FOR ALL USING (true);
INSERT INTO public.device_status (id, device_name, valve_status, water_flow, status, last_update) VALUES
 ('00872118-a50d-40c0-a729-2060418ba363','Device 1','CLOSED',0.00,'ONLINE','2025-12-13 13:47:56.726821+00'),
 ('6a097c60-973b-4f9a-8367-8a5ae981e630','Device 2','CLOSED',0.00,'OFFLINE','2025-12-13 13:47:56.726821+00'),
 ('d01553e7-6cbb-48df-a1c9-d25d17cfc139','Device 3','CLOSED',0.00,'OFFLINE','2025-12-13 13:47:56.726821+00')
ON CONFLICT DO NOTHING;
