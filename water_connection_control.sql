-- Water Connection Control SQL Schema
-- This script sets up tables and policies for ESP-based water valve control

BEGIN;

-- 1. WATER_CONNECTION_CONTROL TABLE (Main control table for ESP devices)
CREATE TABLE IF NOT EXISTS public.water_connection_control (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    device_id character varying(100) NOT NULL,
    device_name text NOT NULL,
    valve_status text NOT NULL DEFAULT 'closed'::text,
    water_flow numeric(10, 2) NULL DEFAULT 0.00,
    pressure numeric(5, 2) NULL DEFAULT 0.00,
    temperature numeric(4, 2) NULL DEFAULT 0.00,
    is_online boolean NULL DEFAULT false,
    last_heartbeat timestamp with time zone NULL DEFAULT now(),
    location text NULL,
    user_id uuid NULL,
    property_id uuid NULL,
    created_at timestamp with time zone NULL DEFAULT now(),
    updated_at timestamp with time zone NULL DEFAULT now(),
    total_water_used numeric(10, 2) NULL DEFAULT 0.00,
    sensor_data jsonb NULL DEFAULT '{}'::jsonb,
    CONSTRAINT water_connection_control_pkey PRIMARY KEY (id),
    CONSTRAINT water_connection_control_device_id_key UNIQUE (device_id),
    CONSTRAINT water_connection_control_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE SET NULL,
    CONSTRAINT water_connection_control_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT water_connection_control_valve_status_check CHECK (valve_status = ANY (ARRAY['open'::text, 'closed'::text]))
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_water_control_device_id ON public.water_connection_control USING btree (device_id);
CREATE INDEX IF NOT EXISTS idx_water_control_location ON public.water_connection_control USING btree (location);
CREATE INDEX IF NOT EXISTS idx_water_control_is_online ON public.water_connection_control USING btree (is_online);
CREATE INDEX IF NOT EXISTS idx_water_control_sensor_data ON public.water_connection_control USING gin (sensor_data);

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

-- Create indexes for commands and logs
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
CREATE POLICY "Anyone can view water connection control" ON water_connection_control FOR SELECT USING (true);
CREATE POLICY "Anyone can insert water connection control" ON water_connection_control FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update water connection control" ON water_connection_control FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete water connection control" ON water_connection_control FOR DELETE USING (true);

-- Create RLS policies for water_connection_commands
CREATE POLICY "Anyone can view water connection commands" ON water_connection_commands FOR SELECT USING (true);
CREATE POLICY "Anyone can insert water connection commands" ON water_connection_commands FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update water connection commands" ON water_connection_commands FOR UPDATE USING (true);

-- Create RLS policies for water_connection_logs
CREATE POLICY "Anyone can view water connection logs" ON water_connection_logs FOR SELECT USING (true);
CREATE POLICY "Anyone can insert water connection logs" ON water_connection_logs FOR INSERT WITH CHECK (true);

-- Create function to update updated_at timestamp (User requested alias)
CREATE OR REPLACE FUNCTION update_water_control_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS trigger_update_water_control_updated_at ON water_connection_control;
CREATE TRIGGER trigger_update_water_control_updated_at
  BEFORE UPDATE ON water_connection_control
  FOR EACH ROW
  EXECUTE FUNCTION update_water_control_updated_at();

-- Grant necessary permissions
GRANT ALL ON public.water_connection_control TO authenticated;
GRANT ALL ON public.water_connection_control TO anon;
GRANT ALL ON public.water_connection_commands TO authenticated;
GRANT ALL ON public.water_connection_commands TO anon;
GRANT ALL ON public.water_connection_logs TO authenticated;
GRANT ALL ON public.water_connection_logs TO anon;

COMMIT;


