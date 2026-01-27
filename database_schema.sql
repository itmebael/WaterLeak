-- Water Leak Detection System Database Schema
-- Supabase SQL Schema

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS TABLE
CREATE TABLE users (
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
CREATE TABLE properties (
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
CREATE TABLE pipeline_segments (
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
CREATE TABLE water_consumption_daily (
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
CREATE TABLE water_consumption_weekly (
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
CREATE TABLE water_consumption_monthly (
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
CREATE TABLE water_leak_detections (
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
CREATE TABLE leak_notifications (
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
CREATE TABLE leak_history (
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
CREATE TABLE sensor_readings (
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
CREATE TABLE water_switch_controls (
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
CREATE TABLE emergency_contacts (
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
CREATE TABLE system_settings (
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

-- 14. WATER_SAVINGS_TARGETS TABLE
CREATE TABLE water_savings_targets (
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
CREATE TABLE maintenance_schedules (
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

-- 16. WATER_DATA TABLE (flow/usage data and valve status)
CREATE TABLE water_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    flow_rate NUMERIC(12,6),
    total_used NUMERIC(12,6),
    pressure DECIMAL(5,2),
    temperature DECIMAL(4,2),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sensor_id VARCHAR(100),
    location VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valve_status BOOLEAN DEFAULT TRUE
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_properties_user_id ON properties(user_id);
CREATE INDEX idx_pipeline_segments_property_id ON pipeline_segments(property_id);
CREATE INDEX idx_water_consumption_daily_property_date ON water_consumption_daily(property_id, consumption_date);
CREATE INDEX idx_water_consumption_weekly_property_week ON water_consumption_weekly(property_id, week_start_date);
CREATE INDEX idx_water_data_timestamp ON water_data(created_at);
CREATE INDEX idx_water_consumption_monthly_property_year_month ON water_consumption_monthly(property_id, year, month);
CREATE INDEX idx_water_leak_detections_property_date ON water_leak_detections(property_id, detection_date);
CREATE INDEX idx_water_leak_detections_status ON water_leak_detections(status);
CREATE INDEX idx_leak_notifications_user_id ON leak_notifications(user_id);
CREATE INDEX idx_sensor_readings_segment_timestamp ON sensor_readings(segment_id, reading_timestamp);
CREATE INDEX idx_emergency_contacts_user_id ON emergency_contacts(user_id);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_properties_updated_at BEFORE UPDATE ON properties FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_pipeline_segments_updated_at BEFORE UPDATE ON pipeline_segments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_water_consumption_daily_updated_at BEFORE UPDATE ON water_consumption_daily FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_water_consumption_weekly_updated_at BEFORE UPDATE ON water_consumption_weekly FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_water_consumption_monthly_updated_at BEFORE UPDATE ON water_consumption_monthly FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_water_leak_detections_updated_at BEFORE UPDATE ON water_leak_detections FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_water_switch_controls_updated_at BEFORE UPDATE ON water_switch_controls FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_emergency_contacts_updated_at BEFORE UPDATE ON emergency_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_water_savings_targets_updated_at BEFORE UPDATE ON water_savings_targets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
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
('water_rate_per_liter', '0.05', 'number', 'Water rate per liter in PHP', true);
