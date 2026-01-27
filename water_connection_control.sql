-- Water Connection Control SQL Schema
-- This script sets up tables and policies for ESP-based water valve control

BEGIN;

-- 1. WATER_CONNECTION_CONTROL TABLE (Main control table for ESP devices)
CREATE TABLE IF NOT EXISTS public.water_connection_control (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR(100) NOT NULL UNIQUE, -- ESP device identifier (e.g., "ESP_001", "ESP_002")
  device_name TEXT NOT NULL, -- Human-readable name (e.g., "Main Line", "Kitchen Line")
  valve_status TEXT NOT NULL DEFAULT 'closed', -- 'open' or 'closed'
  water_flow DECIMAL(10, 2) DEFAULT 0.00, -- Current flow rate in L/min
  pressure DECIMAL(5, 2) DEFAULT 0.00, -- Water pressure in PSI (optional)
  temperature DECIMAL(4, 2) DEFAULT 0.00, -- Water temperature in Celsius (optional)
  is_online BOOLEAN DEFAULT false, -- Device connection status
  last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT NOW(), -- Last communication from device
  location TEXT, -- Physical location of the device
  user_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Optional: link to user
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL, -- Optional: link to property
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT water_connection_control_valve_status_check CHECK (
    valve_status = ANY (ARRAY['open'::text, 'closed'::text])
  )
);

-- 2. WATER_CONNECTION_COMMANDS TABLE (Command queue for ESP devices)
CREATE TABLE IF NOT EXISTS public.water_connection_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR(100) NOT NULL, -- ESP device identifier
  command_type TEXT NOT NULL, -- 'open_valve', 'close_valve', 'get_status'
  command_data JSONB, -- Additional command parameters
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'executed', 'failed'
  executed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT water_connection_commands_status_check CHECK (
    status = ANY (ARRAY['pending'::text, 'executed'::text, 'failed'::text])
  )
);

-- 3. WATER_CONNECTION_LOGS TABLE (Historical data and events)
CREATE TABLE IF NOT EXISTS public.water_connection_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR(100) NOT NULL,
  event_type TEXT NOT NULL, -- 'valve_opened', 'valve_closed', 'flow_detected', 'leak_detected', 'heartbeat'
  event_data JSONB, -- Additional event information
  valve_status TEXT,
  water_flow DECIMAL(10, 2),
  pressure DECIMAL(5, 2),
  temperature DECIMAL(4, 2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_water_connection_control_device_id ON water_connection_control(device_id);
CREATE INDEX IF NOT EXISTS idx_water_connection_control_user_id ON water_connection_control(user_id);
CREATE INDEX IF NOT EXISTS idx_water_connection_commands_device_id ON water_connection_commands(device_id);
CREATE INDEX IF NOT EXISTS idx_water_connection_commands_status ON water_connection_commands(status);
CREATE INDEX IF NOT EXISTS idx_water_connection_logs_device_id ON water_connection_logs(device_id);
CREATE INDEX IF NOT EXISTS idx_water_connection_logs_created_at ON water_connection_logs(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.water_connection_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_connection_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_connection_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can insert water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can update water connection control" ON water_connection_control;
DROP POLICY IF EXISTS "Anyone can delete water connection control" ON water_connection_control;

DROP POLICY IF EXISTS "Anyone can view water connection commands" ON water_connection_commands;
DROP POLICY IF EXISTS "Anyone can insert water connection commands" ON water_connection_commands;
DROP POLICY IF EXISTS "Anyone can update water connection commands" ON water_connection_commands;

DROP POLICY IF EXISTS "Anyone can view water connection logs" ON water_connection_logs;
DROP POLICY IF EXISTS "Anyone can insert water connection logs" ON water_connection_logs;

-- Create RLS policies for water_connection_control
CREATE POLICY "Anyone can view water connection control" ON water_connection_control
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert water connection control" ON water_connection_control
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update water connection control" ON water_connection_control
  FOR UPDATE USING (true);

CREATE POLICY "Anyone can delete water connection control" ON water_connection_control
  FOR DELETE USING (true);

-- Create RLS policies for water_connection_commands
CREATE POLICY "Anyone can view water connection commands" ON water_connection_commands
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert water connection commands" ON water_connection_commands
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update water connection commands" ON water_connection_commands
  FOR UPDATE USING (true);

-- Create RLS policies for water_connection_logs
CREATE POLICY "Anyone can view water connection logs" ON water_connection_logs
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert water connection logs" ON water_connection_logs
  FOR INSERT WITH CHECK (true);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_water_connection_control_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS trigger_update_water_connection_control_updated_at ON water_connection_control;
CREATE TRIGGER trigger_update_water_connection_control_updated_at
  BEFORE UPDATE ON water_connection_control
  FOR EACH ROW
  EXECUTE FUNCTION update_water_connection_control_updated_at();

-- Insert default device entries (optional - adjust device_id to match your ESP devices)
INSERT INTO public.water_connection_control (device_id, device_name, valve_status, location, is_online)
VALUES 
  ('ESP_001', 'Main Water Line', 'closed', 'Main Entry', false),
  ('ESP_002', 'Kitchen Line', 'closed', 'Kitchen', false),
  ('ESP_003', 'Bathroom Line', 'closed', 'Bathroom', false)
ON CONFLICT (device_id) DO NOTHING;

-- Grant necessary permissions
GRANT ALL ON public.water_connection_control TO authenticated;
GRANT ALL ON public.water_connection_control TO anon;
GRANT ALL ON public.water_connection_commands TO authenticated;
GRANT ALL ON public.water_connection_commands TO anon;
GRANT ALL ON public.water_connection_logs TO authenticated;
GRANT ALL ON public.water_connection_logs TO anon;

COMMIT;

-- Usage Notes:
-- 1. ESP devices should poll water_connection_commands table for pending commands
-- 2. ESP devices should update water_connection_control table with current status
-- 3. ESP devices should insert logs into water_connection_logs for events
-- 4. Device heartbeat: Update last_heartbeat and is_online in water_connection_control
-- 5. To send a command: INSERT into water_connection_commands with status='pending'
-- 6. ESP device should UPDATE command status to 'executed' or 'failed' after processing



